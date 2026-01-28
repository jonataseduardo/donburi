return {
  'mrjones2014/smart-splits.nvim',
  lazy = false, -- Load immediately
  config = function()
    local smart_splits = require('smart-splits')
    smart_splits.setup({
      at_edge = 'stop',
    })
    
    -- Ctrl+hjkl is reserved for Aerospace window navigation
    -- Use vim's native Ctrl+w+hjkl for splits, or leader+hjkl as fallback
    -- Keymaps using leader key for split navigation
    vim.keymap.set('n', '<leader>h', function() smart_splits.move_cursor_left() end, { desc = 'Move cursor left (smart-splits)' })
    vim.keymap.set('n', '<leader>j', function() smart_splits.move_cursor_down() end, { desc = 'Move cursor down (smart-splits)' })
    vim.keymap.set('n', '<leader>k', function() smart_splits.move_cursor_up() end, { desc = 'Move cursor up (smart-splits)' })
    vim.keymap.set('n', '<leader>l', function() smart_splits.move_cursor_right() end, { desc = 'Move cursor right (smart-splits)' })
  end
}