local M = {}

function M.debug_test()
  local go = require("go_ide.go")
  local context = go.context()
  if not context or not go.save_go_buffers(context) then return end
  if not context.file:match("_test%.go$") then
    vim.notify("Open a *_test.go file and put the cursor in a test first.", vim.log.levels.WARN)
    return
  end
  if vim.api.nvim_get_current_buf() ~= context.buf then
    local windows = vim.fn.win_findbuf(context.buf)
    if #windows > 0 then vim.api.nvim_set_current_win(windows[1])
    else vim.api.nvim_set_current_buf(context.buf) end
  end
  local adapter = require("dap-go")
  local project = require("go_ide.project")
  local flags = table.concat(project.build_flags(context.root), " ")
  if adapter.debug_test({
    program = context.directory,
    cwd = context.directory,
    buildFlags = flags,
    env = project.env(context.root),
  }) then
    M.last_test = { context = context, name = adapter.last_testname }
  end
end

function M.debug_last_test()
  if not M.last_test then
    vim.notify("No previous test in this session. Run :GoDebugTest first.", vim.log.levels.INFO)
    return
  end
  local last = M.last_test
  if not require("go_ide.go").save_go_buffers(last.context) then return end
  require("dap").run({
    type = "go", name = last.name, request = "launch", mode = "test",
    program = last.context.directory, cwd = last.context.directory,
    args = { "-test.run", "^" .. last.name .. "$", "-test.v" },
    buildFlags = table.concat(require("go_ide.project").build_flags(last.context.root), " "),
    env = require("go_ide.project").env(last.context.root),
    outputMode = "remote",
  })
end

function M.setup()
  if M._configured then return end
  M._configured = true
  local dap, dapui = require("dap"), require("dapui")
  local active_root = require("go_ide.project").root(vim.api.nvim_buf_get_name(0))
  require("dap-go").setup({
    delve = {
      path = require("go_ide.lsp").tool("dlv"),
      initialize_timeout_sec = 30,
      build_flags = table.concat(require("go_ide.project").build_flags(active_root), " "),
    },
    tests = { verbose = true },
  })
  -- Delve builds in its own process directory, before applying the debuggee's
  -- `cwd`. Resolve that separately so a package in another module still builds.
  local go_adapter = dap.adapters.go
  dap.adapters.go = function(callback, config)
    go_adapter(function(adapter)
      local resolved = vim.deepcopy(adapter)
      if resolved.executable and config.request == "launch" then
        local build_directory = config.dlvCwd
        if not build_directory and type(config.program) == "string" then
          local program = vim.fn.fnamemodify(config.program, ":p")
          local stat = vim.uv.fs_stat(program)
          if stat then build_directory = stat.type == "directory" and program or vim.fs.dirname(program) end
        end
        resolved.executable.cwd = build_directory or config.cwd or vim.fn.getcwd()
      end
      callback(resolved)
    end, config)
  end
  -- Debug the whole package: `main.go` frequently relies on neighbouring files.
  dap.configurations.go = {
    { type = "go", name = "Go: debug current package", request = "launch", mode = "debug",
      program = "${fileDirname}", cwd = "${fileDirname}",
      buildFlags = function() return table.concat(require("go_ide.project").build_flags(require("go_ide.project").root(vim.api.nvim_buf_get_name(0))), " ") end,
      env = function() return require("go_ide.project").env(require("go_ide.project").root(vim.api.nvim_buf_get_name(0))) end },
    { type = "go", name = "Go: debug package with arguments", request = "launch", mode = "debug",
      program = "${fileDirname}", cwd = "${fileDirname}", args = require("dap-go").get_arguments },
    { type = "go", name = "Go: debug package tests", request = "launch", mode = "test",
      program = "${fileDirname}", cwd = "${fileDirname}", args = { "-test.v" } },
    { type = "go", name = "Go: attach to local process", request = "attach", mode = "local",
      processId = require("dap.utils").pick_process },
  }
  dapui.setup({
    icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
    layouts = {
      { elements = { { id = "scopes", size = 0.45 }, { id = "watches", size = 0.25 },
          { id = "stacks", size = 0.20 }, { id = "breakpoints", size = 0.10 } },
        size = 38, position = "left" },
      { elements = { { id = "repl", size = 0.6 }, { id = "console", size = 0.4 } },
        size = 12, position = "bottom" },
    },
    controls = {
      enabled = true, element = "repl",
      icons = { pause = "Ⅱ", play = "▶", step_into = "↓", step_over = "→", step_out = "↑",
        step_back = "←", run_last = "↻", terminate = "■", disconnect = "×" },
    },
    floating = { border = "rounded", mappings = { close = { "q", "<Esc>" } } },
  })
  dap.listeners.before.attach.go_ide_ui = function() dapui.open() end
  dap.listeners.before.launch.go_ide_ui = function() dapui.open() end
  -- Leave the final output visible after termination; toggle the UI to close it.
  dap.listeners.on_config.go_ide_save = function(config)
    if config.type == "go" and config.request == "launch" then
      local go = require("go_ide.go")
      local context
      -- Saved test configs use absolute paths and may belong to another module.
      if type(config.program) == "string" and config.program:sub(1, 1) == "/" then
        local root = vim.fs.root(config.program, "go.mod")
        if root then context = { root = root, module_name = true } end
      end
      context = context or go.context()
      if context and not go.save_go_buffers(context) then
        local aborted = vim.deepcopy(config)
        aborted.program = dap.ABORT
        return aborted
      end
    end
    return config
  end
  vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
  vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
  vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticWarn" })
  vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })
  vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })
  vim.api.nvim_create_user_command("GoDebugTest", M.debug_test, { desc = "Debug the closest Go test with Delve" })
  vim.api.nvim_create_user_command("GoDebugLastTest", M.debug_last_test, { desc = "Debug the last Go test again" })
end

return M
