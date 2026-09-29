return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    -- The `master` branch is archived and breaks on Neovim >= 0.12
    -- (directive handlers receive a list of nodes, causing
    -- "attempt to call method 'range' (a nil value)" in markdown code fences).
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    config = function()
      local ts = require('nvim-treesitter')

      local ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
      ts.install(ensure_installed)

      -- Languages that rely on vim's regex highlighting / indent instead of treesitter
      local disable_highlight = { 'ruby' }
      local disable_indent = { 'ruby' }

      local function start(buf, lang)
        if not vim.tbl_contains(disable_highlight, lang) then
          pcall(vim.treesitter.start, buf, lang)
        end
        if not vim.tbl_contains(disable_indent, lang) then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('kickstart-treesitter', { clear = true }),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if not lang then
            return
          end
          if vim.treesitter.language.add(lang) then
            start(ev.buf, lang)
          elseif vim.tbl_contains(ts.get_available(), lang) then
            -- Autoinstall languages that are not installed
            ts.install({ lang }):await(function()
              if vim.api.nvim_buf_is_valid(ev.buf) then
                start(ev.buf, lang)
              end
            end)
          end
        end,
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
