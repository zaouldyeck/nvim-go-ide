local M = {}
local cache = {}

local function as_directory(path)
  path = path or ''
  if path == '' then return (vim.uv or vim.loop).cwd() end
  local stat = (vim.uv or vim.loop).fs_stat(path)
  if stat and stat.type == 'directory' then return vim.fs.normalize(path) end
  return vim.fs.dirname(vim.fs.normalize(path))
end

function M.root(path)
  local dir = as_directory(path)
  return vim.fs.root(dir, { 'go.work', 'go.mod', '.git' }) or dir
end

local function string_list(value)
  local out = {}
  if type(value) ~= 'table' then return out end
  for _, item in ipairs(value) do
    if type(item) == 'string' and item ~= '' then out[#out + 1] = item end
  end
  return out
end

local function string_map(value)
  local out = {}
  if type(value) ~= 'table' then return out end
  for key, item in pairs(value) do
    if type(key) == 'string' and (type(item) == 'string' or type(item) == 'number' or type(item) == 'boolean') then
      out[key] = tostring(item)
    end
  end
  return out
end

function M.config(root)
  root = root or M.root(vim.api.nvim_buf_get_name(0))
  root = vim.fs.normalize(root)
  if cache[root] then return cache[root] end
  local result = {
    build_tags = {},
    go_test_args = {},
    go_env = {},
  }
  local path = root .. '/.nvim-go.json'
  if vim.fn.filereadable(path) == 1 then
    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), '\n'))
    if ok and type(decoded) == 'table' then
      result.build_tags = string_list(decoded.build_tags)
      result.go_test_args = string_list(decoded.go_test_args)
      result.go_env = string_map(decoded.go_env)
    else
      vim.notify('Could not parse ' .. path, vim.log.levels.WARN)
    end
  end
  cache[root] = result
  return result
end

function M.build_flags(root)
  local tags = M.config(root).build_tags
  if #tags == 0 then return {} end
  return { '-tags=' .. table.concat(tags, ',') }
end

function M.test_args(root)
  return vim.deepcopy(M.config(root).go_test_args)
end

function M.env(root)
  return vim.deepcopy(M.config(root).go_env)
end

function M.reload()
  cache = {}
  vim.notify('Project configuration reloaded')
end

function M.setup()
  vim.api.nvim_create_user_command('GoProjectReload', function()
    M.reload()
    require('go_ide.lsp').restart()
  end, { desc = 'Reload .nvim-go.json and restart gopls' })
end

return M
