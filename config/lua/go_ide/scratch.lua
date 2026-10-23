local M = {}

function M.go()
  local project = require('go_ide.project')
  local root = project.root(vim.api.nvim_buf_get_name(0))
  if vim.fn.filereadable(root .. '/go.mod') ~= 1 and vim.fn.filereadable(root .. '/go.work') ~= 1 then
    vim.notify('Open a Go module/workspace before creating a scratch buffer.', vim.log.levels.WARN)
    return
  end
  vim.cmd('enew')
  local buf = vim.api.nvim_get_current_buf()
  local name = string.format('%s/.nvim-go-scratch-%d.go', root, vim.fn.getpid())
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].buftype = 'acwrite'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'go'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    'package main',
    '',
    'func main() {',
    '\t',
    '}',
  })
  vim.api.nvim_create_autocmd('BufWriteCmd', {
    buffer = buf,
    callback = function() vim.bo[buf].modified = false end,
  })
  vim.api.nvim_win_set_cursor(0, { 4, 1 })
  vim.notify('Scratch Go buffer: never written to disk')
end

function M.setup()
  vim.api.nvim_create_user_command('GoScratch', M.go, { desc = 'Open an in-module Go scratch buffer' })
end

return M
