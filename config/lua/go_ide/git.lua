local M = {}

local function run(args)
  local result = vim.system(args, { text = true }):wait(5000)
  return result.code == 0 and vim.trim(result.stdout or '') or nil
end

local function repo_root()
  return run({ 'git', 'rev-parse', '--show-toplevel' })
end

function M.base()
  local candidates = { 'origin/main', 'origin/master', 'main', 'master' }
  for _, ref in ipairs(candidates) do
    local ok = run({ 'git', 'rev-parse', '--verify', '--quiet', ref })
    if ok then
      local merge = run({ 'git', 'merge-base', 'HEAD', ref })
      if merge then return merge, ref end
    end
  end
  return 'HEAD~1', 'HEAD~1'
end

function M.diff(ref)
  ref = ref or select(1, M.base())
  require('gitsigns').diffthis(ref)
end

function M.review()
  local root = repo_root()
  if not root then vim.notify('Not inside a Git repository.', vim.log.levels.WARN); return end
  local base, label = M.base()
  local output = run({ 'git', '-C', root, 'diff', '--name-only', '--diff-filter=ACMRT', base .. '...HEAD' }) or ''
  local files = vim.split(output, '\n', { trimempty = true })
  if #files == 0 then
    vim.notify('No branch changes against ' .. label)
    return
  end
  vim.ui.select(files, { prompt = 'Changed files vs ' .. label }, function(choice)
    if not choice then return end
    vim.cmd.edit(vim.fn.fnameescape(root .. '/' .. choice))
    vim.schedule(function() require('gitsigns').diffthis(base) end)
  end)
end

function M.hunks()
  require('gitsigns').setqflist('all')
  vim.schedule(function() require('quicker').open({ focus = true, height = 10 }) end)
end

function M.setup()
  vim.api.nvim_create_user_command('GoGitDiff', function(opts) M.diff(opts.args ~= '' and opts.args or nil) end, {
    nargs = '?', desc = 'Diff current file against a revision/branch base',
  })
  vim.api.nvim_create_user_command('GoGitReview', M.review, { desc = 'Review branch-changed files' })
end

return M
