-- Seamless split navigation across Neovim and herdr panes
-- Ctrl+hjkl navigates (crosses neovim/herdr boundary)
-- Resize: Ctrl+w H/J/K/L in neovim, prefix+hjkl in herdr (see keymaps.lua, herdr/config.toml)
-- The herdr side lives in herdr/scripts/navigate.sh (bound to Ctrl+hjkl in herdr/config.toml)
return {
  'smart-splits-nvim/smart-splits.nvim',
  lazy = false,
  config = function()
    local smart_splits = require('smart-splits')
    smart_splits.setup {
      at_edge = 'stop',
      -- Seamless navigation between neovim splits and herdr panes
      multiplexer_integration = 'herdr',
      -- When a herdr pane is zoomed, don't navigate out of neovim
      disable_multiplexer_nav_when_zoomed = true,
    }

    -- smart-splits' herdr backend always reports "not zoomed"; ask herdr so
    -- disable_multiplexer_nav_when_zoomed keeps you inside neovim like under tmux
    require('smart-splits.mux.herdr').current_pane_is_zoomed = function()
      local herdr = vim.env.HERDR_BIN_PATH ~= nil and vim.env.HERDR_BIN_PATH ~= '' and vim.env.HERDR_BIN_PATH or 'herdr'
      local output = vim.fn.system { herdr, 'pane', 'layout', '--current' }
      if vim.v.shell_error ~= 0 then
        return false
      end
      local ok, data = pcall(vim.json.decode, output)
      return ok and type(data) == 'table' and data.result ~= nil and data.result.layout ~= nil and data.result.layout.zoomed == true
    end

    -- Ctrl+hjkl for navigation (crosses neovim/herdr boundary)
    vim.keymap.set('n', '<C-h>', smart_splits.move_cursor_left, { desc = 'Navigate left (smart-splits)' })
    vim.keymap.set('n', '<C-j>', smart_splits.move_cursor_down, { desc = 'Navigate down (smart-splits)' })
    vim.keymap.set('n', '<C-k>', smart_splits.move_cursor_up, { desc = 'Navigate up (smart-splits)' })
    vim.keymap.set('n', '<C-l>', smart_splits.move_cursor_right, { desc = 'Navigate right (smart-splits)' })
  end,
}
-- vim: ts=2 sts=2 sw=2 et
