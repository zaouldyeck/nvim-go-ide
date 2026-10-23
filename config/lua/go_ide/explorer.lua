local M = {}

-- Keep Explorer commands in one place for the startup hook and global shortcuts.
function M.open()
  require('neo-tree.command').execute({ action = 'show', source = 'filesystem', position = 'left' })
end

function M.close()
  require('neo-tree.command').execute({ action = 'close', source = 'filesystem', position = 'left' })
end

function M.is_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'neo-tree' then return true end
    end
  end
  return false
end

function M.toggle()
  require('neo-tree.command').execute({ action = 'focus', source = 'filesystem', position = 'left', toggle = true })
end

function M.reveal()
  require('neo-tree.command').execute({ action = 'focus', source = 'filesystem', position = 'left', reveal = true })
end

return M
