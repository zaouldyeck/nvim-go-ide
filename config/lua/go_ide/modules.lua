local M = {}

local function go_command(args, cwd)
  local go = require('go_ide.lsp').tool('go')
  local result = vim.system(vim.list_extend({ go }, args), { cwd = cwd, text = true }):wait(15000)
  if result.code ~= 0 then
    vim.notify(vim.trim(result.stderr or 'go command failed'), vim.log.levels.ERROR)
    return nil
  end
  return result.stdout or ''
end

local function parse_line(line)
  local name, version, update = line:match('^(%S+)%s+(%S+)%s+%[(%S+)%]')
  if not name then name, version = line:match('^(%S+)%s+(%S+)') end
  if not name then name = line:match('^(%S+)') end
  return { module = name or line, version = version, update = update, raw = line }
end

local function open_source(item, root)
  local target = item.module .. (item.version and ('@' .. item.version) or '')
  local output = go_command({ 'mod', 'download', '-json', target }, root)
  if not output then return end
  local ok, info = pcall(vim.json.decode, output)
  if not ok or not info.Dir then
    vim.notify('Module source directory unavailable.', vim.log.levels.WARN)
    return
  end
  require('telescope.builtin').find_files({ cwd = info.Dir, prompt_title = item.module })
end

function M.show()
  pcall(require, 'telescope')
  local root = require('go_ide.project').root(vim.api.nvim_buf_get_name(0))
  local output = go_command({ 'list', '-m', '-u', 'all' }, root)
  if not output then return end
  local items = {}
  for _, line in ipairs(vim.split(output, '\n', { trimempty = true })) do
    items[#items + 1] = parse_line(line)
  end
  vim.ui.select(items, {
    prompt = 'Go modules',
    format_item = function(item)
      local text = item.module .. (item.version and ('  ' .. item.version) or '')
      if item.update then text = text .. '  →  ' .. item.update end
      return text
    end,
  }, function(item)
    if not item then return end
    vim.ui.select({ 'Source', 'Documentation', 'Copy module path' }, { prompt = item.module }, function(action)
      if action == 'Source' then open_source(item, root)
      elseif action == 'Documentation' then
        if vim.ui.open then vim.ui.open('https://pkg.go.dev/' .. item.module)
        else vim.fn.setreg('+', 'https://pkg.go.dev/' .. item.module) end
      elseif action == 'Copy module path' then
        vim.fn.setreg('+', item.module)
        vim.notify('Copied ' .. item.module)
      end
    end)
  end)
end

function M.setup()
  vim.api.nvim_create_user_command('GoModules', M.show, { desc = 'Browse Go module dependencies and updates' })
end

return M
