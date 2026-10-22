local s = require('go_ide.settings')
local M = { panels = {}, minimap_enabled = s.minimap, breadcrumbs_enabled = s.breadcrumbs ~= false }
local breadcrumb_winbar = '%{%v:lua.GoIdeBreadcrumb()%}'
local function editor_winbar()
  if M.breadcrumbs_enabled then return breadcrumb_winbar end
  -- Keep the breathing room even when breadcrumbs are toggled off.
  return s.editor_top_padding ~= false and ' ' or ''
end

local function escape_tabline(text)
  return (text or ''):gsub('%%', '%%%%')
end

local function explorer_tab_offset()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'neo-tree' then
        local pos = vim.api.nvim_win_get_position(win)
        if pos[2] == 0 then return vim.api.nvim_win_get_width(win) end
      end
    end
  end
  return 0
end

local function editor_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == '' then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == '' and vim.bo[buf].filetype ~= 'neo-tree'
        and vim.api.nvim_buf_get_name(buf) ~= '' then
        return win
      end
    end
  end
end

function M.tabline()
  local out = {}
  local offset = explorer_tab_offset()
  if offset > 0 then
    local label = ' Explorer'
    local pad = math.max(0, offset - vim.fn.strdisplaywidth(label))
    out[#out + 1] = '%#GoIdeTabExplorer#' .. label .. string.rep(' ', pad)
  end

  local current = M.last_editor_buf
  if not current or not vim.api.nvim_buf_is_valid(current) then
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= '' then current = buf end
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted and vim.bo[buf].buftype == '' then
      local path = vim.api.nvim_buf_get_name(buf)
      if path ~= '' then
        local name = vim.fn.fnamemodify(path, ':t')
        local icon = ''
        if s.icons then
          local ok, devicons = pcall(require, 'nvim-web-devicons')
          if ok then icon = devicons.get_icon(name, vim.bo[buf].filetype, { default = true }) or '' end
        end
        local label = (icon ~= '' and (icon .. '  ') or '') .. name
        if vim.bo[buf].modified then label = label .. '  ●' end
        local click = '%' .. buf .. '@v:lua.GoIdeTabClick@'
        if buf == current then
          out[#out + 1] = click
            .. '%#GoIdeTabCap#'
            .. '%#GoIdeTabActive# ' .. escape_tabline(label) .. ' '
            .. '%#GoIdeTabCap#%T'
            .. '%#GoIdeTabFill# '
        else
          out[#out + 1] = click
            .. '%#GoIdeTabInactive#  ' .. escape_tabline(label) .. '  %T'
        end
      end
    end
  end
  out[#out + 1] = '%#GoIdeTabFill#'
  return table.concat(out)
end

function M.tab_click(buf, _, button)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if button == 'm' then M.close_buffer(buf); return end
    if button ~= 'l' then return end
    local win = editor_window()
    if win then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_buf(win, buf)
    else
      vim.api.nvim_set_current_buf(buf)
    end
    M.last_editor_buf = buf
  end)
end
function M.close_buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then return end
  -- Confirmation belongs to the editor: never discard unsaved work on a tab click.
  if vim.bo[buf].modified then
    local choice = vim.fn.confirm('Save changes to ' .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t') .. '?', '&Save\n&Discard\n&Cancel', 3)
    if choice == 1 then
      local ok = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd('write') end)
      if not ok then return end
    elseif choice ~= 2 then return end
  end
  local replacement
  for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
    if candidate ~= buf and vim.bo[candidate].buflisted and vim.bo[candidate].buftype == '' then replacement = candidate; break end
  end
  replacement = replacement or vim.api.nvim_create_buf(true, false)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do vim.api.nvim_win_set_buf(win, replacement) end
  vim.api.nvim_buf_delete(buf, { force = true })
end
function M.breadcrumb()
  if not M.breadcrumbs_enabled then return '' end
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= '' or vim.bo[buf].filetype == '' then return '' end
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t'):gsub('%%', '%%%%')
  if name == '' then return '' end
  local prefix = ''
  if s.icons then
    local icon = require('nvim-web-devicons').get_icon(name, vim.bo[buf].filetype, { default = true })
    prefix = '%#DevIconGo#' .. (icon or '') .. '  '
  end
  local value = '  ' .. prefix .. '%#GoIdeBreadcrumbFile#' .. name
  local navic = require('nvim-navic')
  if navic.is_available() then
    local location = navic.get_location()
    if location ~= '' then value = value .. '%#GoIdeBreadcrumbSeparator#  ›  ' .. location end
  end
  return value
end
function M.refresh_breadcrumbs()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == ''
      and vim.api.nvim_win_get_config(win).relative == '' then
      vim.wo[win].winbar = editor_winbar()
    end
  end
end
function M.toggle_breadcrumbs()
  M.breadcrumbs_enabled = not M.breadcrumbs_enabled
  M.refresh_breadcrumbs()
  vim.notify('Breadcrumbs ' .. (M.breadcrumbs_enabled and 'on' or 'off'))
end
function M.set_panel(win, active)
  if not vim.api.nvim_win_is_valid(win) then return end
  M.panels[win] = active
  local names = { { 'problems', 'Problems' }, { 'output', 'Output' }, { 'debug', 'Debug Console' }, { 'terminal', 'Terminal' } }
  local result = '%#GoIdePanelFill# '
  for i, pair in ipairs(names) do
    local text = pair[2]
    if pair[1] == 'problems' then
      local count = #vim.diagnostic.get()
      if count > 0 then text = text .. ' ' .. count end
    end
    result = result .. '%' .. i .. '@v:lua.GoIdePanelClick@%#GoIdePanel' .. (pair[1] == active and 'Active' or 'Inactive') .. '# ' .. text .. ' %T%#GoIdePanelFill#  '
  end
  vim.wo[win].winbar = result
end
function M.open_panel(which)
  local was_open = false
  for win, kind in pairs(M.panels) do
    if kind == which and vim.api.nvim_win_is_valid(win) then
      was_open = true
      vim.api.nvim_set_current_win(win)
      break
    end
  end
  if was_open then return end
  if which ~= 'terminal' then require('go_ide.terminal').close() end
  require('go_ide.go').close_run()
  if which ~= 'output' then require('go_ide.go').close_output() end
  if which ~= 'problems' then require('trouble').close('diagnostics') end
  if which ~= 'debug' then require('dap').repl.close() end
  if which == 'problems' then
    require('trouble').toggle('diagnostics')
  elseif which == 'output' then
    require('go_ide.go').toggle_output()
  elseif which == 'debug' then
    require('dap').repl.open({}, 'botright split')
    M.set_panel(vim.api.nvim_get_current_win(), 'debug')
  elseif which == 'terminal' then
    require('go_ide.terminal').toggle()
  end
end
function M.refresh_minimap()
  local cw = require('codewindow')
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  if vim.bo[buf].filetype == 'Codewindow' then return end
  if not M.minimap_enabled or vim.o.columns < s.minimap_min_columns
    or vim.bo[buf].buftype ~= '' or vim.bo[buf].filetype == ''
    or vim.api.nvim_win_get_width(win) < 95 or vim.api.nvim_buf_line_count(buf) > 5000
    or vim.api.nvim_win_get_config(win).relative ~= '' then
    cw.close_minimap()
    return
  end
  cw.open_minimap()
end
function M.toggle_minimap()
  M.minimap_enabled = not M.minimap_enabled
  M.refresh_minimap()
  vim.notify('Minimap ' .. (M.minimap_enabled and 'on (wide windows)' or 'off'))
end
function M.setup()
  _G.GoIdeBreadcrumb = M.breadcrumb
  _G.GoIdeTabline = M.tabline
  _G.GoIdeTabClick = M.tab_click
  vim.o.tabline = '%!v:lua.GoIdeTabline()'
  _G.GoIdePanelClick = function(index)
    vim.schedule(function() M.open_panel(({ 'problems', 'output', 'debug', 'terminal' })[index]) end)
  end
  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter', 'FileType' }, {
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_config(win).relative ~= '' then return end
      if vim.bo.buftype == '' then
        M.panels[win] = nil
        if vim.api.nvim_buf_get_name(0) ~= '' then M.last_editor_buf = vim.api.nvim_get_current_buf() end
        vim.wo.winbar = editor_winbar()
      elseif vim.bo.filetype == 'goideoutput' then M.set_panel(vim.api.nvim_get_current_win(), 'output')
      elseif vim.bo.filetype == 'Trouble' then M.set_panel(vim.api.nvim_get_current_win(), 'problems')
      elseif vim.wo.winbar == ' ' or vim.wo.winbar == breadcrumb_winbar then
        -- A split may inherit our header before becoming an Explorer/help pane.
        vim.wo.winbar = ''
      end
    end,
  })
  M.refresh_breadcrumbs()
  vim.api.nvim_create_autocmd({ 'BufAdd', 'BufDelete', 'BufModifiedSet', 'BufEnter' }, {
    callback = function() vim.schedule(function() pcall(vim.cmd, 'redrawtabline') end) end,
  })
  vim.api.nvim_create_autocmd('DiagnosticChanged', {
    callback = function()
      for win, kind in pairs(M.panels) do
        if vim.api.nvim_win_is_valid(win) then M.set_panel(win, kind) else M.panels[win] = nil end
      end
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter', 'VimResized' }, {
    callback = function()
      if #vim.api.nvim_list_uis() > 0 then vim.schedule(M.refresh_minimap) end
    end,
  })
  vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
      if #vim.api.nvim_list_uis() == 0 then return end
      vim.schedule(function()
        if s.auto_explorer and vim.bo.buftype == '' then
          local previous = vim.api.nvim_get_current_win()
          require('go_ide.explorer').open()
          if vim.api.nvim_win_is_valid(previous) then vim.api.nvim_set_current_win(previous) end
        end
        M.refresh_minimap()
      end)
    end,
  })
  vim.api.nvim_create_user_command('GoIdeHealth', function() vim.cmd('checkhealth go_ide') end, {})
  vim.api.nvim_create_user_command('GoIdeBreadcrumbs', M.toggle_breadcrumbs, {})
  vim.api.nvim_create_user_command('GoIdeSettings', function()
    vim.cmd.edit(vim.fn.stdpath('config') .. '/lua/go_ide/settings.lua')
  end, {})
  vim.api.nvim_create_user_command('GoIdeGuide', function()
    local guide = vim.fn.stdpath('config') .. '/docs/GETTING_STARTED.md'
    if vim.fn.filereadable(guide) == 1 then vim.cmd.edit(guide)
    else vim.notify('Open docs/GETTING_STARTED.md from the downloaded package.') end
  end, {})
end
return M
