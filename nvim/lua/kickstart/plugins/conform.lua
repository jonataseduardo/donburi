--- Resolve the ruff command based on project context.
--- Priority: 1) uv run ruff (if in a uv project with ruff installed)
---           2) global uv tool ruff (~/.local/bin/ruff)
---           3) uvx ruff (ephemeral fallback)
---@param ctx table conform formatter context with `dirname` field
---@return { cmd: string, extra_args: string[] }
local function resolve_ruff(ctx)
  -- 1. Check if we're in a uv project with ruff available
  local uv_lock = vim.fs.find('uv.lock', { path = ctx.dirname, upward = true })[1]
  if uv_lock then
    local project_root = vim.fn.fnamemodify(uv_lock, ':h')
    local local_ruff = project_root .. '/.venv/bin/ruff'
    if vim.uv.fs_stat(local_ruff) then
      return { cmd = 'uv', extra_args = { 'run', 'ruff' } }
    end
  end

  -- 2. Check global uv tool ruff
  local global_ruff = vim.fn.expand('~/.local/bin/ruff')
  if vim.fn.executable(global_ruff) == 1 then
    return { cmd = global_ruff, extra_args = {} }
  end

  -- 3. Fallback to uvx
  return { cmd = 'uvx', extra_args = { 'ruff' } }
end

--- Create a conform formatter override that resolves ruff dynamically.
---@return table conform formatter spec
local function make_ruff_formatter()
  return {
    command = function(self, ctx)
      return resolve_ruff(ctx).cmd
    end,
    prepend_args = function(self, ctx)
      return resolve_ruff(ctx).extra_args
    end,
  }
end

return {
  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        local lsp_format_opt
        if disable_filetypes[vim.bo[bufnr].filetype] then
          lsp_format_opt = 'never'
        else
          lsp_format_opt = 'fallback'
        end
        return {
          timeout_ms = 1500,
          lsp_format = lsp_format_opt,
        }
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        -- Conform can also run multiple formatters sequentially
        python = {
          -- To fix auto-fixable lint errors.
          'ruff_fix',
          -- To run the Ruff formatter.
          'ruff_format',
          -- To organize the imports.
          'ruff_organize_imports',
        },
        sh = { 'shfmt' },
        -- You can use 'stop_after_first' to run the first available formatter from the list
        javascript = { 'prettierd', 'prettier', stop_after_first = true },
        -- JSON formatting
        json = { 'prettierd', 'prettier', stop_after_first = true },
        jsonc = { 'prettierd', 'prettier', stop_after_first = true },
        -- YAML formatting
        yaml = { 'prettierd', 'prettier', stop_after_first = true },
        yml = { 'prettierd', 'prettier', stop_after_first = true },
        -- Markdown formatting
        markdown = { 'prettierd', 'prettier', stop_after_first = true },
        ['markdown.mdx'] = { 'prettierd', 'prettier', stop_after_first = true },
        -- TOML formatting
        toml = { 'taplo' },
      },
      formatters = {
        injected = { options = { ignore_errors = true } },
        shfmt = {
          prepend_args = { '-i', '2', '-ci' },
        },
        ruff_fix = make_ruff_formatter(),
        ruff_format = make_ruff_formatter(),
        ruff_organize_imports = make_ruff_formatter(),
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
