-- Normal mode for an agent conversation: a read-only, live Neovim view of the
-- Markdown that scripts/transcript.py renders. Loaded by scripts/transcript-view.sh.
--
--   i a o I A O <CR>  jump to the agent's prompt pane (insert mode)
--   ]] / [[           next / previous turn;  zc zo zM zR fold turns and sessions
--   ]e / [e           next / previous feed event (takes a count)
--   G                 go to the end and keep following new output
--   :HerdrAgent[!] [target]  every line naming an agent (pane ID or name) in the
--                     location list; without a target, the pane on this line
--   :HerdrTag[!] [tag]  the sections tagged with an agent ([▲ w5:p2 donburi], a
--                     pane ID or a name) in the location list, in its color
--
-- With HERDR_TRANSCRIPT_DAYS (the coordinator: transcript.py --days), the
-- history is also kept as one file per day:
--
--   [d / ]d           previous / next day in this window (]d past the last
--                     day returns to the live view)
--   :HerdrDay [date]  open a day (Tab completes from index.md); no date = live
--   ! on :HerdrAgent / :HerdrTag  search every day file, not just this buffer
--
-- Only the live view reloads as the renderer rewrites it; day files are
-- archived and do not change.
local agent = vim.env.HERDR_TRANSCRIPT_AGENT or "coordinator"
local herdr = vim.env.HERDR_BIN_PATH or "herdr"
local days_dir = vim.env.HERDR_TRANSCRIPT_DAYS
if days_dir and days_dir ~= "" then
	days_dir = vim.fn.fnamemodify(days_dir, ":p"):gsub("/$", "")
else
	days_dir = nil
end
local live_buf = vim.api.nvim_get_current_buf()
local group = vim.api.nvim_create_augroup("herdr_transcript", { clear = true })
local update_banner = function() end -- set below for the coordinator

-- Agent markers in their Kanagawa colors: same list as MARKS in
-- scripts/agent_watch.py and the agent label rules in config.toml.
local marks = {
	{ "◉", "#FF9E64" },
	{ "●", "#7FB4CA" },
	{ "◆", "#957FB8" },
	{ "■", "#7E9CD8" },
	{ "▲", "#D27E99" },
	{ "★", "#DCD7BA" },
	{ "▼", "#C0A36E" },
	{ "✚", "#A3D4D5" },
	{ "✦", "#E46876" },
}
local mark_group = {}
for index, mark in ipairs(marks) do
	vim.api.nvim_set_hl(0, "HerdrMark" .. index, { fg = mark[2], bold = true })
	mark_group[mark[1]] = "HerdrMark" .. index
end
vim.api.nvim_set_hl(0, "HerdrTag", { link = "Comment", default = true })
local ns = vim.api.nvim_create_namespace("herdr_sections")
local live_marks = {}

-- Matches belong to a window: color the history window and, later, its
-- location list window, once each.
local function color_marks(win)
	if vim.w[win].herdr_marks then
		return
	end
	vim.w[win].herdr_marks = true
	for index, mark in ipairs(marks) do
		vim.fn.matchadd("HerdrMark" .. index, "\\V" .. mark[1], 20, -1, { window = win })
	end
end
color_marks(vim.api.nvim_get_current_win())

local function window_options()
	vim.wo.wrap = true
	vim.wo.linebreak = true
	vim.wo.foldmethod = "expr"
	vim.wo.foldexpr = [[getline(v:lnum)=~'^# '?'>1':(getline(v:lnum)=~'^## '?'>2':'=')]]
	vim.wo.foldlevel = 99
	vim.wo.signcolumn = "yes" -- section bars
end

---------------------------------------------------------------------------
-- Reading the text (pure functions over a list of lines)
---------------------------------------------------------------------------

-- Column where `line` names `target` as a whole word (w5:p2, not w5:p23), or nil.
local function names(line, target)
	local from = 1
	while true do
		local first, last = line:find(target, from, true)
		if not first then
			return nil
		end
		local before, after = line:sub(first - 1, first - 1), line:sub(last + 1, last + 1)
		if not before:match("[%w:_-]") and not after:match("[%w:_-]") then
			return first
		end
		from = last + 1
	end
end

-- Feed events are the "HH:MM:SS ..." lines of the ```text block under a
-- "### HH:MM · feed" heading (task blocks and code in replies are not events).
local function event_lines(lines)
	local found, in_feed, in_block = {}, false, false
	for lnum, line in ipairs(lines) do
		if line:match("^#+ ") and not in_block then
			in_feed = line:match("^### %d%d:%d%d · feed$") ~= nil
		elseif line:match("^```") then
			in_block = not in_block
		elseif in_feed and in_block and line:match("^%d%d:%d%d:%d%d ") then
			table.insert(found, lnum)
		end
	end
	return found
end

-- Pane IDs anywhere, and agent names from feed lines ("api-impl (wJ:p2)").
local function targets(lines)
	local seen, list = {}, {}
	for _, line in ipairs(lines) do
		for _, pattern in ipairs({ "w%w+:p%d+", "([%w_.-]+) %(w%w+:p%d+%)" }) do
			for value in line:gmatch(pattern) do
				if not seen[value] then
					seen[value] = true
					table.insert(list, value)
				end
			end
		end
	end
	table.sort(list)
	return list
end

-- Sections and tags. A section is a turn ("## HH:MM · you|claude") or a block
-- ("### HH:MM · feed|task|agent message") up to the next one. Each section is
-- tagged with the agents it names, shown as virtual text at the start of its
-- heading ("[▲ w5:p2 donburi]"), and its lines get a bar in the agent's
-- color; the Markdown itself is unchanged. Tags only come from the text: pane
-- IDs, the marker written before them, agent names from feed lines ("api-impl
-- (wJ:p2)", also matched on their own afterwards), and the workspace a feed
-- line names ("in donburi"). A pane's marker is the one written in that
-- section, else the nearest one written elsewhere in the same file, else its
-- live marker from `herdr agent list`; with none, the tag is just the pane ID.
local function section_kind(line)
	if line:match("^# %d%d%d%d%-%d%d%-%d%d %d%d:%d%d · ") then
		return "session"
	elseif line:match("^## %d%d:%d%d · ") then
		return "turn"
	end
	local label = line:match("^### %d%d:%d%d · (.+)$")
	if label == "feed" or label == "task" or label == "agent message" then
		return "block"
	end
end

-- Pane IDs written on a line, with what the text says about each.
local function mentions(line)
	local found, from = {}, 1
	while true do
		local first, last = line:find("w%w+:p%d+", from)
		if not first then
			return found
		end
		local before, after = line:sub(first - 1, first - 1), line:sub(last + 1, last + 1)
		if not before:match("[%w:_-]") and not after:match("[%w:_-]") then
			local prefix, tail = line:sub(1, first - 1), line:sub(last + 1)
			local name = prefix:match("([%w_.-]+) %($") -- feed form: "api-impl (wJ:p2)"
			local mark = name and prefix:match("(%S+) [%w_.-]+ %($") or prefix:match("(%S+) $")
			local feed = line:match("^%d%d:%d%d:%d%d ")
			table.insert(found, {
				pane = line:sub(first, last),
				mark = mark_group[mark or ""] and mark or nil,
				name = name and feed and name or nil,
				workspace = feed and tail:match("^%)? %S+ in ([%w_.-]+)") or nil,
				label = not name and tail:match("^ %(([%w_.-]+)%)") or nil,
			})
		end
		from = last + 1
	end
end

local function parse(lines)
	local info, marks_at, agent_names = {}, {}, {}
	local sections, current, fenced = {}, nil, false
	local per_line = {}
	for lnum, line in ipairs(lines) do
		local kind = not fenced and section_kind(line)
		if line:match("^```") then
			fenced = not fenced
		end
		if kind then
			current = kind ~= "session" and { heading = lnum, first = lnum, last = lnum, agents = {}, lines = {} }
				or nil
			if current then
				table.insert(sections, current)
			end
		elseif current then
			current.last = lnum
		end
		per_line[lnum] = mentions(line)
		for _, m in ipairs(per_line[lnum]) do
			local pane = info[m.pane] or {}
			info[m.pane] = pane
			pane.name = m.name or pane.name
			pane.workspace = m.workspace or pane.workspace
			pane.label = m.label or pane.label
			if m.name then
				agent_names[m.name] = m.pane
			end
			if m.mark then
				marks_at[m.pane] = marks_at[m.pane] or {}
				table.insert(marks_at[m.pane], { lnum = lnum, mark = m.mark })
			end
		end
	end
	-- Second pass: which agents each section names, line by line.
	for _, section in ipairs(sections) do
		local seen = {}
		for lnum = section.first, section.last do
			local line, line_panes = lines[lnum], {}
			for _, m in ipairs(per_line[lnum]) do
				table.insert(line_panes, m.pane)
			end
			for name, pane in pairs(agent_names) do
				if names(line, name) then
					table.insert(line_panes, pane)
				end
			end
			for _, pane in ipairs(line_panes) do
				if not seen[pane] then
					seen[pane] = true
					table.insert(section.agents, pane)
				end
			end
			section.lines[lnum] = line_panes[1]
		end
	end
	return { info = info, marks_at = marks_at, sections = sections, lines = lines }
end

-- The marker for `pane` in `section`: written there, else nearest, else live.
local function mark_for(parsed, pane, section)
	local list, before, after = parsed.marks_at[pane] or {}, nil, nil
	for _, entry in ipairs(list) do
		if entry.lnum >= section.first and entry.lnum <= section.last then
			return entry.mark
		elseif entry.lnum < section.first then
			before = entry.mark
		elseif not after then
			after = entry.mark
		end
	end
	return before or after or live_marks[pane]
end

local function tag_for(parsed, pane, section)
	local info, mark = parsed.info[pane] or {}, mark_for(parsed, pane, section)
	local name = info.name or info.workspace or info.label
	local text = "["
		.. table.concat(
			vim.tbl_filter(function(part)
				return part ~= nil
			end, { mark, pane, name }),
			" "
		)
		.. "]"
	return text, mark and mark_group[mark] or "HerdrTag"
end

-- The tagged sections of some lines, and every name a tag can be found by.
local function tagged(lines)
	local parsed = parse(lines)
	local result = { names = {}, sections = {}, parsed = parsed }
	for _, section in ipairs(parsed.sections) do
		if #section.agents > 0 then
			local entry = { section = section, heading = section.heading, tags = {} }
			for _, pane in ipairs(section.agents) do
				local text, tag_group = tag_for(parsed, pane, section)
				entry.tags[pane] = { text = text, group = tag_group }
				local info = parsed.info[pane] or {}
				for _, value in ipairs({ pane, info.name or info.workspace or info.label }) do
					result.names[value] = result.names[value] or {}
					result.names[value][pane] = true
				end
			end
			table.insert(result.sections, entry)
		end
	end
	return result
end

-- The panes a :HerdrTag argument means, using `known_names` for agent names.
local function tag_panes(arg, known_names)
	local panes, pane = {}, arg:match("w%w+:p%d+")
	if pane then
		panes[pane] = true
	elseif arg ~= "" then
		panes = known_names[arg] or {}
	else
		pane = vim.api.nvim_get_current_line():match("w%w+:p%d+")
		if pane then
			panes[pane] = true
		end
	end
	return panes
end

---------------------------------------------------------------------------
-- Day files
---------------------------------------------------------------------------

local function today()
	return os.date("%Y-%m-%d")
end

-- Dates of the day files on disk, oldest first.
local function day_files()
	local found = {}
	if days_dir then
		for name, kind in vim.fs.dir(days_dir) do
			local date = kind == "file" and name:match("^(%d%d%d%d%-%d%d%-%d%d)%.md$")
			if date then
				table.insert(found, date)
			end
		end
	end
	table.sort(found)
	return found
end

-- Dates listed in index.md (what the renderer archived), else the files.
local function index_days()
	local ok, lines = pcall(vim.fn.readfile, (days_dir or "") .. "/index.md")
	local found = {}
	for _, line in ipairs(ok and lines or {}) do
		local date = line:match("^| %[(%d%d%d%d%-%d%d%-%d%d)%]")
		if date then
			table.insert(found, date)
		end
	end
	table.sort(found)
	return #found > 0 and found or day_files()
end

local function day_path(date)
	return days_dir .. "/" .. date .. ".md"
end

-- Show a day in this window; today and later are the live view.
local function open_day(date)
	if not date or date >= today() then
		vim.api.nvim_win_set_buf(0, live_buf)
	else
		vim.cmd.edit(vim.fn.fnameescape(day_path(date)))
	end
end

---------------------------------------------------------------------------
-- A buffer showing a history: the live view or a day file
---------------------------------------------------------------------------

local attached = {} -- buf -> { known = tagged(...), events = {tick, lines} }
local following = true

local function buf_lines(buf)
	return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function render(buf)
	if not (vim.api.nvim_buf_is_valid(buf) and attached[buf]) then
		return
	end
	local known = tagged(buf_lines(buf))
	attached[buf].known = known
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, entry in ipairs(known.sections) do
		local section, chunks, colors = entry.section, {}, {}
		for _, pane in ipairs(section.agents) do
			local tag = entry.tags[pane]
			colors[pane] = tag.group ~= "HerdrTag" and tag.group or nil
			vim.list_extend(chunks, { { tag.text, tag.group }, { " " } })
		end
		vim.api.nvim_buf_set_extmark(buf, ns, section.heading - 1, 0, {
			virt_text = chunks,
			virt_text_pos = "inline",
		})
		local primary = colors[section.agents[1]]
		for lnum = section.first, section.last do
			local bar = colors[section.lines[lnum] or ""] or primary
			if bar then
				vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, { sign_text = "▎", sign_hl_group = bar })
			end
		end
	end
end

local function events(buf)
	local state, tick = attached[buf], vim.api.nvim_buf_get_changedtick(buf)
	if state.events.tick ~= tick then
		state.events = { tick = tick, lines = event_lines(buf_lines(buf)) }
	end
	return state.events.lines
end

local function jump_event(buf, forward)
	return function()
		local start, list = vim.fn.line("."), events(buf)
		local target = start
		for _ = 1, vim.v.count1 do
			local next_line
			if forward then
				for _, lnum in ipairs(list) do
					if lnum > target then
						next_line = lnum
						break
					end
				end
			else
				for i = #list, 1, -1 do
					if list[i] < target then
						next_line = list[i]
						break
					end
				end
			end
			if not next_line then
				break
			end
			target = next_line
		end
		if target ~= start then
			vim.cmd("normal! m'")
			vim.api.nvim_win_set_cursor(0, { target, 0 })
		end
	end
end

local function step_day(forward)
	return function()
		local current, dates = vim.b.herdr_day or today(), day_files()
		local target
		for _, date in ipairs(dates) do
			if forward and date > current then
				target = date
				break
			elseif not forward and date < current then
				target = date
			end
		end
		if forward and (target == nil or target >= today()) then
			if vim.b.herdr_day then
				open_day(nil)
			end
			return
		end
		if target then
			open_day(target)
		else
			vim.notify("herdr: no earlier day", vim.log.levels.INFO)
		end
	end
end

local function show_list(items, title, colors)
	vim.fn.setloclist(0, {}, " ", { title = title, items = items })
	vim.cmd("lopen")
	local list_win = vim.api.nvim_get_current_win()
	color_marks(list_win)
	for text, tag_group in pairs(colors or {}) do
		vim.fn.matchadd(tag_group, "\\V" .. text:gsub("\\", "\\\\"), 21, -1, { window = list_win })
	end
end

-- Every day file as {date, path, lines}, oldest first (for the ! searches).
local function each_day()
	local list = {}
	for _, date in ipairs(day_files()) do
		local path = day_path(date)
		local ok, lines = pcall(vim.fn.readfile, path)
		if ok then
			table.insert(list, { date = date, path = path, lines = lines })
		end
	end
	return list
end

local function agent_command(buf)
	return function(opts)
		local target = vim.trim(opts.args)
		if target == "" then
			target = vim.api.nvim_get_current_line():match("w%w+:p%d+") or ""
		end
		if target == "" then
			vim.notify("HerdrAgent: give a pane ID or agent name, e.g. :HerdrAgent w5:p2", vim.log.levels.WARN)
			return
		end
		local items = {}
		local sources = opts.bang and days_dir and each_day() or { { lines = buf_lines(buf) } }
		for _, source in ipairs(sources) do
			for lnum, line in ipairs(source.lines) do
				local col = names(line, target)
				if col then
					table.insert(items, {
						bufnr = not source.path and buf or nil,
						filename = source.path,
						lnum = lnum,
						col = col,
						text = line,
					})
				end
			end
		end
		if #items == 0 then
			vim.notify("HerdrAgent: no lines name " .. target, vim.log.levels.INFO)
			return
		end
		show_list(items, (opts.bang and days_dir and "herdr (all days): " or "herdr: ") .. target)
	end
end

local function tag_command(buf)
	return function(opts)
		local arg = vim.trim(opts.args):gsub("^%[", ""):gsub("%]$", "")
		local sources = {}
		if opts.bang and days_dir then
			for _, day in ipairs(each_day()) do
				table.insert(sources, { path = day.path, lines = day.lines, known = tagged(day.lines) })
			end
		else
			sources = { { lines = buf_lines(buf), known = attached[buf].known } }
		end
		local known_names = {}
		for _, source in ipairs(sources) do
			for value, panes in pairs(source.known.names) do
				known_names[value] = vim.tbl_extend("force", known_names[value] or {}, panes)
			end
		end
		local panes = tag_panes(arg, known_names)
		if next(panes) == nil then
			vim.notify("HerdrTag: give a tag, pane ID or agent name, e.g. :HerdrTag w5:p2", vim.log.levels.WARN)
			return
		end
		local items, colors = {}, {}
		for _, source in ipairs(sources) do
			for _, entry in ipairs(source.known.sections) do
				for pane in pairs(panes) do
					local tag = entry.tags[pane]
					if tag then
						colors[tag.text] = tag.group
						table.insert(items, {
							bufnr = not source.path and buf or nil,
							filename = source.path,
							lnum = entry.heading,
							col = 1,
							text = tag.text .. " " .. source.lines[entry.heading],
						})
						break
					end
				end
			end
		end
		if #items == 0 then
			vim.notify("HerdrTag: no sections tagged " .. arg, vim.log.levels.INFO)
			return
		end
		show_list(items, (opts.bang and days_dir and "herdr tag (all days): " or "herdr tag: ") .. arg, colors)
	end
end

local function prompt()
	vim.fn.jobstart({ herdr, "agent", "focus", agent })
end

local function attach(buf, live)
	if attached[buf] then
		return
	end
	attached[buf] = { known = { names = {}, sections = {} }, events = { tick = -1 } }
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].readonly = true
	vim.bo[buf].modifiable = false
	window_options()

	local function map(key, action, desc)
		vim.keymap.set("n", key, action, { buffer = buf, desc = desc })
	end
	for _, key in ipairs({ "i", "a", "o", "I", "A", "O", "<CR>" }) do
		map(key, prompt, "Prompt " .. agent .. " (insert mode)")
	end
	map("]]", function()
		vim.fn.search([[^##\? ]], "W")
	end, "Next turn")
	map("[[", function()
		vim.fn.search([[^##\? ]], "bW")
	end, "Previous turn")
	map("]e", jump_event(buf, true), "Next feed event")
	map("[e", jump_event(buf, false), "Previous feed event")

	vim.api.nvim_buf_create_user_command(buf, "HerdrAgent", agent_command(buf), {
		nargs = "?",
		bang = true,
		desc = "Lines naming a herdr agent, in the location list (! = every day file)",
		complete = function(lead)
			return vim.tbl_filter(function(value)
				return vim.startswith(value, lead)
			end, targets(buf_lines(buf)))
		end,
	})
	vim.api.nvim_buf_create_user_command(buf, "HerdrTag", tag_command(buf), {
		nargs = "?",
		bang = true,
		desc = "Sections tagged with a herdr agent, in the location list (! = every day file)",
		complete = function(lead)
			local list = vim.tbl_filter(function(value)
				return vim.startswith(value, lead)
			end, vim.tbl_keys(attached[buf].known.names))
			table.sort(list)
			return list
		end,
	})

	if days_dir then
		map("[d", step_day(false), "Previous day")
		map("]d", step_day(true), "Next day (the live view after the last)")
		vim.api.nvim_buf_create_user_command(buf, "HerdrDay", function(opts)
			local date = vim.trim(opts.args)
			if date ~= "" and date ~= "today" and not date:match("^%d%d%d%d%-%d%d%-%d%d$") then
				vim.notify("HerdrDay: give a date like 2026-11-05", vim.log.levels.WARN)
			elseif date ~= "" and date ~= "today" and date < today() and vim.fn.filereadable(day_path(date)) == 0 then
				vim.notify("HerdrDay: no history for " .. date, vim.log.levels.INFO)
			else
				open_day(date ~= "today" and date ~= "" and date or nil)
			end
		end, {
			nargs = "?",
			desc = "Open a day of the history (no date: the live view)",
			complete = function(lead)
				local dates = vim.tbl_filter(function(value)
					return vim.startswith(value, lead)
				end, index_days())
				table.sort(dates, function(a, b)
					return a > b
				end)
				return dates
			end,
		})
	end

	render(buf)
	if not live then
		-- Archived days do not change; if one is reloaded anyway, redraw its tags.
		vim.api.nvim_create_autocmd("FileChangedShellPost", {
			group = group,
			buffer = buf,
			callback = function()
				render(buf)
			end,
		})
		return
	end

	-- Reload when the renderer rewrites the file; stay at the end if we were
	-- there. While a day is shown instead, the live buffer reloads in the
	-- background and the day window's cursor is left alone.
	local function shown()
		return vim.api.nvim_get_current_buf() == buf
	end
	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		buffer = buf,
		callback = function()
			following = vim.fn.line(".") == vim.fn.line("$")
		end,
	})
	vim.api.nvim_create_autocmd("FileChangedShell", {
		group = group,
		buffer = buf,
		callback = function()
			if shown() then
				following = vim.fn.line(".") == vim.fn.line("$")
			end
			vim.v.fcs_choice = "reload"
		end,
	})
	vim.api.nvim_create_autocmd("FileChangedShellPost", {
		group = group,
		buffer = buf,
		callback = function()
			render(buf)
			if shown() then
				window_options()
				if following then
					vim.cmd("normal! G")
				end
			end
		end,
	})
	vim.uv.new_timer():start(
		500,
		500,
		vim.schedule_wrap(function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.cmd("silent! checktime " .. buf)
			end
		end)
	)
end

attach(live_buf, true)
vim.cmd("normal! G")

-- Day files get the same view however they are opened ([d, :HerdrDay, a
-- location list entry, gf from index.md); the live view keeps following.
-- Directories are compared resolved: a location list names a file by its
-- real path (/private/var/... on macOS), :edit by the path it was given.
if days_dir then
	local days_real = vim.fn.resolve(days_dir)
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		pattern = "*.md",
		callback = function(event)
			local path = vim.api.nvim_buf_get_name(event.buf)
			local date = path:match("(%d%d%d%d%-%d%d%-%d%d)%.md$")
			if vim.fn.resolve(vim.fn.fnamemodify(path, ":h")) ~= days_real then
				return
			end
			if date then
				vim.b[event.buf].herdr_day = date
				attach(event.buf, false)
				window_options()
			end
			update_banner()
		end,
	})
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		buffer = live_buf,
		callback = function()
			window_options()
			if following then
				vim.cmd("normal! G")
			end
			update_banner()
		end,
	})
end

local function fetch_live_marks()
	pcall(vim.system, { herdr, "agent", "list" }, { text = true }, function(result)
		local ok, data = pcall(vim.json.decode, result.stdout or "", { luanil = { object = true, array = true } })
		local fresh = {}
		for _, item in ipairs(ok and type(data) == "table" and vim.tbl_get(data, "result", "agents") or {}) do
			local mark = vim.tbl_get(item, "tokens", "mark")
			if item.pane_id and mark_group[mark or ""] then
				fresh[item.pane_id] = mark
			end
		end
		vim.schedule(function()
			if not vim.deep_equal(fresh, live_marks) then
				live_marks = fresh
				for buf in pairs(attached) do
					render(buf)
				end
			end
		end)
	end)
end
fetch_live_marks()
vim.uv.new_timer():start(15000, 15000, vim.schedule_wrap(fetch_live_marks))

-- The coordinator's own history pane gets a darker background and an orange
-- "◉ COORDINATOR" banner with live agent counts (the same block as its Claude
-- status line), so its workspace is unmistakable.
if agent ~= (vim.env.HERDR_COORDINATOR_NAME or "coordinator") then
	return
end

local win = vim.api.nvim_get_current_win()
local bar, ink = "#2A2A37", "#16161D" -- sumiInk4 bar on sumiInk0, one shade below Kanagawa's background
vim.api.nvim_set_hl(0, "HerdrCoordinatorNormal", { fg = "#DCD7BA", bg = ink })
vim.api.nvim_set_hl(0, "HerdrCoordinatorEob", { fg = ink, bg = ink })
vim.api.nvim_set_hl(0, "HerdrBanner", { fg = "#C8C093", bg = bar })
vim.api.nvim_set_hl(0, "HerdrBannerTitle", { fg = ink, bg = "#FF9E64", bold = true })
vim.api.nvim_set_hl(0, "HerdrBannerBlocked", { fg = "#FF5D62", bg = bar, bold = true })
vim.api.nvim_set_hl(0, "HerdrBannerWorking", { fg = "#E6C384", bg = bar })
vim.api.nvim_set_hl(0, "HerdrBannerHint", { fg = "#727169", bg = bar })
vim.wo[win].winhighlight = table.concat({
	"Normal:HerdrCoordinatorNormal",
	"NormalNC:HerdrCoordinatorNormal",
	"SignColumn:HerdrCoordinatorNormal",
	"FoldColumn:HerdrCoordinatorNormal",
	"EndOfBuffer:HerdrCoordinatorEob",
	"WinBar:HerdrBanner",
	"WinBarNC:HerdrBanner",
}, ",")

local last_counts = { agents = 0 }
local function banner(counts)
	local parts = { "%#HerdrBannerTitle# ◉ COORDINATOR %#HerdrBanner# " }
	if not counts or counts.error then
		table.insert(parts, "%#HerdrBannerBlocked#herdr unavailable%#HerdrBanner#")
	else
		local total = counts.agents or 0
		table.insert(parts, total .. (total == 1 and " agent" or " agents"))
		if (counts.blocked or 0) > 0 then
			table.insert(parts, " · %#HerdrBannerBlocked#" .. counts.blocked .. " blocked%#HerdrBanner#")
		end
		if (counts.working or 0) > 0 then
			table.insert(parts, " · %#HerdrBannerWorking#" .. counts.working .. " working%#HerdrBanner#")
		end
	end
	-- Which day the pane shows, when it is not the live view.
	local day = vim.api.nvim_win_is_valid(win) and vim.b[vim.api.nvim_win_get_buf(win)].herdr_day
	if day then
		table.insert(parts, " · %#HerdrBannerWorking#" .. day .. "%#HerdrBanner# ([d ]d)")
	end
	table.insert(parts, "%=%#HerdrBannerHint#i prompt · Ctrl+a back ")
	return table.concat(parts)
end

update_banner = function()
	if vim.api.nvim_win_is_valid(win) then
		vim.wo[win].winbar = banner(last_counts)
	end
end
update_banner()
local feed = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/scripts/agent_watch.py"
local pending = false
local function refresh()
	if pending or not vim.api.nvim_win_is_valid(win) then
		return
	end
	pending = true
	vim.system({ "python3", feed, "--counts" }, { text = true }, function(result)
		local ok, counts = pcall(vim.json.decode, result.stdout or "")
		vim.schedule(function()
			pending = false
			last_counts = ok and counts or nil
			update_banner()
		end)
	end)
end
refresh()
vim.uv.new_timer():start(3000, 3000, vim.schedule_wrap(refresh))
