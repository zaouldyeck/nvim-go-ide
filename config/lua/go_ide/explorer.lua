local M = {}

-- Keep Explorer commands in one place for the startup hook and global shortcuts.
function M.open()
  require('neo-tree.command').execute({ action = 'show', source = 'filesystem', position = 'left' })
end

function M.toggle()
  require('neo-tree.command').execute({ action = 'focus', source = 'filesystem', position = 'left', toggle = true })
end

function M.reveal()
  require('neo-tree.command').execute({ action = 'focus', source = 'filesystem', position = 'left', reveal = true })
end

return M
