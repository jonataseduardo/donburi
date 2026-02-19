-- Seamless split navigation across Neovim and tmux panes
-- Ctrl+hjkl navigates (crosses neovim/tmux boundary)
-- Resize: Ctrl+w H/J/K/L in neovim, prefix+hjkl in tmux (see keymaps.lua, tmux.conf)
return {
  'mrjones2014/smart-splits.nvim',
  lazy = false,
  config = function()
    local smart_splits = require('smart-splits')
    smart_splits.setup {
      at_edge = 'stop',
      -- Seamless navigation between neovim splits and tmux panes
      multiplexer_integration = 'tmux',
      -- When a tmux pane is zoomed, don't navigate out of neovim
      disable_multiplexer_nav_when_zoomed = true,
    }

    -- Ctrl+hjkl for navigation (crosses neovim/tmux boundary)
    vim.keymap.set('n', '<C-h>', smart_splits.move_cursor_left, { desc = 'Navigate left (smart-splits)' })
    vim.keymap.set('n', '<C-j>', smart_splits.move_cursor_down, { desc = 'Navigate down (smart-splits)' })
    vim.keymap.set('n', '<C-k>', smart_splits.move_cursor_up, { desc = 'Navigate up (smart-splits)' })
    vim.keymap.set('n', '<C-l>', smart_splits.move_cursor_right, { desc = 'Navigate right (smart-splits)' })
  end,
}
-- vim: ts=2 sts=2 sw=2 et
