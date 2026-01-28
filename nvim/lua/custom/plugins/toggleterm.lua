return {
  {
    'akinsho/toggleterm.nvim',
    event = 'VeryLazy',
    opts = {
      size = 20,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 2,
      start_in_insert = true,
      insert_mappings = true,
      persist_size = false,
      direction = 'horizontal',
      close_on_exit = true,
      shell = vim.env.SHELL or '/bin/zsh',
      float_opts = {
        border = 'rounded',
        winblend = 0,
        highlights = {
          border = 'Normal',
          background = 'Normal',
        },
      },
    },
    config = function(_, opts)
      require('toggleterm').setup(opts)

      function _G.set_terminal_keymaps()
        local opts_local = { noremap = true, silent = true }
        local trim_spaces = false

        -- Exit terminal mode
        vim.keymap.set('t', '<esc>', [[<C-\><C-n>]], opts_local)

        -- Send lines to terminal functionality
        vim.keymap.set({ 'n', 'v' }, '<leader>tl', function()
          require('toggleterm').send_lines_to_terminal('single_line', trim_spaces, { args = vim.v.count, trim_spaces = trim_spaces })
        end, { desc = 'Send lines to terminal' })

        vim.keymap.set('v', '<leader>tv', function()
          require('toggleterm').send_lines_to_terminal('visual_lines', trim_spaces, { args = vim.v.count, trim_spaces = trim_spaces })
        end, { desc = 'Send visual lines to terminal' })

        vim.keymap.set('v', '<leader>ts', function()
          require('toggleterm').send_lines_to_terminal('visual_selection', trim_spaces, { args = vim.v.count, trim_spaces = trim_spaces })
        end, { desc = 'Send visual selection to terminal' })

        -- Window operations in terminal mode (basic functionality)
        vim.keymap.set('t', '<C-w>', [[<C-\><C-n><C-w>]], opts_local)
      end

      -- Apply keymaps to all terminal types
      vim.cmd 'autocmd! TermOpen * lua set_terminal_keymaps()'
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et