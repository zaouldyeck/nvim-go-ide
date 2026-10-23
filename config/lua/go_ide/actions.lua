local M = {
  _actions = {},
  _order = {},
  _sequence = 0,
  _usage = {},
  last_id = nil,
}

local function available(action, ctx)
  if not action.available then return true end
  local ok, result = pcall(action.available, ctx)
  return ok and result == true
end

local function score(action, ctx)
  local value = action.priority or 0
  if action.score then
    local ok, bonus = pcall(action.score, ctx)
    if ok and type(bonus) == 'number' then value = value + bonus end
  end
  local used = M._usage[action.id]
  if used then value = value + math.min(15, used / 1000000) end
  return value
end

local function telescope()
  pcall(require, 'telescope')
end

local function lsp_picker(name)
  return function()
    telescope()
    require('telescope.builtin')[name]()
  end
end

local function code_action(only)
  return function()
    telescope()
    vim.lsp.buf.code_action(only and { context = { only = only } } or nil)
  end
end

local function calls(kind)
  return function()
    if kind == 'incoming' then vim.lsp.buf.incoming_calls() else vim.lsp.buf.outgoing_calls() end
    vim.defer_fn(function() pcall(require('quicker').open, { focus = true, height = 10 }) end, 120)
  end
end

function M.register(action)
  assert(type(action) == 'table' and type(action.id) == 'string', 'action.id is required')
  assert(type(action.label) == 'string', 'action.label is required for ' .. action.id)
  assert(type(action.run) == 'function', 'action.run is required for ' .. action.id)
  if M._actions[action.id] then error('duplicate Go IDE action: ' .. action.id) end
  M._actions[action.id] = action
  M._order[#M._order + 1] = action.id
end

function M.get(id)
  return M._actions[id]
end

function M.context()
  return require('go_ide.context').current()
end

function M.list(ctx)
  ctx = ctx or M.context()
  local result = {}
  for _, id in ipairs(M._order) do
    local action = M._actions[id]
    if available(action, ctx) then
      result[#result + 1] = {
        id = id,
        label = action.label,
        group = action.group or 'IDE',
        key = action.key,
        detail = action.detail and action.detail(ctx) or nil,
        _score = score(action, ctx),
      }
    end
  end
  table.sort(result, function(a, b)
    if a._score == b._score then
      if a.group == b.group then return a.label < b.label end
      return a.group < b.group
    end
    return a._score > b._score
  end)
  return result
end

function M.run(id, ctx)
  local action = M._actions[id]
  if not action then
    vim.notify('Unknown IDE action: ' .. tostring(id), vim.log.levels.ERROR)
    return false
  end
  ctx = ctx or M.context()
  if not available(action, ctx) then
    vim.notify(action.label .. ' is not available in the current context.', vim.log.levels.WARN)
    return false
  end
  local ok, result = xpcall(function() return action.run(ctx) end, debug.traceback)
  if not ok then
    vim.notify('Action failed: ' .. action.label .. '\n' .. tostring(result), vim.log.levels.ERROR)
    return false
  end
  if result == false then return false end
  M._sequence = M._sequence + 1
  M._usage[id] = M._sequence * 1000000
  if action.repeatable ~= false then M.last_id = id end
  return true
end

function M.repeat_last()
  if not M.last_id then
    vim.notify('No IDE action to repeat yet. Use Space a first.', vim.log.levels.INFO)
    return
  end
  M.run(M.last_id)
end

function M.pick()
  telescope()
  local ctx = M.context()
  local items = M.list(ctx)
  if #items == 0 then
    vim.notify('No actions are available here.', vim.log.levels.INFO)
    return
  end
  local prompt = 'Actions · ' .. require('go_ide.context').label(ctx)
  vim.ui.select(items, {
    prompt = prompt,
    format_item = function(item)
      local key = item.key and ('  [' .. item.key .. ']') or ''
      local detail = item.detail and ('  · ' .. item.detail) or ''
      return string.format('%-10s  %s%s%s', item.group, item.label, detail, key)
    end,
  }, function(choice)
    if choice then M.run(choice.id, ctx) end
  end)
end

local function register_defaults()
  if M._defaults_registered then return end
  M._defaults_registered = true

  M.register({
    id = 'test.nearest', group = 'Test', label = 'Run nearest test', key = 'Space t t', priority = 90,
    available = function(c) return c.test_file and not c.benchmark_name and not c.fuzz_name end,
    detail = function(c) return c.test_name or c.filename end,
    run = function() return require('go_ide.go').test('nearest') end,
  })
  M.register({
    id = 'test.package', group = 'Test', label = 'Test package', key = 'Space t p', priority = 55,
    available = function(c) return c.go end,
    run = function() return require('go_ide.go').test('package') end,
  })
  M.register({
    id = 'test.race', group = 'Test', label = 'Race-test nearest', key = 'Space t R', priority = 82,
    available = function(c) return c.test_file and not c.benchmark_name and not c.fuzz_name end,
    run = function() return require('go_ide.go').test_race('nearest') end,
  })
  M.register({
    id = 'test.rerun', group = 'Test', label = 'Rerun previous test', key = 'Space t r', priority = 72,
    available = function() return require('go_ide.go').state.last_test ~= nil end,
    run = function() return require('go_ide.go').rerun_last_test() end,
  })
  M.register({
    id = 'test.debug', group = 'Test', label = 'Debug nearest test', key = 'Space t d', priority = 80,
    available = function(c) return c.test_file and not c.benchmark_name and not c.fuzz_name end,
    run = function() vim.cmd('GoDebugTest') end,
  })
  M.register({
    id = 'benchmark.run', group = 'Benchmark', label = 'Run benchmark', key = 'Space t b', priority = 120,
    available = function(c) return c.benchmark_name ~= nil end,
    detail = function(c) return c.benchmark_name end,
    run = function() return require('go_ide.go').benchmark('nearest') end,
  })
  M.register({
    id = 'benchmark.baseline', group = 'Benchmark', label = 'Save benchmark baseline', key = 'Space t v', priority = 112,
    available = function(c) return c.benchmark_name ~= nil end,
    run = function() return require('go_ide.go').benchmark_baseline('nearest') end,
  })
  M.register({
    id = 'benchmark.compare', group = 'Benchmark', label = 'Compare with baseline', key = 'Space t V', priority = 115,
    available = function(c) return c.benchmark_name ~= nil end,
    run = function() return require('go_ide.go').benchmark_compare('nearest') end,
  })
  M.register({
    id = 'go.run', group = 'Go', label = 'Run current package', key = 'Space r r', priority = 48,
    available = function(c) return c.go and not c.test_file end,
    run = function() return require('go_ide.go').run() end,
  })
  M.register({
    id = 'go.coverage', group = 'Go', label = 'Run module coverage', key = 'Space t c', priority = 36,
    available = function(c) return c.go end,
    run = function() return require('go_ide.go').coverage() end,
  })
  M.register({
    id = 'go.tidy', group = 'Go', label = 'Tidy module dependencies', key = 'Space c m', priority = 28,
    available = function(c) return c.go or c.filename == 'go.mod' or c.filename == 'go.sum' end,
    run = function() return require('go_ide.go').mod_tidy() end,
  })
  M.register({
    id = 'go.modules', group = 'Go', label = 'Browse dependencies', key = 'Space c d', priority = 26,
    available = function(c) return c.go or c.filename == 'go.mod' or c.filename == 'go.sum' end,
    run = function() require('go_ide.modules').show() end,
  })
  M.register({
    id = 'code.definition', group = 'Code', label = 'Go to definition', key = 'g d', priority = 66,
    available = function(c) return c.lsp end,
    run = function() vim.lsp.buf.definition() end,
  })
  M.register({
    id = 'code.references', group = 'Code', label = 'Find references', key = 'g r', priority = 64,
    available = function(c) return c.lsp end,
    run = lsp_picker('lsp_references'),
  })
  M.register({
    id = 'code.implementations', group = 'Code', label = 'Find implementations', key = 'Space f i', priority = 62,
    available = function(c) return c.lsp end,
    run = lsp_picker('lsp_implementations'),
  })
  M.register({
    id = 'code.rename', group = 'Code', label = 'Rename symbol', key = 'Space r n', priority = 60,
    available = function(c) return c.lsp end,
    run = function() vim.lsp.buf.rename() end,
  })
  M.register({
    id = 'code.actions', group = 'Code', label = 'Code actions', key = 'Space c a', priority = 58,
    available = function(c) return c.lsp end,
    run = code_action(),
  })
  M.register({
    id = 'code.refactor', group = 'Code', label = 'Refactor actions', key = 'Space c r', priority = 61,
    available = function(c) return c.lsp end,
    run = code_action({ 'refactor' }),
  })
  M.register({
    id = 'code.fix', group = 'Code', label = 'Quick fixes', key = 'Space c x', priority = 74,
    available = function(c) return c.lsp and c.diagnostics > 0 end,
    detail = function(c) return tostring(c.diagnostics) .. ' diagnostic' .. (c.diagnostics == 1 and '' or 's') end,
    run = code_action({ 'quickfix', 'source.fixAll' }),
  })
  M.register({
    id = 'code.calls.incoming', group = 'Code', label = 'Incoming calls', key = 'Space c I', priority = 52,
    available = function(c) return c.lsp and c.declaration_name ~= nil end,
    run = calls('incoming'),
  })
  M.register({
    id = 'code.calls.outgoing', group = 'Code', label = 'Outgoing calls', key = 'Space c O', priority = 51,
    available = function(c) return c.lsp and c.declaration_name ~= nil end,
    run = calls('outgoing'),
  })
  M.register({
    id = 'git.diff', group = 'Git', label = 'Diff file vs branch base', key = 'Space g d', priority = 44,
    available = function(c) return c.git and c.file ~= '' end,
    run = function() require('go_ide.git').diff() end,
  })
  M.register({
    id = 'git.review', group = 'Git', label = 'Review branch changes', key = 'Space g D', priority = 42,
    available = function(c) return c.git end,
    run = function() require('go_ide.git').review() end,
  })
  M.register({
    id = 'git.hunks', group = 'Git', label = 'All repository hunks', key = 'Space g q', priority = 38,
    available = function(c) return c.git end,
    run = function() require('go_ide.git').hunks() end,
  })
  M.register({
    id = 'project.switch', group = 'Project', label = 'Switch recent project', key = 'Space p p', priority = 24,
    repeatable = false,
    run = function() require('go_ide.workspace').pick() end,
  })
  M.register({
    id = 'project.save', group = 'Project', label = 'Save workspace', key = 'Space p s', priority = 18,
    repeatable = false,
    run = function() require('go_ide.workspace').save() end,
  })
  M.register({
    id = 'project.restore', group = 'Project', label = 'Restore workspace', key = 'Space p r', priority = 17,
    repeatable = false,
    run = function() require('go_ide.workspace').restore() end,
  })
  M.register({
    id = 'go.scratch', group = 'Project', label = 'New Go scratch buffer', key = 'Space n g', priority = 16,
    repeatable = false,
    run = function() require('go_ide.scratch').go() end,
  })
  M.register({
    id = 'ui.focus', group = 'IDE', label = 'Toggle Focus Mode', key = 'Space u f', priority = 14,
    repeatable = false,
    run = function() require('go_ide.ui').toggle_focus_mode() end,
  })
  M.register({
    id = 'ui.profile', group = 'IDE', label = 'Startup/runtime profile', key = 'Space u p', priority = 10,
    repeatable = false,
    run = function() vim.cmd('GoIdeProfile') end,
  })
  M.register({
    id = 'ui.health', group = 'IDE', label = 'IDE health check', key = 'Space u i', priority = 9,
    repeatable = false,
    run = function() vim.cmd('GoIdeHealth') end,
  })
end

function M.setup()
  register_defaults()
  vim.api.nvim_create_user_command('GoActions', M.pick, {
    desc = 'Open the context-aware Go IDE action hub',
  })
  vim.api.nvim_create_user_command('GoActionRepeat', M.repeat_last, {
    desc = 'Repeat the last repeatable Go IDE action',
  })
  vim.api.nvim_create_user_command('GoAction', function(opts)
    M.run(opts.args)
  end, {
    nargs = 1,
    complete = function(prefix)
      local matches = {}
      for _, id in ipairs(M._order) do
        if vim.startswith(id, prefix) then matches[#matches + 1] = id end
      end
      return matches
    end,
    desc = 'Run a Go IDE action by id',
  })
end

return M
