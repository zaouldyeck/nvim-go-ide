-- Run with Neovim 0.11+: nvim --headless -u NONE -l scripts/test-go-tidy.lua [path-to-go]
-- Exercises the real async task runner against temporary, offline Go modules.
local script = debug.getinfo(1, "S").source:sub(2)
local repo = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(vim.fn.fnamemodify(script, ":p"))))
vim.opt.runtimepath:prepend(repo .. "/config")
vim.o.hidden = true
vim.o.autoread = true
vim.o.swapfile = false
vim.o.confirm = false
local go_binary = vim.fn.exepath(arg[1] or "go")
assert(go_binary ~= "", "Supply a Go executable as the first argument or put Go on PATH")
local tmp = vim.fn.tempname() .. "-go-tidy"
vim.fn.mkdir(tmp, "p")
vim.env.GOPROXY = "off"
vim.env.GOSUMDB = "off"
vim.env.GOTOOLCHAIN = "local"
vim.env.GOWORK = "off"
local notices = {}
vim.notify = function(message) notices[#notices + 1] = message end
local lsp = require("go_ide.lsp")
local original_tool = lsp.tool
lsp.tool = function(name) return name == "go" and go_binary or original_tool(name) end
local tasks = require("go_ide.go")
tasks.setup()
local checks = 0
local function check(ok, message)
  assert(ok, message)
  checks = checks + 1
end
local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end
local function read(path) return table.concat(vim.fn.readfile(path), "\n") end
local function open(path, filetype)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.bo.filetype = filetype
  return vim.api.nvim_get_current_buf()
end
local function output()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == "go-ide://output" then
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end
  end
  return ""
end
local function finish()
  check(vim.wait(15000, function() return not tasks.state.running end, 10), "Go task timed out")
  check(tasks.state.last_result ~= nil, "Task did not publish a result")
  return tasks.state.last_result
end

local ok, err = xpcall(function()
  local target = tmp .. "/target module"
  local other = tmp .. "/unrelated"
  local nested = target .. "/nested"
  local mod = {
    "module example.com/target", "", "go 1.27.0", "",
    "require example.com/unused v0.0.0", "replace example.com/unused => ../unused",
  }
  write(tmp .. "/unused/go.mod", { "module example.com/unused", "go 1.27.0" })
  write(tmp .. "/unused/unused.go", { "package unused" })
  write(target .. "/go.mod", mod)
  write(target .. "/main.go", { "package target", "var Value = 1" })
  write(nested .. "/go.mod", { "module example.com/nested", "go 1.27.0" })
  write(nested .. "/nested.go", { "package nested", "var Value = 1" })
  write(other .. "/go.mod", { "module example.com/unrelated", "go 1.27.0" })
  local unrelated_before = read(other .. "/go.mod")
  local nested_buf = open(nested .. "/nested.go", "go")
  vim.api.nvim_buf_set_lines(nested_buf, 1, 2, false, { "var Value = 2" })
  local mod_buf = open(target .. "/go.mod", "gomod")
  vim.api.nvim_buf_set_lines(mod_buf, -1, -1, false, { "// preserve local metadata edits" })
  local source_buf = open(target .. "/main.go", "go")
  vim.api.nvim_buf_set_lines(source_buf, 1, 2, false, { "var Value = 2" })
  vim.cmd.cd(vim.fn.fnameescape(other))
  check(tasks.mod_tidy() == true, "Tidy did not start from a Go source file")
  check(tasks.state.running, "Tidy must run asynchronously")
  local result = finish()
  check(result.code == 0, "Tidy failed: " .. output())
  check(result.summary:match("^DONE") ~= nil and not result.summary:find("passed"), "Tidy displayed test counts")
  check(output():find("cwd: " .. target, 1, true) ~= nil, "Tidy used the editor cwd instead of the module")
  check(not read(target .. "/go.mod"):find("require example.com/unused", 1, true), "Unused requirement was not removed")
  check(read(target .. "/go.mod"):find("preserve local metadata edits", 1, true) ~= nil, "Metadata edits were lost")
  check(not vim.bo[mod_buf].modified, "Saved module buffer remained dirty")
  check(table.concat(vim.api.nvim_buf_get_lines(mod_buf, 0, -1, false), "\n") == read(target .. "/go.mod"), "Module buffer did not reload after tidy")
  check(read(target .. "/main.go"):find("Value = 2", 1, true) ~= nil and not vim.bo[source_buf].modified, "Source changes were not saved")
  check(vim.bo[nested_buf].modified and read(nested .. "/nested.go"):find("Value = 1", 1, true) ~= nil, "Tidy saved a different nested module")
  check(read(other .. "/go.mod") == unrelated_before, "Tidy modified the unrelated cwd module")

  vim.api.nvim_set_current_buf(mod_buf)
  check(tasks.mod_tidy() == true, "Tidy did not start directly from go.mod")
  check(finish().code == 0, "Tidy from go.mod failed")
  write(target .. "/go.sum", {})
  open(target .. "/go.sum", "gosum")
  check(tasks.mod_tidy() == true, "Tidy did not start directly from go.sum")
  check(finish().code == 0, "Tidy from go.sum failed")

  vim.api.nvim_set_current_buf(mod_buf)
  vim.api.nvim_buf_set_lines(mod_buf, 0, -1, false, { "module" })
  check(tasks.mod_tidy() == true, "Invalid metadata should report an async Go failure")
  check(finish().code ~= 0 and output():find("FAIL", 1, true) ~= nil, "Go failure was hidden")
  check(output():find("go.mod", 1, true) ~= nil, "Failure output did not retain the Go error")
  vim.api.nvim_buf_set_lines(mod_buf, 0, -1, false, { "module example.com/target", "go 1.27.0" })

  local fake_go = tmp .. "/slow-go"
  write(fake_go, {
    "#!/bin/sh", "sleep 0.05",
    "printf 'module example.com/target\\ngo 1.27.0\\n// changed on disk\\n' > go.mod",
  })
  vim.fn.setfperm(fake_go, "rwxr-xr-x")
  lsp.tool = function(name) return name == "go" and fake_go or original_tool(name) end
  check(tasks.mod_tidy() == true, "Async metadata-edit fixture did not start")
  vim.api.nvim_buf_set_lines(mod_buf, -1, -1, false, { "// edits made while tidy is running" })
  check(finish().code == 0, "Async metadata-edit fixture failed")
  check(vim.bo[mod_buf].modified and table.concat(vim.api.nvim_buf_get_lines(mod_buf, 0, -1, false), "\n")
    :find("edits made while tidy is running", 1, true) ~= nil, "Tidy discarded concurrent metadata edits")
  check(read(target .. "/go.mod"):find("changed on disk", 1, true) ~= nil, "Metadata-edit fixture did not change disk contents")
  -- Resolve this deliberate test-only conflict before exercising the next task.
  vim.api.nvim_buf_call(mod_buf, function() vim.cmd("edit!") end)

  write(fake_go, { "#!/bin/sh", "echo waiting", "sleep 5" })
  vim.fn.setfperm(fake_go, "rwxr-xr-x")
  lsp.tool = function(name) return name == "go" and fake_go or original_tool(name) end
  check(tasks.mod_tidy() == true, "Cancellable task did not start")
  check(tasks.mod_tidy() == false, "A second task started while the first was running")
  tasks.stop()
  result = finish()
  check(result.cancelled and result.summary:match("^STOPPED") ~= nil, "GoStop did not report cancellation")

  write(tmp .. "/loose/main.go", { "package main", "func main() {}" })
  open(tmp .. "/loose/main.go", "go")
  check(tasks.mod_tidy() == false and not tasks.state.running, "Tidy should reject a file outside a module")
end, debug.traceback)

if tasks.state.running then tasks.stop(); vim.wait(2000, function() return not tasks.state.running end, 10) end
if not ok then
  io.stderr:write(err .. "\nFixture retained at " .. tmp .. "\n")
  vim.cmd("cquit 1")
end
vim.fn.delete(tmp, "rf")
print("GoModTidy: " .. checks .. " checks passed (offline real Go, module scope, saves/reload, failures and cancellation)")
vim.cmd("qa!")
