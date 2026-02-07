-- Open diffview against the repo's default branch (main/master/develop)
-- so PR diffs show file-by-file with full navigation
local function pr_diff_with_diffview()
  local base = vim.fn.system('git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null'):gsub('%s+', '')
  if base == '' then
    -- fallback: try common branch names
    for _, branch in ipairs { 'main', 'master', 'develop' } do
      local check = vim.fn.system('git rev-parse --verify origin/' .. branch .. ' 2>/dev/null'):gsub('%s+', '')
      if check ~= '' then
        base = 'origin/' .. branch
        break
      end
    end
  end
  if base == '' then
    vim.notify('Could not detect base branch for PR diff', vim.log.levels.ERROR)
    return
  end
  -- strip refs/remotes/ prefix for DiffviewOpen
  base = base:gsub('^refs/remotes/', '')
  vim.cmd('DiffviewOpen ' .. base .. '...HEAD')
end

return {
  { -- GitHub PR review and issue management
    'pwntester/octo.nvim',
    cmd = 'Octo',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
      'sindrets/diffview.nvim',
    },
    keys = {
      -- PR workflow
      { '<leader>ol', '<cmd>Octo pr list<cr>', desc = 'List pull requests' },
      { '<leader>os', '<cmd>Octo pr search<cr>', desc = 'Search pull requests' },
      { '<leader>oc', '<cmd>Octo pr checkout<cr>', desc = 'Checkout PR branch' },
      { '<leader>od', pr_diff_with_diffview, desc = 'PR diff (file-by-file via diffview)' },
      { '<leader>oD', '<cmd>Octo pr diff<cr>', desc = 'PR diff (raw unified)' },
      { '<leader>om', '<cmd>Octo pr merge<cr>', desc = 'Merge PR' },
      { '<leader>oR', '<cmd>Octo pr ready<cr>', desc = 'Mark PR as ready' },

      -- Review workflow
      { '<leader>orr', '<cmd>Octo review start<cr>', desc = 'Start review' },
      { '<leader>ors', '<cmd>Octo review submit<cr>', desc = 'Submit review' },
      { '<leader>ord', '<cmd>Octo review discard<cr>', desc = 'Discard review' },
      { '<leader>orc', '<cmd>Octo review comments<cr>', desc = 'View review comments' },
      { '<leader>ort', '<cmd>Octo review resume<cr>', desc = 'Resume review' },

      -- Comments and threads
      { '<leader>oca', '<cmd>Octo comment add<cr>', desc = 'Add comment' },
      { '<leader>otr', '<cmd>Octo thread resolve<cr>', desc = 'Resolve thread' },
      { '<leader>otu', '<cmd>Octo thread unresolve<cr>', desc = 'Unresolve thread' },

      -- Issues
      { '<leader>oil', '<cmd>Octo issue list<cr>', desc = 'List issues' },
      { '<leader>ois', '<cmd>Octo issue search<cr>', desc = 'Search issues' },
      { '<leader>oic', '<cmd>Octo issue create<cr>', desc = 'Create issue' },

      -- Quick actions
      { '<leader>oo', '<cmd>Octo actions<cr>', desc = 'Octo actions menu' },
      { '<leader>ow', '<cmd>Octo pr browser<cr>', desc = 'Open PR in browser' },
    },
    opts = {
      use_local_fs = false,
      enable_builtin = true,
      default_remote = { 'origin' },
      default_merge_method = 'merge',
      picker = 'telescope',
      suppress_missing_scope = {
        projects_v2 = true,
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
