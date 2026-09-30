return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    opts = {},
    keys = {
      {
        '<leader>mc',
        function()
          local markdown = require('render-markdown')
          markdown.toggle()
        end,
        desc = 'Markdown Plain Text Toggle',
      },
    },
    ft = { 'markdown' },
  },
}
