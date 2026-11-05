-- Normal mode for an agent conversation: a read-only, live Neovim view of the
-- Markdown that scripts/transcript.py renders. Loaded by scripts/transcript-view.sh.
--
--   i a o I A O <CR>  jump to the agent's prompt pane (insert mode)
--   ]] / [[           next / previous turn;  zc zo zM zR fold turns and sessions
--   G                 go to the end and keep following new output
local agent = vim.env.HERDR_TRANSCRIPT_AGENT or "coordinator"
local herdr = vim.env.HERDR_BIN_PATH or "herdr"
local buf = vim.api.nvim_get_current_buf()
local following = true

-- Agent markers in their Kanagawa colors: same list as MARKS in
-- scripts/agent_watch.py and the $mark rules in config.toml.
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
	local name = "HerdrMark" .. index
	vim.api.nvim_set_hl(0, name, { fg = mark[2], bold = true })
	vim.fn.matchadd(name, "\\V" .. mark[1], 20)
end

local function setup()
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].readonly = true
	vim.bo[buf].modifiable = false
	vim.wo.wrap = true
	vim.wo.linebreak = true
	vim.wo.foldmethod = "expr"
	vim.wo.foldexpr = [[getline(v:lnum)=~'^# '?'>1':(getline(v:lnum)=~'^## '?'>2':'=')]]
	vim.wo.foldlevel = 99
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
