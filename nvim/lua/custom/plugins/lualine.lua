return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    lazy = false,
    priority = 1000,
    config = function()
      -- Vibrant Kanagawa palette (matching tmux bar and aerospace borders)
      local colors = {
        bg = '#2A2A37', -- sumiInk3 (matches tmux bar bg)
        fg = '#DCD7BA', -- fujiWhite
        dark = '#1F1F28', -- sumiInk1
        orange = '#FF9E64', -- surimiOrange (active accent, matches aerospace)
        blue = '#7FB4CA', -- springBlue
        yellow = '#E6C384', -- carpYellow
        violet = '#957FB8', -- oniViolet
        green = '#98BB6C', -- springGreen
        red = '#FF5D62', -- peachRed
        gray = '#727169', -- fujiGray
      }

      local kanagawa_vibrant = {
        normal = {
          a = { bg = colors.orange, fg = colors.dark, gui = 'bold' },
          b = { bg = colors.bg, fg = colors.orange },
          c = { bg = colors.dark, fg = colors.fg },
        },
        insert = {
          a = { bg = colors.green, fg = colors.dark, gui = 'bold' },
          b = { bg = colors.bg, fg = colors.green },
        },
        visual = {
          a = { bg = colors.red, fg = colors.dark, gui = 'bold' },
          b = { bg = colors.bg, fg = colors.red },
        },
        replace = {
          a = { bg = colors.violet, fg = colors.dark, gui = 'bold' },
          b = { bg = colors.bg, fg = colors.violet },
        },
        command = {
          a = { bg = colors.yellow, fg = colors.dark, gui = 'bold' },
          b = { bg = colors.bg, fg = colors.yellow },
        },
        inactive = {
          a = { bg = colors.bg, fg = colors.gray },
          b = { bg = colors.dark, fg = colors.gray },
          c = { bg = colors.dark, fg = colors.gray },
        },
      }

      require('lualine').setup {
        options = {
          icons_enabled = true,
          theme = kanagawa_vibrant,
          section_separators = { left = '', right = '' },
          component_separators = { left = '', right = '' },
          globalstatus = true,
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff' },
          lualine_c = { { 'filename', path = 1 } },
          lualine_x = { 'diagnostics', 'filetype' },
          lualine_y = { 'encoding' },
          lualine_z = { 'location', 'progress' },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { 'filename', path = 1 } },
          lualine_x = { 'location' },
          lualine_y = {},
          lualine_z = {},
        },
      }
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
