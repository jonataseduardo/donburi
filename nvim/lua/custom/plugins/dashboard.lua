-- Donburi ASCII art dashboard using snacks.nvim
-- Colors match the Kanagawa palette from img/donburi-ascii.svg

local header_lines = {
  {
    '████████▄   ▄██████▄  ███▄▄▄▄   ▀█████████▄  ███    █▄     ▄████████  ▄█ ',
    hl = 'DonburiLine1',
  },
  {
    '███   ▀███ ███    ███ ███▀▀▀██▄   ███    ███ ███    ███   ███    ███ ███ ',
    hl = 'DonburiLine2',
  },
  {
    '███    ███ ███    ███ ███   ███   ███    ███ ███    ███   ███    ███ ███▌',
    hl = 'DonburiLine3',
  },
  {
    '███    ███ ███    ███ ███   ███  ▄███▄▄▄██▀  ███    ███  ▄███▄▄▄▄██▀ ███▌',
    hl = 'DonburiLine4',
  },
  {
    '███    ███ ███    ███ ███   ███ ▀▀███▀▀▀██▄  ███    ███ ▀▀███▀▀▀▀▀   ███▌',
    hl = 'DonburiLine5',
  },
  {
    '███    ███ ███    ███ ███   ███   ███    ██▄ ███    ███ ▀███████████ ███ ',
    hl = 'DonburiLine6',
  },
  {
    '███   ▄███ ███    ███ ███   ███   ███    ███ ███    ███   ███    ███ ███ ',
    hl = 'DonburiLine7',
  },
  {
    '████████▀   ▀██████▀   ▀█   █▀  ▄█████████▀  ████████▀    ███    ███ █▀  ',
    hl = 'DonburiLine8',
  },
  { '                                                          ███    ███     ', hl = 'DonburiLine9' },
}

local colors = {
  DonburiLine1 = '#DCD7BA', -- fujiWhite
  DonburiLine2 = '#C8C093', -- oldWhite
  DonburiLine3 = '#E6C384', -- carpYellow
  DonburiLine4 = '#FFA066', -- surimiOrange
  DonburiLine5 = '#D27E99', -- sakuraPink
  DonburiLine6 = '#957FB8', -- oniViolet
  DonburiLine7 = '#7E9CD8', -- crystalBlue
  DonburiLine8 = '#7FB4CA', -- springBlue
  DonburiLine9 = '#6A9589', -- springGreen
}

return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      dashboard = {
        width = 75,
        preset = {
          keys = {
            { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
            { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
            { icon = ' ', key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = ' ', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = ' ', key = 'c', desc = 'Config', action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = '󰒲 ', key = 'L', desc = 'Lazy', action = ':Lazy', enabled = package.loaded.lazy ~= nil },
            { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
          },
        },
        sections = {
          {
            function()
              -- Define highlight groups for each line
              for name, color in pairs(colors) do
                vim.api.nvim_set_hl(0, name, { fg = color })
              end
              -- Build section items, one per line
              local items = {}
              for _, line in ipairs(header_lines) do
                table.insert(items, {
                  text = { { line[1], hl = line.hl } },
                  align = 'center',
                })
              end
              return items
            end,
            padding = 2,
          },
          { section = 'keys', gap = 1, padding = 1 },
          { section = 'startup' },
        },
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
