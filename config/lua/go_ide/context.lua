local M = {}

local function current_node(buf)
  if vim.bo[buf].filetype ~= 'go' then return nil end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = buf,
    pos = { row - 1, col },
    ignore_injections = false,
  })
  return ok and node or nil
end

local function declaration(buf)
  local node = current_node(buf)
  while node do
    local kind = node:type()
    if kind == 'function_declaration' or kind == 'method_declaration' or kind == 'type_declaration' then
      local name_node = node:field('name')[1]
      return {
        kind = kind,
        name = name_node and vim.treesitter.get_node_text(name_node, buf) or nil,
        node = node,
      }
    end
    node = node:parent()
  end
end

local function generated_file(buf)
  local count = math.min(8, vim.api.nvim_buf_line_count(buf))
  if count == 0 then return false end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, count, false)
  for _, line in ipairs(lines) do
    if line:match('^// Code generated .* DO NOT EDIT%.$') then return true end
  end
  return false
end

local function classify_name(name)
  if not name then return {} end
  if name == 'Benchmark' or name:match('^Benchmark[^a-z]') then return { benchmark_name = name } end
  if name == 'Fuzz' or name:match('^Fuzz[^a-z]') then return { fuzz_name = name } end
  if name == 'Test' or name:match('^Test[^a-z]') or name == 'Example' or name:match('^Example[^a-z]') then
    return { test_name = name }
  end
  return {}
end

function M.current()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local filetype = vim.bo[buf].filetype
  local go_file = filetype == 'go' and file ~= ''
  local root = require('go_ide.project').root(file)
  local decl = go_file and declaration(buf) or nil
  local class = classify_name(decl and decl.name or nil)
  local clients = go_file and vim.lsp.get_clients({ bufnr = buf, name = 'gopls' }) or {}
  local git_root = file ~= '' and vim.fs.root(file, '.git') or vim.fs.root((vim.uv or vim.loop).cwd(), '.git')
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  return {
    buf = buf,
    file = file,
    filename = file ~= '' and vim.fs.basename(file) or '[No Name]',
    filetype = filetype,
    go = go_file,
    root = root,
    directory = file ~= '' and vim.fs.dirname(file) or root,
    test_file = go_file and file:match('_test%.go$') ~= nil,
    generated = go_file and generated_file(buf) or false,
    declaration = decl,
    declaration_name = decl and decl.name or nil,
    declaration_kind = decl and decl.kind or nil,
    test_name = class.test_name,
    benchmark_name = class.benchmark_name,
    fuzz_name = class.fuzz_name,
    lsp = #clients > 0,
    git = git_root ~= nil,
    git_root = git_root,
    modified = vim.bo[buf].modified,
    diagnostics = go_file and #vim.diagnostic.get(buf, { lnum = row }) or 0,
    large_file = vim.b[buf].go_ide_large_file == true,
  }
end

function M.label(ctx)
  ctx = ctx or M.current()
  local subject = ctx.benchmark_name or ctx.test_name or ctx.fuzz_name or ctx.declaration_name
  if subject then return subject .. ' · ' .. ctx.filename end
  if ctx.generated then return 'generated · ' .. ctx.filename end
  if ctx.go then return ctx.filename end
  return ctx.filename or 'workspace'
end

return M
