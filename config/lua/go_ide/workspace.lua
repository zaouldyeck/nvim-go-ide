local M = {}
local state_dir = vim.fn.stdpath('state') .. '/workspaces'
local recent_path = state_dir .. '/recent.json'

local function ensure_dir()
  vim.fn.mkdir(state_dir, 'p')
end

local function session_path(root)
  return state_dir .. '/' .. vim.fn.sha256(root):sub(1, 20) .. '.json'
end

local function read_json(path, fallback)
  if vim.fn.filereadable(path) ~= 1 then return fallback end
  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
  return ok and type(decoded) == 'table' and decoded or fallback
end

local function write_json(path, value)
  ensure_dir()
  local encoded = vim.json.encode(value)
  vim.fn.writefile({ encoded }, path)
end

local function root()
  return require('go_ide.project').root(vim.api.nvim_buf_get_name(0))
end

local function normal_files(root_dir)
  local files = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= '' and vim.startswith(vim.fs.normalize(name), root_dir .. '/') then
        files[#files + 1] = name
      end
    end
  end
  return files
end

local function encode_layout(node, root_dir, positions)
  if not node then return nil end
  if node[1] == 'leaf' then
    local win = node[2]
    if not vim.api.nvim_win_is_valid(win) then return nil end
    local buf = vim.api.nvim_win_get_buf(win)
    local file = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= '' or file == ''
      or not vim.startswith(vim.fs.normalize(file), root_dir .. '/') then return nil end
    positions[file] = vim.api.nvim_win_get_cursor(win)
    return { kind = 'leaf', file = file }
  end
  local children = {}
  for _, child in ipairs(node[2] or {}) do
    local encoded = encode_layout(child, root_dir, positions)
    if encoded then children[#children + 1] = encoded end
  end
  if #children == 0 then return nil end
  if #children == 1 then return children[1] end
  return { kind = node[1], children = children }
end

local function close_extra_editor_windows()
  local keep
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_win_get_config(win).relative == '' and vim.bo[buf].buftype == '' then
      if not keep then keep = win
      elseif vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, false) end
    end
  end
  return keep or vim.api.nvim_get_current_win()
end

local function restore_layout(node, win, opened, positions)
  if not node or not vim.api.nvim_win_is_valid(win) then return end
  if node.kind == 'leaf' then
    local buf = opened[node.file]
    if buf then
      vim.api.nvim_win_set_buf(win, buf)
      local pos = positions and positions[node.file]
      if pos then pcall(vim.api.nvim_win_set_cursor, win, pos) end
    end
    return
  end
  local children = node.children or {}
  if #children == 0 then return end
  restore_layout(children[1], win, opened, positions)
  for index = 2, #children do
    vim.api.nvim_set_current_win(win)
    vim.cmd(node.kind == 'row' and 'rightbelow vsplit' or 'belowright split')
    local child_win = vim.api.nvim_get_current_win()
    restore_layout(children[index], child_win, opened, positions)
  end
end

function M.record(root_dir)
  root_dir = vim.fs.normalize(root_dir or root())
  local recent = read_json(recent_path, {})
  local next_recent = { root_dir }
  for _, item in ipairs(recent) do
    if item ~= root_dir and vim.fn.isdirectory(item) == 1 then
      next_recent[#next_recent + 1] = item
    end
  end
  local max = require('go_ide.settings').workspace_max_recent or 20
  while #next_recent > max do table.remove(next_recent) end
  write_json(recent_path, next_recent)
end

function M.save(root_dir)
  root_dir = vim.fs.normalize(root_dir or root())
  if vim.fn.isdirectory(root_dir) ~= 1 then return end
  local ui = require('go_ide.ui')
  local explorer = require('go_ide.explorer')
  local current = vim.api.nvim_buf_get_name(0)
  local positions = {}
  local data = {
    root = root_dir,
    files = normal_files(root_dir),
    current = vim.startswith(current, root_dir .. '/') and current or nil,
    layout = encode_layout(vim.fn.winlayout(), root_dir, positions),
    positions = positions,
    explorer = explorer.is_open(),
    minimap = ui.minimap_enabled,
    breadcrumbs = ui.breadcrumbs_enabled,
  }
  write_json(session_path(root_dir), data)
  M.record(root_dir)
end

local function close_project_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= '' then
      if vim.bo[buf].modified then
        local ok = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd('silent update') end)
        if not ok then return false end
      end
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= '' then
      pcall(vim.api.nvim_buf_delete, buf, { force = false })
    end
  end
  return true
end

function M.restore(root_dir)
  root_dir = vim.fs.normalize(root_dir or root())
  local data = read_json(session_path(root_dir), nil)
  if not data then return false end
  local opened = {}
  for _, file in ipairs(data.files or {}) do
    if vim.fn.filereadable(file) == 1 then
      local buf = vim.fn.bufadd(file)
      vim.fn.bufload(buf)
      opened[file] = buf
    end
  end
  local target = data.current and opened[data.current]
  if not target then
    for _, buf in pairs(opened) do target = buf; break end
  end
  if target then
    local base_win = close_extra_editor_windows()
    if data.layout then restore_layout(data.layout, base_win, opened, data.positions or {})
    else vim.api.nvim_win_set_buf(base_win, target) end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == target then
        vim.api.nvim_set_current_win(win)
        break
      end
    end
  end
  local ui = require('go_ide.ui')
  if data.minimap ~= nil then ui.minimap_enabled = data.minimap end
  if data.breadcrumbs ~= nil then ui.breadcrumbs_enabled = data.breadcrumbs end
  ui.refresh_breadcrumbs()
  ui.refresh_minimap()
  if data.explorer and not require('go_ide.explorer').is_open() then
    local previous = vim.api.nvim_get_current_win()
    require('go_ide.explorer').open()
    if vim.api.nvim_win_is_valid(previous) then vim.api.nvim_set_current_win(previous) end
  end
  M.record(root_dir)
  return target ~= nil
end

function M.switch_to(root_dir)
  root_dir = vim.fs.normalize(root_dir)
  if vim.fn.isdirectory(root_dir) ~= 1 then
    vim.notify('Project directory no longer exists: ' .. root_dir, vim.log.levels.WARN)
    return
  end
  M.save()
  pcall(function() require('trouble').close() end)
  pcall(function() require('codewindow').close_minimap() end)
  pcall(function() require('go_ide.terminal').close() end)
  pcall(function() require('go_ide.explorer').close() end)
  if not close_project_buffers() then
    vim.notify('Could not save all modified project buffers; project switch cancelled.', vim.log.levels.ERROR)
    return
  end
  vim.cmd.cd(vim.fn.fnameescape(root_dir))
  require('go_ide.project').reload()
  vim.cmd('enew')
  if not M.restore(root_dir) then
    local go_mod = root_dir .. '/go.mod'
    if vim.fn.filereadable(go_mod) == 1 then vim.cmd.edit(vim.fn.fnameescape(go_mod)) end
    if require('go_ide.settings').auto_explorer then require('go_ide.explorer').open() end
  end
  require('go_ide.lsp').restart()
  vim.notify('Project: ' .. vim.fn.fnamemodify(root_dir, ':~'))
end

function M.pick()
  pcall(require, 'telescope')
  local recent = read_json(recent_path, {})
  if #recent == 0 then
    vim.notify('No recent Go projects yet.', vim.log.levels.INFO)
    return
  end
  vim.ui.select(recent, {
    prompt = 'Recent Go projects',
    format_item = function(item) return vim.fn.fnamemodify(item, ':~') end,
  }, function(choice)
    if choice then M.switch_to(choice) end
  end)
end

function M.setup()
  ensure_dir()
  local group = vim.api.nvim_create_augroup('GoIDE_Workspaces', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function()
      local file = vim.api.nvim_buf_get_name(0)
      if file ~= '' and vim.bo.buftype == '' then M.record(require('go_ide.project').root(file)) end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function() pcall(M.save) end,
  })
  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    once = true,
    callback = function()
      if require('go_ide.settings').workspace_auto_restore == false then return end
      vim.schedule(function()
        local named_file = false
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.bo[buf].buflisted and vim.bo[buf].buftype == ''
            and vim.api.nvim_buf_get_name(buf) ~= '' and vim.fn.filereadable(vim.api.nvim_buf_get_name(buf)) == 1 then
            named_file = true
            break
          end
        end
        local directory_arg = vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1
        if not named_file or directory_arg then M.restore(root()) end
      end)
    end,
  })
  vim.api.nvim_create_user_command('GoWorkspaceSave', function() M.save() end, {})
  vim.api.nvim_create_user_command('GoWorkspaceRestore', function() M.restore() end, {})
  vim.api.nvim_create_user_command('GoWorkspaceSwitch', M.pick, {})
end

return M
