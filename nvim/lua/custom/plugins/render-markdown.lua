return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    opts = {},
    keys = {
      {
        '<leader>mc',
        function()
          local markdown = require('render-markdown')
          local state = require('render-markdown.state')

          if state.enabled then
            markdown.disable()
            vim.wo.conceallevel = 0
            vim.wo.concealcursor = ''
            vim.notify('Markdown plain text enabled')
          else
            markdown.enable()
            vim.wo.conceallevel = 2
            vim.wo.concealcursor = 'nc'
            vim.notify('Markdown rendering enabled')
          end
        end,
        desc = 'Markdown Plain Text Toggle',
      },
    },
    ft = { 'markdown' },
  },
}
