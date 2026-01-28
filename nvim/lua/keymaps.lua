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
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Terminal navigation keymaps are now handled by the navigation plugin
-- This ensures seamless navigation between Neovim splits and terminals

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Smart navigation between Neovim splits and terminals
-- Pure Neovim solution - no tmux dependencies
-- Similar to nvim-tmux-navigation but optimized for Ghostty + toggleterm

-- Track last active window for <C-\> functionality
local last_active_window = nil

-- Function to navigate between windows
local function navigate_window(direction)
  local current_window = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_win_get_buf(current_window)

  -- Check if we're in a terminal buffer
  local is_terminal = vim.bo[current_buf].buftype == 'terminal'

  if is_terminal then
    -- In terminal mode, exit terminal mode first, then navigate
    vim.cmd 'stopinsert'
  end

  -- Store current window as last active before navigating
  last_active_window = current_window

  -- Navigate to the window in the specified direction
  local success = pcall(function()
    vim.cmd('wincmd ' .. direction)
  end)

  -- If navigation failed (no window in that direction), show a message
  if not success then
    vim.notify('No window in ' .. direction .. ' direction', vim.log.levels.INFO)
  end
end

-- Function to navigate to last active window
local function navigate_last_active()
  if last_active_window and vim.api.nvim_win_is_valid(last_active_window) then
    vim.api.nvim_set_current_win(last_active_window)
  else
    vim.notify('No last active window available', vim.log.levels.INFO)
  end
end

-- Window navigation keymaps - ensure they work reliably
-- Use <C-w> commands directly for maximum compatibility
-- Using Ctrl+Shift+jklh for navigation (primary mappings)
vim.keymap.set('n', '<C-S-j>', '<C-w>j', { desc = 'Navigate down (Ctrl+Shift+J)', noremap = true, silent = true })
vim.keymap.set('n', '<C-S-k>', '<C-w>k', { desc = 'Navigate up (Ctrl+Shift+K)', noremap = true, silent = true })
vim.keymap.set('n', '<C-S-l>', '<C-w>l', { desc = 'Navigate right (Ctrl+Shift+L)', noremap = true, silent = true })
vim.keymap.set('n', '<C-S-h>', '<C-w>h', { desc = 'Navigate left (Ctrl+Shift+H)', noremap = true, silent = true })

-- Alternative key codes for better terminal compatibility
-- Note: <C-h/j/k/l> keymaps removed to avoid conflicts with smart-splits plugin


-- Alternative navigation using vim.cmd for better compatibility
vim.keymap.set('n', '<C-Left>', '<C-w>h', { desc = 'Navigate left (alternative)', noremap = true, silent = true })
vim.keymap.set('n', '<C-Down>', '<C-w>j', { desc = 'Navigate down (alternative)', noremap = true, silent = true })
vim.keymap.set('n', '<C-Up>', '<C-w>k', { desc = 'Navigate up (alternative)', noremap = true, silent = true })
vim.keymap.set('n', '<C-Right>', '<C-w>l', { desc = 'Navigate right (alternative)', noremap = true, silent = true })


-- Additional fallback keybindings for terminal emulator compatibility
-- Some terminals might not send Ctrl+hjkl properly
-- Note: <leader>hjkl keymaps removed to avoid conflicts with smart-splits plugin

-- Terminal mode navigation - primary mappings (Ctrl+Shift+jklh)
vim.keymap.set('t', '<C-S-h>', [[<C-\><C-n><C-w>h]], { desc = 'Navigate left from terminal (Ctrl+Shift+H)', noremap = true, silent = true })
vim.keymap.set('t', '<C-S-j>', [[<C-\><C-n><C-w>j]], { desc = 'Navigate down from terminal (Ctrl+Shift+J)', noremap = true, silent = true })
vim.keymap.set('t', '<C-S-k>', [[<C-\><C-n><C-w>k]], { desc = 'Navigate up from terminal (Ctrl+Shift+K)', noremap = true, silent = true })
vim.keymap.set('t', '<C-S-l>', [[<C-\><C-n><C-w>l]], { desc = 'Navigate right from terminal (Ctrl+Shift+L)', noremap = true, silent = true })

-- Alternative syntax for terminal mode (Ctrl+jklh)
-- Note: <C-h/j/k/l> terminal keymaps removed to avoid conflicts with smart-splits plugin

-- Navigate to last active window (similar to tmux's last-pane functionality)
vim.keymap.set('n', '<C-\\>', navigate_last_active, {
  desc = 'Navigate to last active window',
  noremap = true,
  silent = true,
})
vim.keymap.set('t', '<C-\\>', function()
  vim.cmd 'stopinsert'
  navigate_last_active()
end, {
  desc = 'Navigate to last active window from terminal',
  noremap = true,
  silent = true,
})

-- Track window changes to maintain last active window
vim.api.nvim_create_autocmd('WinEnter', {
  callback = function()
    last_active_window = vim.api.nvim_get_current_win()
  end,
})

-- Debug function to verify keybindings are working
-- Call with :lua verify_navigation_keys()
function _G.verify_navigation_keys()
  print("Verifying navigation keybindings...")
  local mappings = {
    '<C-S-j>', '<C-S-k>', '<C-S-l>', '<C-S-h>',  -- Primary Ctrl+Shift mappings
    '<C-Left>', '<C-Down>', '<C-Up>', '<C-Right>' -- Arrow key alternatives
  }
  
  for _, key in ipairs(mappings) do
    local ok, result = pcall(vim.api.nvim_get_keymap, 'n')
    if ok then
      local found = false
      for _, map in ipairs(result) do
        if map.lhs == key then
          print(string.format("✓ %s -> %s", key, map.rhs))
          found = true
          break
        end
      end
      if not found then
        print(string.format("✗ %s not found", key))
      end
    end
  end
end

-- Window resizing keymaps (Alt + hjkl)
vim.keymap.set('n', '<A-h>', '<C-w><', { desc = 'Resize window left', noremap = true, silent = true })
vim.keymap.set('n', '<A-j>', '<C-w>-', { desc = 'Resize window down', noremap = true, silent = true })
vim.keymap.set('n', '<A-k>', '<C-w>+', { desc = 'Resize window up', noremap = true, silent = true })
vim.keymap.set('n', '<A-l>', '<C-w>>', { desc = 'Resize window right', noremap = true, silent = true })

-- Terminal mode window resizing
vim.keymap.set('t', '<A-h>', function()
  vim.cmd 'stopinsert'
  vim.cmd 'wincmd <'
end, { desc = 'Resize window left from terminal', noremap = true, silent = true })

vim.keymap.set('t', '<A-j>', function()
  vim.cmd 'stopinsert'
  vim.cmd 'wincmd -'
end, { desc = 'Resize window down from terminal', noremap = true, silent = true })

vim.keymap.set('t', '<A-k>', function()
  vim.cmd 'stopinsert'
  vim.cmd 'wincmd +'
end, { desc = 'Resize window up from terminal', noremap = true, silent = true })

vim.keymap.set('t', '<A-l>', function()
  vim.cmd 'stopinsert'
  vim.cmd 'wincmd >'
end, { desc = 'Resize window right from terminal', noremap = true, silent = true })

-- Ghostty terminal specific keymaps
-- Open terminal in current directory
vim.keymap.set('n', '<leader>tt', '<cmd>terminal<CR>', { desc = 'Open terminal' })
vim.keymap.set('n', '<leader>tf', '<cmd>terminal<CR>', { desc = 'Open terminal in current file directory' })

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

vim.keymap.set('n', '\\', '<cmd>lua MiniFiles.open()<CR>')

vim.keymap.set({ 'n', 'v' }, '<leader>ia', '<cmd>ChatGPT<CR>', { desc = 'ChatGPT' })
vim.keymap.set({ 'n', 'v' }, '<leader>ie', '"<cmd>ChatGPTEditWithInstruction<CR>"', { desc = 'Edit with instruction' })
vim.keymap.set({ 'n', 'v' }, '<leader>ig', '<cmd>ChatGPTRun grammar_correction<CR>', { desc = 'Grammar Correction' })
vim.keymap.set({ 'n', 'v' }, '<leader>id', '<cmd>ChatGPTRun docstring<CR>', { desc = 'Create Docstring' })
vim.keymap.set({ 'n', 'v' }, '<leader>ix', '<cmd>ChatGPTRun explain_code<CR>', { desc = 'Explain Code' })
vim.keymap.set({ 'n', 'v' }, '<leader>if', '<cmd>ChatGPTRun fix_bugs<CR>', { desc = 'Fix Bugs' })
vim.keymap.set({ 'n', 'v' }, '<leader>is', '<cmd>ChatGPTRun summarize<CR>', { desc = 'Summarize Text' })
vim.keymap.set({ 'n', 'v' }, '<leader>il', '<cmd>ChatGPTRun code_readability_analysis<CR>', { desc = 'Code Readability Analysis' })
-- vim: ts=2 sts=2 sw=2 et
