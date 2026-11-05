-- Normal mode for an agent conversation: a read-only, live Neovim view of the
-- Markdown that scripts/transcript.py renders. Loaded by scripts/transcript-view.sh.
--
--   i a o I A O <CR>  jump to the agent's prompt pane (insert mode)
--   ]] / [[           next / previous turn;  zc zo zM zR fold turns and sessions
--   ]e / [e           next / previous feed event (takes a count)
--   G                 go to the end and keep following new output
--   :HerdrAgent [target]  every line naming an agent (pane ID or name) in the
--                     location list; without a target, the pane on this line
--   :HerdrTag [tag]   the sections tagged with an agent ([▲ w5:p2 donburi], a
--                     pane ID or a name) in the location list, in its color
local agent = vim.env.HERDR_TRANSCRIPT_AGENT or "coordinator"
local herdr = vim.env.HERDR_BIN_PATH or "herdr"
local buf = vim.api.nvim_get_current_buf()
local following = true

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
for index, mark in ipairs(marks) do
	vim.api.nvim_set_hl(0, "HerdrMark" .. index, { fg = mark[2], bold = true })
end
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

local function setup()
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].readonly = true
	vim.bo[buf].modifiable = false
	vim.wo.wrap = true
	vim.wo.linebreak = true
	vim.wo.foldmethod = "expr"
	vim.wo.foldexpr = [[getline(v:lnum)=~'^# '?'>1':(getline(v:lnum)=~'^## '?'>2':'=')]]
	vim.wo.foldlevel = 99
	vim.wo.signcolumn = "yes" -- section bars
end

setup()
vim.cmd("normal! G")

-- Reload when the renderer rewrites the file; stay at the end if we were there.
local group = vim.api.nvim_create_augroup("herdr_transcript", { clear = true })
vim.api.nvim_create_autocmd("FileChangedShell", {
	group = group,
	buffer = buf,
	callback = function()
		following = vim.fn.line(".") == vim.fn.line("$")
		vim.v.fcs_choice = "reload"
	end,
})
vim.api.nvim_create_autocmd("FileChangedShellPost", {
	group = group,
	buffer = buf,
	callback = function()
		setup()
		if following then
			vim.cmd("normal! G")
		end
	end,
})
local timer = vim.uv.new_timer()
timer:start(
	500,
	500,
	vim.schedule_wrap(function()
		if vim.api.nvim_buf_is_valid(buf) then
			vim.cmd("silent! checktime " .. buf)
		end
	end)
)

local function prompt()
	vim.fn.jobstart({ herdr, "agent", "focus", agent })
end
for _, key in ipairs({ "i", "a", "o", "I", "A", "O", "<CR>" }) do
	vim.keymap.set("n", key, prompt, { buffer = buf, desc = "Prompt " .. agent .. " (insert mode)" })
end
vim.keymap.set("n", "]]", function()
	vim.fn.search([[^##\? ]], "W")
end, { buffer = buf, desc = "Next turn" })
vim.keymap.set("n", "[[", function()
	vim.fn.search([[^##\? ]], "bW")
end, { buffer = buf, desc = "Previous turn" })

-- Feed events are the "HH:MM:SS ..." lines of the ```text block under a
-- "### HH:MM · feed" heading (task blocks and code in replies are not events).
-- Recomputed only when the renderer has rewritten the buffer.
local cache = { tick = -1, events = {} }
local function events()
	local tick = vim.api.nvim_buf_get_changedtick(buf)
	if cache.tick ~= tick then
		local found, in_feed, in_block = {}, false, false
		for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
			if line:match("^#+ ") and not in_block then
				in_feed = line:match("^### %d%d:%d%d · feed$") ~= nil
			elseif line:match("^```") then
				in_block = not in_block
			elseif in_feed and in_block and line:match("^%d%d:%d%d:%d%d ") then
				table.insert(found, lnum)
			end
		end
		cache = { tick = tick, events = found }
	end
	return cache.events
end

local function jump_event(forward)
	return function()
		local start, list = vim.fn.line("."), events()
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
vim.keymap.set("n", "]e", jump_event(true), { buffer = buf, desc = "Next feed event" })
vim.keymap.set("n", "[e", jump_event(false), { buffer = buf, desc = "Previous feed event" })

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

-- Pane IDs anywhere, and agent names from feed lines ("api-impl (wJ:p2)").
local function targets()
	local seen, list = {}, {}
	local function add(value)
		if not seen[value] then
			seen[value] = true
			table.insert(list, value)
		end
	end
	for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		for pane in line:gmatch("w%w+:p%d+") do
			add(pane)
		end
		for name in line:gmatch("([%w_.-]+) %(w%w+:p%d+%)") do
			add(name)
		end
	end
	table.sort(list)
	return list
end

vim.api.nvim_buf_create_user_command(buf, "HerdrAgent", function(opts)
	local target = vim.trim(opts.args)
	if target == "" then
		target = vim.api.nvim_get_current_line():match("w%w+:p%d+") or ""
	end
	if target == "" then
		vim.notify("HerdrAgent: give a pane ID or agent name, e.g. :HerdrAgent w5:p2", vim.log.levels.WARN)
		return
	end
	local items = {}
	for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local col = names(line, target)
		if col then
			table.insert(items, { bufnr = buf, lnum = lnum, col = col, text = line })
		end
	end
	if #items == 0 then
		vim.notify("HerdrAgent: no lines name " .. target, vim.log.levels.INFO)
		return
	end
	vim.fn.setloclist(0, {}, " ", { title = "herdr: " .. target, items = items })
	vim.cmd("lopen")
	color_marks(vim.api.nvim_get_current_win())
end, {
	nargs = "?",
	desc = "Lines naming a herdr agent, in the location list",
	complete = function(lead)
		return vim.tbl_filter(function(value)
			return vim.startswith(value, lead)
		end, targets())
	end,
})

-- Sections and tags. A section is a turn ("## HH:MM · you|claude") or a block
-- ("### HH:MM · feed|task|agent message") up to the next one. Each section is
-- tagged with the agents it names, shown as virtual text at the start of its
-- heading ("[▲ w5:p2 donburi]"), and its lines get a bar in the agent's
-- color; the Markdown itself is unchanged. Tags only come from the text: pane
-- IDs, the marker written before them, agent names from feed lines ("api-impl
-- (wJ:p2)", also matched on their own afterwards), and the workspace a feed
-- line names ("in donburi"). A pane's marker is the one written in that
-- section, else the nearest one written elsewhere, else its live marker from
-- `herdr agent list`; with none, the tag is just the pane ID.
local ns = vim.api.nvim_create_namespace("herdr_sections")
vim.api.nvim_set_hl(0, "HerdrTag", { link = "Comment", default = true })
local mark_group = {}
for index, mark in ipairs(marks) do
	mark_group[mark[1]] = "HerdrMark" .. index
end
local live_marks = {}
local known = { names = {}, sections = {} }

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

local function parse()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
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

local function render()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local parsed = parse()
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	known = { names = {}, sections = {} }
	for _, section in ipairs(parsed.sections) do
		if #section.agents > 0 then
			local chunks, colors, entry = {}, {}, { heading = section.heading, tags = {} }
			for _, pane in ipairs(section.agents) do
				local text, group = tag_for(parsed, pane, section)
				colors[pane] = group ~= "HerdrTag" and group or nil
				vim.list_extend(chunks, { { text, group }, { " " } })
				entry.tags[pane] = { text = text, group = group }
				local info = parsed.info[pane] or {}
				for _, value in ipairs({ pane, info.name or info.workspace or info.label }) do
					known.names[value] = known.names[value] or {}
					known.names[value][pane] = true
				end
			end
			table.insert(known.sections, entry)
			vim.api.nvim_buf_set_extmark(buf, ns, section.heading - 1, 0, {
				virt_text = chunks,
				virt_text_pos = "inline",
			})
			local primary = colors[section.agents[1]]
			for lnum = section.first, section.last do
				local group = colors[section.lines[lnum] or ""] or primary
				if group then
					vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, { sign_text = "▎", sign_hl_group = group })
				end
			end
		end
	end
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
				render()
			end
		end)
	end)
end

render()
fetch_live_marks()
vim.uv.new_timer():start(15000, 15000, vim.schedule_wrap(fetch_live_marks))
vim.api.nvim_create_autocmd("FileChangedShellPost", { group = group, buffer = buf, callback = render })

vim.api.nvim_buf_create_user_command(buf, "HerdrTag", function(opts)
	local arg = vim.trim(opts.args):gsub("^%[", ""):gsub("%]$", "")
	local panes = {}
	local pane = arg:match("w%w+:p%d+")
	if pane then
		panes[pane] = true
	elseif arg ~= "" then
		panes = known.names[arg] or {}
	else
		pane = vim.api.nvim_get_current_line():match("w%w+:p%d+")
		if pane then
			panes[pane] = true
		end
	end
	if next(panes) == nil then
		vim.notify("HerdrTag: give a tag, pane ID or agent name, e.g. :HerdrTag w5:p2", vim.log.levels.WARN)
		return
	end
	local items, groups = {}, {}
	for _, section in ipairs(known.sections) do
		for tagged in pairs(panes) do
			local tag = section.tags[tagged]
			if tag then
				groups[tag.text] = tag.group
				table.insert(items, {
					bufnr = buf,
					lnum = section.heading,
					col = 1,
					text = tag.text
						.. " "
						.. vim.api.nvim_buf_get_lines(buf, section.heading - 1, section.heading, false)[1],
				})
				break
			end
		end
	end
	if #items == 0 then
		vim.notify("HerdrTag: no sections tagged " .. arg, vim.log.levels.INFO)
		return
	end
	vim.fn.setloclist(0, {}, " ", { title = "herdr tag: " .. arg, items = items })
	vim.cmd("lopen")
	local list_win = vim.api.nvim_get_current_win()
	color_marks(list_win)
	for text, tag_group in pairs(groups) do
		vim.fn.matchadd(tag_group, "\\V" .. text:gsub("\\", "\\\\"), 21, -1, { window = list_win })
	end
end, {
	nargs = "?",
	desc = "Sections tagged with a herdr agent, in the location list",
	complete = function(lead)
		local list = vim.tbl_filter(function(value)
			return vim.startswith(value, lead)
		end, vim.tbl_keys(known.names))
		table.sort(list)
		return list
	end,
})

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
	table.insert(parts, "%=%#HerdrBannerHint#i prompt · Ctrl+a back ")
	return table.concat(parts)
end

vim.wo[win].winbar = banner({ agents = 0 })
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
			if vim.api.nvim_win_is_valid(win) then
				vim.wo[win].winbar = banner(ok and counts or nil)
			end
		end)
	end)
end
refresh()
vim.uv.new_timer():start(3000, 3000, vim.schedule_wrap(refresh))
