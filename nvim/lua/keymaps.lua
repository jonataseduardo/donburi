-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- ── Navigation ──────────────────────────────────────────
-- Ctrl+hjkl: seamless navigation between neovim splits and tmux panes
--   handled by smart-splits.lua (with multiplexer_integration = 'tmux')
-- Ctrl+w H/J/K/L: resize neovim splits (overrides default reposition)
-- Ctrl+w Arrow: reposition neovim splits (replaces Ctrl+w H/J/K/L default)
-- Resize tmux panes: prefix + h/j/k/l (defined in tmux.conf)

-- Terminal mode navigation — exit terminal first, then let smart-splits handle it
vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-h>]], { desc = 'Navigate left from terminal', noremap = false, silent = true })
vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-j>]], { desc = 'Navigate down from terminal', noremap = false, silent = true })
vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-k>]], { desc = 'Navigate up from terminal', noremap = false, silent = true })
vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-l>]], { desc = 'Navigate right from terminal', noremap = false, silent = true })

-- Resize neovim splits with Ctrl+w H/J/K/L (overrides default reposition)
vim.keymap.set('n', '<C-w>H', '<cmd>vertical resize -5<CR>', { desc = 'Resize split left' })
vim.keymap.set('n', '<C-w>J', '<cmd>resize -3<CR>', { desc = 'Resize split down' })
vim.keymap.set('n', '<C-w>K', '<cmd>resize +3<CR>', { desc = 'Resize split up' })
vim.keymap.set('n', '<C-w>L', '<cmd>vertical resize +5<CR>', { desc = 'Resize split right' })

-- Reposition splits with Ctrl+w Arrow (wincmd bypasses the remap above)
vim.keymap.set('n', '<C-w><Left>', '<cmd>wincmd H<CR>', { desc = 'Move split to far left' })
vim.keymap.set('n', '<C-w><Down>', '<cmd>wincmd J<CR>', { desc = 'Move split to bottom' })
vim.keymap.set('n', '<C-w><Up>', '<cmd>wincmd K<CR>', { desc = 'Move split to top' })
vim.keymap.set('n', '<C-w><Right>', '<cmd>wincmd L<CR>', { desc = 'Move split to far right' })

-- Open terminal in current directory
vim.keymap.set('n', '<leader>tt', '<cmd>terminal<CR>', { desc = 'Open terminal' })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Mini.files explorer
vim.keymap.set('n', '\\', '<cmd>lua MiniFiles.open()<CR>')

-- ChatGPT keymaps
vim.keymap.set({ 'n', 'v' }, '<leader>ia', '<cmd>ChatGPT<CR>', { desc = 'ChatGPT' })
vim.keymap.set({ 'n', 'v' }, '<leader>ie', '"<cmd>ChatGPTEditWithInstruction<CR>"', { desc = 'Edit with instruction' })
vim.keymap.set({ 'n', 'v' }, '<leader>ig', '<cmd>ChatGPTRun grammar_correction<CR>', { desc = 'Grammar Correction' })
vim.keymap.set({ 'n', 'v' }, '<leader>id', '<cmd>ChatGPTRun docstring<CR>', { desc = 'Create Docstring' })
vim.keymap.set({ 'n', 'v' }, '<leader>ix', '<cmd>ChatGPTRun explain_code<CR>', { desc = 'Explain Code' })
vim.keymap.set({ 'n', 'v' }, '<leader>if', '<cmd>ChatGPTRun fix_bugs<CR>', { desc = 'Fix Bugs' })
vim.keymap.set({ 'n', 'v' }, '<leader>is', '<cmd>ChatGPTRun summarize<CR>', { desc = 'Summarize Text' })
vim.keymap.set({ 'n', 'v' }, '<leader>il', '<cmd>ChatGPTRun code_readability_analysis<CR>', { desc = 'Code Readability Analysis' })
-- vim: ts=2 sts=2 sw=2 et
