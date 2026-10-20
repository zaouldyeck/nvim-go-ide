local M = { buf = nil, win = nil, job = nil }
function M.is_open() return M.win and vim.api.nvim_win_is_valid(M.win) end
function M.close()
  if M.is_open() then vim.api.nvim_win_close(M.win, true) end
  M.win = nil
end
function M.toggle()
  if M.is_open() then M.close(); return end
  if M.job and vim.fn.jobwait({ M.job }, 0)[1] ~= -1 then
    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then vim.api.nvim_buf_delete(M.buf, { force = true }) end
    M.buf, M.job = nil, nil
  end
  local cwd = vim.fn.getcwd()
  vim.cmd('botright ' .. require('go_ide.settings').terminal_height .. 'split')
  M.win = vim.api.nvim_get_current_win()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(M.win, M.buf)
    vim.bo[M.buf].bufhidden = 'hide'
    M.job = vim.fn.jobstart({ vim.o.shell }, { term = true, cwd = cwd })
    if M.job <= 0 then vim.notify('Could not start shell: ' .. vim.o.shell, vim.log.levels.ERROR) end
  else
    vim.api.nvim_win_set_buf(M.win, M.buf)
  end
  vim.wo[M.win].number = false
  vim.wo[M.win].relativenumber = false
  vim.wo[M.win].signcolumn = 'no'
  require('go_ide.ui').set_panel(M.win, 'terminal')
  vim.cmd('startinsert')
end
function M.setup()
  vim.api.nvim_create_user_command('GoTerminal', M.toggle, { desc = 'Toggle the project terminal' })
  vim.api.nvim_create_autocmd('TermOpen', {
    callback = function()
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.signcolumn = 'no'
    end,
  })
end
return M
