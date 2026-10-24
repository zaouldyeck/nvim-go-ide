-- Small, transparent Go workflow layer: real `go` commands, JSON test output,
-- navigable quickfix failures, and coverage signs. Commands never use a shell.
local M = { state = { running = false, last_result = nil } }
local output_buf, output_win, run_buf, run_job, last_go_buf
local coverage_ns = vim.api.nvim_create_namespace("go_ide_coverage")
local test_ns = vim.api.nvim_create_namespace("go_ide_test_status")
local coverage = {}
local test_results = {}

local function notify(message, level) vim.notify(message, level or vim.log.levels.INFO, { title = "Go IDE" }) end
local function tool(name) return require("go_ide.lsp").tool(name) end

local function project_env(context)
  return vim.tbl_extend("force", vim.fn.environ(), require("go_ide.project").env(context.root))
end

local function project_test_flags(context)
  local args = {}
  vim.list_extend(args, require("go_ide.project").build_flags(context.root))
  vim.list_extend(args, require("go_ide.project").test_args(context.root))
  return args
end

function M.context(buf)
  buf = (not buf or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if vim.bo[buf].filetype ~= "go" and last_go_buf and vim.api.nvim_buf_is_valid(last_go_buf) then
    buf = last_go_buf
  end
  local filename = vim.api.nvim_buf_get_name(buf)
  if vim.bo[buf].filetype ~= "go" or filename == "" then
    notify("Open a saved .go file in the package first.", vim.log.levels.WARN)
    return nil
  end
  local directory = vim.fs.dirname(filename)
  local root = vim.fs.root(directory, "go.mod") or directory
  local module_name
  if vim.fn.filereadable(root .. "/go.mod") == 1 then
    for _, line in ipairs(vim.fn.readfile(root .. "/go.mod")) do
      module_name = line:match('^%s*module%s+"?([^%s"]+)')
      if module_name then break end
    end
  end
  return { buf = buf, file = filename, directory = directory, root = root, module_name = module_name }
end

function M.save_go_buffers(context)
  context = context or M.context()
  if not context then return false end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "go" and vim.bo[buf].modified then
      local filename = vim.api.nvim_buf_get_name(buf)
      local module_root = filename ~= "" and vim.fs.root(filename, "go.mod") or nil
      local same_module = module_root == context.root or (not module_root and not context.module_name)
      if filename ~= "" and filename:sub(1, #context.root + 1) == context.root .. "/" and same_module then
        local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("silent update") end)
        if not ok then notify("Could not save " .. filename .. ": " .. err, vim.log.levels.ERROR); return false end
      end
    end
  end
  return true
end

local function ensure_output()
  if output_buf and vim.api.nvim_buf_is_valid(output_buf) then return output_buf end
  output_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(output_buf, "go-ide://output")
  vim.bo[output_buf].buftype = "nofile"
  vim.bo[output_buf].bufhidden = "hide"
  vim.bo[output_buf].swapfile = false
  vim.bo[output_buf].filetype = "goideoutput"
  vim.bo[output_buf].modifiable = false
  vim.keymap.set("n", "q", function() vim.cmd.close() end, { buffer = output_buf, desc = "Close Go output" })
  vim.keymap.set("n", "<CR>", function() M.open_failures() end, { buffer = output_buf, desc = "Show test failures" })
  return output_buf
end

local function append(lines)
  if #lines == 0 then return end
  local buf = ensure_output()
  local count = vim.api.nvim_buf_line_count(buf)
  local follow = {}
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    follow[win] = vim.api.nvim_win_get_cursor(win)[1] >= count
  end
  vim.bo[buf].modifiable = true
  if count == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  end
  vim.bo[buf].modifiable = false
  for win, should_follow in pairs(follow) do
    if should_follow and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end
end

function M.open_output(focus)
  M.close_run()
  local terminal_ok, terminal = pcall(require, "go_ide.terminal")
  if terminal_ok then terminal.close() end
  local buf = ensure_output()
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage() then
      output_win = win
      if focus then vim.api.nvim_set_current_win(win) end
      return
    end
  end
  local previous = vim.api.nvim_get_current_win()
  vim.cmd("botright 12split")
  output_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(output_win, buf)
  vim.wo[output_win].number = false
  vim.wo[output_win].relativenumber = false
  vim.wo[output_win].signcolumn = "no"
  vim.wo[output_win].wrap = false
  vim.wo[output_win].winfixheight = true
  local ui_ok, ui = pcall(require, "go_ide.ui")
  if not ui_ok or not pcall(ui.set_panel, output_win, "output") then
    vim.wo[output_win].winbar = "  OUTPUT   Go tasks  |  Enter: failures  ·  q: close"
  end
  if not focus then vim.api.nvim_set_current_win(previous) end
end

function M.close_output()
  if output_buf and vim.api.nvim_buf_is_valid(output_buf) then
    for _, win in ipairs(vim.fn.win_findbuf(output_buf)) do
      if vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage() then
        pcall(vim.api.nvim_win_close, win, false)
      end
    end
  end
  output_win = nil
end

function M.toggle_output()
  if output_win and vim.api.nvim_win_is_valid(output_win) then
    M.close_output()
  else M.open_output(true) end
end

function M.open_failures()
  local ok, quicker = pcall(require, "quicker")
  if ok then quicker.open({ focus = true, height = 8 })
  else vim.cmd("botright copen 8") end
end

local function package_dir(context, package)
  if context.module_name and package then
    if package == context.module_name then return context.root end
    if package:sub(1, #context.module_name + 1) == context.module_name .. "/" then
      return context.root .. package:sub(#context.module_name + 1)
    end
  end
  return context.directory
end

local function diagnostic_from_line(line, context, package, cwd)
  local file, lnum, col, message = line:match("^%s*(.-%.go):(%d+):(%d+):%s*(.*)$")
  if not file then
    file, lnum, message = line:match("^%s*(.-%.go):(%d+):%s*(.*)$")
  end
  if not file then return nil end
  if file:sub(1, 1) ~= "/" then
    local base = file:sub(1, 2) == "./" and cwd or package_dir(context, package)
    file = vim.fs.normalize(base .. "/" .. file)
  end
  return { filename = file, lnum = tonumber(lnum), col = tonumber(col) or 1, text = message, type = "E" }
end

local function benchmark_functions(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "go")
  if not ok then return {} end
  local parsed = parser:parse()
  if not parsed[1] then return {} end
  local benches = {}
  for node in parsed[1]:root():iter_children() do
    if node:type() == "function_declaration" then
      local name_node = node:field("name")[1]
      local name = name_node and vim.treesitter.get_node_text(name_node, buf) or ""
      if name == "Benchmark" or name:match("^Benchmark[^a-z]") then
        local first, _, last = node:range()
        benches[#benches + 1] = { name = name, first = first + 1, last = last + 1 }
      end
    end
  end
  return benches
end

local function test_functions(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "go")
  if not ok then
    notify("The Go syntax parser is missing. Run :TSInstallSync go, then retry.", vim.log.levels.ERROR)
    return nil
  end
  local parsed = parser:parse()
  if not parsed[1] then return {} end
  local tests = {}
  for node in parsed[1]:root():iter_children() do
    if node:type() == "function_declaration" then
      local name_node = node:field("name")[1]
      local name = name_node and vim.treesitter.get_node_text(name_node, buf) or ""
      local test_name = name == "Test" or name:match("^Test[^a-z]")
        or name == "Example" or name:match("^Example[^a-z]")
        or name == "Fuzz" or name:match("^Fuzz[^a-z]")
      if test_name then
        local first, _, last = node:range()
        tests[#tests + 1] = { name = name, first = first + 1, last = last + 1 }
      end
    end
  end
  return tests
end

local function apply_test_results(buf)
  if require("go_ide.settings").test_gutter == false
    or not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, test_ns, 0, -1)
  local file = vim.api.nvim_buf_get_name(buf)
  if not file:match("_test%.go$") then return end
  local results = test_results[vim.fs.dirname(file)]
  if not results then return end
  local tests = test_functions(buf) or {}
  for _, test in ipairs(tests) do
    local result = results[test.name]
    if result then
      local icon, hl = "○", "GoTestSkip"
      if result.action == "pass" then icon, hl = "✓", "GoTestPass"
      elseif result.action == "fail" then icon, hl = "✗", "GoTestFail"
      elseif result.action == "run" then icon, hl = "●", "GoTestRun" end
      local opts = { sign_text = icon, sign_hl_group = hl, priority = 15 }
      if result.elapsed and result.elapsed > 0 then
        local duration = result.elapsed < 1
          and string.format("  %.0fms", result.elapsed * 1000)
          or string.format("  %.2fs", result.elapsed)
        opts.virt_text = { { duration, "GoTestDuration" } }
        opts.virt_text_pos = "eol"
        opts.virt_text_hide = true
      end
      vim.api.nvim_buf_set_extmark(buf, test_ns, test.first - 1, 0, opts)
    end
  end
end

local function refresh_test_results(directory)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local file = vim.api.nvim_buf_get_name(buf)
    if vim.api.nvim_buf_is_loaded(buf) and file:match("_test%.go$")
      and vim.fs.dirname(file) == directory then
      apply_test_results(buf)
    end
  end
end

local function record_test_event(context, event)
  if require("go_ide.settings").test_gutter == false or not event.Test
    or event.Test:find("/", 1, true)
    or not vim.tbl_contains({ "run", "pass", "fail", "skip" }, event.Action) then return end
  local directory = package_dir(context, event.Package)
  test_results[directory] = test_results[directory] or {}
  test_results[directory][event.Test] = {
    action = event.Action,
    elapsed = tonumber(event.Elapsed),
  }
  refresh_test_results(directory)
end

function M.test_pattern(scope, buf)
  buf = (not buf or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if not vim.api.nvim_buf_get_name(buf):match("_test%.go$") then
    notify("Open a *_test.go file for " .. scope .. " tests; use package tests from implementation files.", vim.log.levels.WARN)
    return nil
  end
  local tests = test_functions(buf)
  if not tests then return nil end
  if #tests == 0 then notify("No top-level Test, Example or Fuzz functions in this file.", vim.log.levels.WARN); return nil end
  if scope == "file" then
    return "^(" .. table.concat(vim.tbl_map(function(test) return test.name end, tests), "|") .. ")$"
  end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  if vim.api.nvim_get_current_buf() ~= buf then row = vim.api.nvim_buf_get_mark(buf, '"')[1] end
  local nearest = tests[1]
  for _, test in ipairs(tests) do
    if test.first <= row then nearest = test else break end
  end
  return "^" .. nearest.name .. "$"
end

local function run_task(args, context, cwd, after)
  if M.state.running then notify("A Go task is already running. Use :GoStop first.", vim.log.levels.WARN); return false end
  if vim.fn.executable(tool("go")) ~= 1 then notify("Go is missing; run the installer.", vim.log.levels.ERROR); return false end
  local buf = ensure_output()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "$ " .. table.concat(args, " "), "cwd: " .. cwd, "" })
  vim.bo[buf].modifiable = false
  M.open_output(false)
  local items, seen, partial, pending_test_items = {}, {}, { stdout = "", stderr = "" }, {}
  local counts = { pass = 0, fail = 0, skip = 0 }
  local title = "Go: " .. table.concat(args, " ")
  local started = vim.uv.hrtime()
  M.state.running = true
  M.state.last_result = nil
  vim.fn.setqflist({}, " ", { title = title, items = {} })
  local function add_item(item)
    local key = item.filename .. ":" .. item.lnum .. ":" .. item.text
    if not seen[key] then items[#items + 1] = item; seen[key] = true end
  end
  local function consume(line)
    if line == "" then return end
    local ok, event = pcall(vim.json.decode, line)
    local output, package, test_key = line, nil, nil
    if ok and type(event) == "table" and event.Action then
      record_test_event(context, event)
      if event.Test and not event.Test:find("/", 1, true) and counts[event.Action] ~= nil then
        counts[event.Action] = counts[event.Action] + 1
      end
      if event.Test then
        test_key = (event.Package or "") .. "/" .. event.Test
        if event.Action == "fail" then
          for _, item in ipairs(pending_test_items[test_key] or {}) do add_item(item) end
        end
        if event.Action == "pass" or event.Action == "skip" or event.Action == "fail" then
          pending_test_items[test_key] = nil
        end
      end
      output, package = event.Output, event.Package
      if not output then return end
      output = output:gsub("\n$", "")
    end
    append(vim.split(output, "\n", { plain = true }))
    for _, part in ipairs(vim.split(output, "\n", { plain = true })) do
      local item = diagnostic_from_line(part, context, package, cwd)
      if item then
        if test_key then
          pending_test_items[test_key] = pending_test_items[test_key] or {}
          pending_test_items[test_key][#pending_test_items[test_key] + 1] = item
        else add_item(item) end
      end
    end
  end
  local function stream(channel, data)
    if not data then return end
    data[1] = partial[channel] .. data[1]
    partial[channel] = data[#data]
    for index = 1, #data - 1 do consume(data[index]) end
  end
  local job = vim.fn.jobstart(args, {
    cwd = cwd,
    env = project_env(context),
    on_stdout = function(_, data) stream("stdout", data) end,
    on_stderr = function(_, data) stream("stderr", data) end,
    on_exit = function(_, code)
      consume(partial.stdout); consume(partial.stderr)
      M.state.running = false
      M.state.job = nil
      local seconds = (vim.uv.hrtime() - started) / 1e9
      local cancelled = M.state.cancelled
      M.state.cancelled = false
      local is_test = args[2] == "test"
      local status = cancelled and "STOPPED" or (code == 0 and (is_test and "PASS" or "DONE") or "FAIL")
      local summary = is_test
        and string.format("%s  %d passed · %d failed · %d skipped  (%.2fs)", status, counts.pass, counts.fail, counts.skip, seconds)
        or string.format("%s  %s  (%.2fs)", status, table.concat(args, " ", 2), seconds)
      append({ "", summary })
      M.state.last_result = { code = code, counts = counts, summary = summary, quickfix = items, cancelled = cancelled }
      vim.fn.setqflist({}, "r", { title = title, items = items })
      notify(summary, (code == 0 or cancelled) and vim.log.levels.INFO or vim.log.levels.ERROR)
      if code ~= 0 and not cancelled and #items > 0 then M.open_failures() end
      if after and code == 0 and not cancelled then after() end
    end,
  })
  if job <= 0 then
    M.state.running = false
    notify("Could not start: " .. table.concat(args, " "), vim.log.levels.ERROR)
    return false
  end
  M.state.job = job
  return true
end

local function test_args(context, scope, race)
  local args = { tool("go"), "test", "-json", "-count=1" }
  if race then args[#args + 1] = "-race" end
  vim.list_extend(args, project_test_flags(context))
  if scope == "nearest" or scope == "file" then
    local pattern = M.test_pattern(scope, context.buf)
    if not pattern then return nil end
    vim.list_extend(args, { "-run", pattern })
  end
  args[#args + 1] = scope == "all" and "./..." or "."
  return args
end

local function run_tests(scope, race)
  scope = scope or "package"
  if not vim.tbl_contains({ "nearest", "file", "package", "all" }, scope) then
    notify("Use nearest, file, package or all.", vim.log.levels.WARN); return
  end
  local context = M.context()
  if not context or not M.save_go_buffers(context) then return end
  local args = test_args(context, scope, race)
  if not args then return end
  local cwd = scope == "all" and context.root or context.directory
  M.state.last_test = {
    args = vim.deepcopy(args),
    context = vim.deepcopy(context),
    cwd = cwd,
    scope = scope,
    race = race == true,
  }
  return run_task(args, context, cwd)
end

function M.test(scope) return run_tests(scope, false) end
function M.test_race(scope) return run_tests(scope, true) end

function M.rerun_last_test()
  local last = M.state.last_test
  if not last then notify("No previous Go test to rerun.", vim.log.levels.WARN); return false end
  if not M.save_go_buffers(last.context) then return false end
  return run_task(vim.deepcopy(last.args), vim.deepcopy(last.context), last.cwd)
end

local function benchmark_pattern(context, scope)
  if scope ~= "nearest" then return "." end
  if not context.file:match("_test%.go$") then
    notify("Open a *_test.go file and place the cursor in a benchmark.", vim.log.levels.WARN)
    return nil
  end
  local benches = benchmark_functions(context.buf)
  if #benches == 0 then notify("No BenchmarkXxx functions in this file.", vim.log.levels.WARN); return nil end
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local nearest = benches[1]
  for _, bench in ipairs(benches) do
    if bench.first <= row then nearest = bench else break end
  end
  return "^" .. nearest.name .. "$"
end

local function benchmark_file(context, pattern)
  local dir = vim.fn.stdpath("cache") .. "/go-ide-benchmarks"
  vim.fn.mkdir(dir, "p")
  return dir .. "/" .. vim.fn.sha256(context.root .. ":" .. context.directory .. ":" .. pattern):sub(1, 20) .. ".txt"
end

local function run_benchmark(scope, mode)
  scope = scope or "nearest"
  if not vim.tbl_contains({ "nearest", "package", "all" }, scope) then
    notify("Use nearest, package or all.", vim.log.levels.WARN); return
  end
  if M.state.running then notify("A Go task is already running.", vim.log.levels.WARN); return end
  local context = M.context()
  if not context or not M.save_go_buffers(context) then return end
  local pattern = benchmark_pattern(context, scope)
  if not pattern then return end
  local args = { tool("go"), "test", "-run", "^$", "-bench", pattern, "-benchmem",
    "-count=" .. tostring(require("go_ide.settings").benchmark_count or 5) }
  vim.list_extend(args, project_test_flags(context))
  args[#args + 1] = scope == "all" and "./..." or "."
  local cwd = scope == "all" and context.root or context.directory
  local buf = ensure_output()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "$ " .. table.concat(args, " "),
    "cwd: " .. cwd,
    "",
    "Running benchmark…",
  })
  vim.bo[buf].modifiable = false
  M.open_output(false)
  M.state.running = true
  local system_job
  system_job = vim.system(args, { cwd = cwd, text = true, env = project_env(context) }, function(result)
    vim.schedule(function()
      M.state.running = false
      if M.state.system_job == system_job then M.state.system_job = nil end
      local output = (result.stdout or "") .. (result.stderr or "")
      append({ "" })
      append(vim.split(vim.trim(output), "\n", { plain = true }))
      if result.code ~= 0 then
        notify("Benchmark failed.", vim.log.levels.ERROR)
        return
      end
      local path = benchmark_file(context, pattern)
      if mode == "baseline" then
        vim.fn.writefile(vim.split(output, "\n", { plain = true }), path)
        notify("Benchmark baseline saved.")
      elseif mode == "compare" then
        if vim.fn.filereadable(path) ~= 1 then
          notify("No baseline yet. Run :GoBenchmarkBaseline first.", vim.log.levels.WARN)
          return
        end
        local current = path .. ".current"
        vim.fn.writefile(vim.split(output, "\n", { plain = true }), current)
        local benchstat = tool("benchstat")
        local comparison = vim.system({ benchstat, path, current }, { text = true }):wait(15000)
        append({ "", "BENCHSTAT" })
        append(vim.split(vim.trim((comparison.stdout or "") .. (comparison.stderr or "")), "\n", { plain = true }))
        vim.fn.delete(current)
        notify(comparison.code == 0 and "Benchmark comparison ready." or "benchstat reported an error.",
          comparison.code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
      else
        notify("Benchmark complete.")
      end
    end)
  end)
  M.state.system_job = system_job
end

function M.benchmark(scope) return run_benchmark(scope, nil) end
function M.benchmark_baseline(scope) return run_benchmark(scope, "baseline") end
function M.benchmark_compare(scope) return run_benchmark(scope, "compare") end

local function module_metadata_buffers(root)
  local buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name == root .. "/go.mod" or name == root .. "/go.sum" then buffers[#buffers + 1] = buf end
    end
  end
  return buffers
end

function M.generate(scope)
  scope = scope or "package"
  if not vim.tbl_contains({ "package", "all" }, scope) then
    notify("Use :GoGenerate package or all.", vim.log.levels.WARN)
    return false
  end
  local context = M.context()
  if not context or not M.save_go_buffers(context) then return false end
  local args = { tool("go"), "generate" }
  vim.list_extend(args, require("go_ide.project").build_flags(context.root))
  args[#args + 1] = scope == "all" and "./..." or "."
  local cwd = scope == "all" and context.root or context.directory
  return run_task(args, context, cwd)
end

function M.mod_tidy()
  if M.state.running then notify("A Go task is already running. Use :GoStop first.", vim.log.levels.WARN); return false end
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  local basename = vim.fs.basename(file)
  local context
  if basename == "go.mod" or basename == "go.sum" then
    local directory = vim.fs.dirname(file)
    context = { buf = buf, file = file, directory = directory, root = vim.fs.root(directory, "go.mod") }
  else
    context = M.context()
  end
  if not context then return false end
  if not context.root or vim.fn.filereadable(context.root .. "/go.mod") ~= 1 then
    notify("No go.mod found. Open a saved Go file, go.mod or go.sum inside a Go module.", vim.log.levels.WARN)
    return false
  end
  if not M.save_go_buffers(context) then return false end
  -- Tidy must see saved source and metadata, including edits in hidden buffers.
  for _, metadata in ipairs(module_metadata_buffers(context.root)) do
    if vim.bo[metadata].modified then
      local ok, err = pcall(vim.api.nvim_buf_call, metadata, function() vim.cmd("silent update") end)
      if not ok then notify("Could not save module metadata: " .. tostring(err), vim.log.levels.ERROR); return false end
    end
  end
  return run_task({ tool("go"), "mod", "tidy" }, context, context.root, function()
    for _, metadata in ipairs(module_metadata_buffers(context.root)) do
      if vim.bo[metadata].modified then
        notify("Kept unsaved edits in " .. vim.fs.basename(vim.api.nvim_buf_get_name(metadata))
          .. "; review the module changes before reloading it.", vim.log.levels.WARN)
      else
        -- Reload metadata changed by Go, without discarding edits made during the job.
        vim.cmd("silent checktime " .. metadata)
      end
    end
  end)
end

function M.run(args)
  if run_job and vim.fn.jobwait({ run_job }, 0)[1] == -1 then
    local windows = vim.fn.win_findbuf(run_buf)
    if #windows > 0 then vim.api.nvim_set_current_win(windows[1])
    else vim.cmd("botright 12split"); vim.api.nvim_win_set_buf(0, run_buf) end
    vim.cmd.startinsert()
    notify("Returned to the running Go program. Ctrl-C stops it.")
    return
  end
  local context = M.context()
  if not context or not M.save_go_buffers(context) then return end
  if vim.fn.executable(tool("go")) ~= 1 then notify("Go is missing; run the installer.", vim.log.levels.ERROR); return end
  local command = { tool("go"), "run" }
  vim.list_extend(command, require("go_ide.project").build_flags(context.root))
  command[#command + 1] = "."
  vim.list_extend(command, args or {})
  M.close_run()
  M.close_output()
  local terminal_ok, terminal = pcall(require, "go_ide.terminal")
  if terminal_ok then terminal.close() end
  vim.cmd("botright 12new")
  run_buf = vim.api.nvim_get_current_buf()
  M.state.run_buf = run_buf
  M.state.run_result = nil
  vim.bo[run_buf].bufhidden = "hide"
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.winbar = "  TERMINAL   go run .  |  Ctrl-C: stop  ·  Ctrl-\\ Ctrl-N: normal mode"
  run_job = vim.fn.jobstart(command, {
    cwd = context.directory, term = true, env = project_env(context),
    on_exit = function(_, code)
      run_job = nil
      M.state.run_job = nil
      M.state.run_result = code
      notify("go run exited with code " .. code, code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
    end,
  })
  if run_job <= 0 then run_job = nil; notify("Failed to start go run", vim.log.levels.ERROR); return end
  M.state.run_job = run_job
  vim.cmd.startinsert()
end

function M.close_run()
  if run_buf and vim.api.nvim_buf_is_valid(run_buf) then
    for _, win in ipairs(vim.fn.win_findbuf(run_buf)) do
      if vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage() then
        pcall(vim.api.nvim_win_close, win, false)
      end
    end
  end
end

function M.stop()
  local stopped = false
  if M.state.job then
    M.state.cancelled = true
    vim.fn.jobstop(M.state.job)
    stopped = true
  end
  if run_job then vim.fn.jobstop(run_job); stopped = true end
  if M.state.system_job then
    pcall(M.state.system_job.kill, M.state.system_job, 15)
    M.state.system_job = nil
    M.state.running = false
    stopped = true
  end
  if not stopped then notify("No Go task is running.") end
end

local function apply_coverage(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, coverage_ns, 0, -1)
  local entries = coverage[vim.api.nvim_buf_get_name(buf)]
  if not entries then return end
  local count = vim.api.nvim_buf_line_count(buf)
  local lines = {}
  for _, entry in ipairs(entries) do
    for row = entry.first, math.min(entry.last, count) do
      -- A line with any executed block is marked covered.
      lines[row] = lines[row] or entry.hits > 0
    end
  end
  for row, covered in pairs(lines) do
    vim.api.nvim_buf_set_extmark(buf, coverage_ns, row - 1, 0, {
      sign_text = "▎", sign_hl_group = covered and "GoCoverageCovered" or "GoCoverageUncovered",
      priority = 5,
    })
  end
end

local function read_coverage(path, context)
  coverage = {}
  for _, line in ipairs(vim.fn.readfile(path)) do
    local source, first, last, hits = line:match("^(.+):(%d+)%.%d+,(%d+)%.%d+%s+%d+%s+(%d+)$")
    if source then
      local file = source
      if context.module_name and source:sub(1, #context.module_name + 1) == context.module_name .. "/" then
        file = context.root .. source:sub(#context.module_name + 1)
      elseif source:sub(1, 1) ~= "/" then file = vim.fs.normalize(context.root .. "/" .. source) end
      coverage[file] = coverage[file] or {}
      coverage[file][#coverage[file] + 1] = { first = tonumber(first), last = tonumber(last), hits = tonumber(hits) }
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do apply_coverage(buf) end
  local result = vim.system({ tool("go"), "tool", "cover", "-func=" .. path }, { cwd = context.root, text = true }):wait(10000)
  if result.code == 0 then
    append({ "", "COVERAGE  green: executed · red: not executed" })
    append(vim.split(vim.trim(result.stdout or ""), "\n", { plain = true }))
  end
end

function M.coverage()
  local context = M.context()
  if not context or not M.save_go_buffers(context) then return end
  local directory = vim.fn.stdpath("cache") .. "/go-ide-coverage"
  vim.fn.mkdir(directory, "p")
  local path = directory .. "/" .. vim.fn.sha256(context.root):sub(1, 16) .. ".out"
  local args = { tool("go"), "test", "-json", "-count=1", "-coverprofile=" .. path }
  vim.list_extend(args, project_test_flags(context))
  args[#args + 1] = "./..."
  return run_task(args, context, context.root, function() read_coverage(path, context) end)
end

function M.clear_coverage()
  coverage = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_clear_namespace(buf, coverage_ns, 0, -1) end
  end
  notify("Coverage signs cleared.")
end

function M.setup()
  if M._configured then return end
  M._configured = true
  local group = vim.api.nvim_create_augroup("GoIDE_Tasks", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group, pattern = "*.go", callback = function(event)
      last_go_buf = event.buf
      apply_coverage(event.buf)
      apply_test_results(event.buf)
    end,
  })
  -- Coverage positions refer to the tested text. Hide stale signs after edits.
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group, pattern = "*.go", callback = function(event)
      local file = vim.api.nvim_buf_get_name(event.buf)
      coverage[file] = nil
      test_results[vim.fs.dirname(file)] = nil
      vim.api.nvim_buf_clear_namespace(event.buf, coverage_ns, 0, -1)
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local other = vim.api.nvim_buf_get_name(buf)
        if other ~= "" and vim.api.nvim_buf_is_valid(buf)
          and vim.fs.dirname(other) == vim.fs.dirname(file) then
          vim.api.nvim_buf_clear_namespace(buf, test_ns, 0, -1)
        end
      end
    end,
  })
  local function highlights()
    local colors = require("go_ide.settings").colors
    vim.api.nvim_set_hl(0, "GoCoverageCovered", { fg = colors.green })
    vim.api.nvim_set_hl(0, "GoCoverageUncovered", { fg = colors.red })
  end
  highlights()
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  vim.api.nvim_create_user_command("GoRun", function(opts) M.run(opts.fargs) end,
    { nargs = "*", desc = "Run current Go package in an interactive terminal (arguments supported)" })
  vim.api.nvim_create_user_command("GoTest", function(opts) M.test(opts.args == "" and "package" or opts.args) end,
    { nargs = "?", complete = function() return { "nearest", "file", "package", "all" } end, desc = "Run Go tests" })
  vim.api.nvim_create_user_command("GoTestLast", M.rerun_last_test, { desc = "Rerun the exact previous Go test command" })
  vim.api.nvim_create_user_command("GoTestRace", function(opts) M.test_race(opts.args == "" and "package" or opts.args) end,
    { nargs = "?", complete = function() return { "nearest", "file", "package", "all" } end, desc = "Run Go tests with the race detector" })
  vim.api.nvim_create_user_command("GoBenchmark", function(opts) M.benchmark(opts.args == "" and "nearest" or opts.args) end,
    { nargs = "?", complete = function() return { "nearest", "package", "all" } end, desc = "Run Go benchmarks" })
  vim.api.nvim_create_user_command("GoBenchmarkBaseline", function(opts) M.benchmark_baseline(opts.args == "" and "nearest" or opts.args) end,
    { nargs = "?", complete = function() return { "nearest", "package", "all" } end, desc = "Save benchmark baseline" })
  vim.api.nvim_create_user_command("GoBenchmarkCompare", function(opts) M.benchmark_compare(opts.args == "" and "nearest" or opts.args) end,
    { nargs = "?", complete = function() return { "nearest", "package", "all" } end, desc = "Compare benchmark with baseline" })
  vim.api.nvim_create_user_command("GoGenerate", function(opts) M.generate(opts.args == "" and "package" or opts.args) end,
    { nargs = "?", complete = function() return { "package", "all" } end, desc = "Run go generate for the current package/module" })
  vim.api.nvim_create_user_command("GoModTidy", M.mod_tidy, { desc = "Save module buffers and tidy dependencies asynchronously" })
  vim.api.nvim_create_user_command("GoCoverage", M.coverage, { desc = "Test the module with coverage signs" })
  vim.api.nvim_create_user_command("GoCoverageClear", M.clear_coverage, { desc = "Clear Go coverage signs" })
  vim.api.nvim_create_user_command("GoOutput", M.toggle_output, { desc = "Toggle Go task output" })
  vim.api.nvim_create_user_command("GoStop", M.stop, { desc = "Stop Go task/run jobs" })
end

return M
