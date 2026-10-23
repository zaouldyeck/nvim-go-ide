local M = {}

local function parser_root(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'go')
  if not ok then return nil end
  local trees = parser:parse()
  return trees[1] and trees[1]:root() or nil
end

local function node_name(node, buf)
  local name = node and node:field('name')[1]
  return name and vim.treesitter.get_node_text(name, buf) or ''
end

local function is_test_name(name)
  return name == 'Test' or name:match('^Test[^a-z]')
    or name == 'Benchmark' or name:match('^Benchmark[^a-z]')
    or name == 'Example' or name:match('^Example[^a-z]')
    or name == 'Fuzz' or name:match('^Fuzz[^a-z]')
end

local function collect(buf, kind)
  local root = parser_root(buf)
  if not root then return {} end
  local out = {}
  local function walk(node)
    local t = node:type()
    local matched = false
    if kind == 'function' then matched = t == 'function_declaration' or t == 'method_declaration'
    elseif kind == 'test' then matched = t == 'function_declaration' and is_test_name(node_name(node, buf))
    elseif kind == 'type' then matched = t == 'type_declaration' end
    if matched then out[#out + 1] = node end
    for child in node:iter_children() do walk(child) end
  end
  walk(root)
  table.sort(out, function(a, b)
    local ar, ac = a:start()
    local br, bc = b:start()
    return ar == br and ac < bc or ar < br
  end)
  return out
end

function M.jump(kind, direction)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= 'go' then return end
  local nodes = collect(buf, kind)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local chosen
  if direction > 0 then
    for _, node in ipairs(nodes) do
      local first = node:start()
      if first > row then chosen = node; break end
    end
    chosen = chosen or nodes[1]
  else
    for index = #nodes, 1, -1 do
      local first = nodes[index]:start()
      if first < row then chosen = nodes[index]; break end
    end
    chosen = chosen or nodes[#nodes]
  end
  if chosen then
    local first = chosen:start()
    vim.api.nvim_win_set_cursor(0, { first + 1, 0 })
    vim.cmd('normal! ^')
  end
end

local function containing(kind)
  local buf = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  local best
  for _, node in ipairs(collect(buf, kind)) do
    local sr, sc, er, ec = node:range()
    local after_start = row > sr or (row == sr and col >= sc)
    local before_end = row < er or (row == er and col <= ec)
    if after_start and before_end then best = node end
  end
  return best
end

local function select_node(node, inner)
  if not node then return end
  local target = node
  if inner then
    target = node:field('body')[1] or node:named_child(0) or node
  end
  local sr, sc, er, ec = target:range()
  if inner and target:type() == 'block' then
    sc = sc + 1
    ec = math.max(0, ec - 1)
  end
  vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
  vim.cmd('normal! v')
  vim.api.nvim_win_set_cursor(0, { er + 1, math.max(0, ec - 1) })
end

function M.select(kind, inner)
  if vim.bo.filetype ~= 'go' then return end
  select_node(containing(kind), inner)
end

return M
