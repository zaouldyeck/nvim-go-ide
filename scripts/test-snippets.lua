-- Offline interaction checks against an installed profile's pinned plugins.
-- nvim --headless -u NONE -i NONE -l scripts/test-snippets.lua /path/to/nvim-go/lazy
-- Runs the checkout's completion config in a separate Neovim; no LSP or bootstrap.
local script = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fs.dirname(vim.fs.dirname(script))
local plugins = arg[1] or (vim.fn.stdpath("data") .. "/lazy")
local temporary = vim.fn.tempname()
vim.fn.mkdir(temporary, "p")
local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-n", "-u", "NONE", "-i", "NONE" }, {
  rpc = true,
  env = {
    XDG_CONFIG_HOME = temporary .. "/config", XDG_DATA_HOME = temporary .. "/data",
    XDG_STATE_HOME = temporary .. "/state", XDG_CACHE_HOME = temporary .. "/cache",
    NVIM_LOG_FILE = temporary .. "/nvim.log",
  },
})
assert(child > 0, "Could not start isolated Neovim")

local function rpc(method, ...)
  return vim.rpcrequest(child, method, ...)
end

local function lua(code, ...)
  return rpc("nvim_exec_lua", code, { ... })
end

local function feed(keys)
  -- Give scheduled InsertEnter handlers and snippet selections a turn between
  -- text and special keys, just as they get between physical key presses.
  local function input(part)
    rpc("nvim_input", part)
    vim.wait(25, function() return false end, 5)
  end
  local offset = 1
  while offset <= #keys do
    local first, last = keys:find("<[^>]+>", offset)
    if not first then input(keys:sub(offset)); break end
    if first > offset then input(keys:sub(offset, first - 1)) end
    input(keys:sub(first, last))
    offset = last + 1
  end
end

local function expect(condition, message)
  assert(condition, message)
end

local function line()
  return rpc("nvim_buf_get_lines", 0, 0, 1, false)[1]
end

local function position()
  return lua([[
    local node = require("luasnip").session.current_nodes[vim.api.nvim_get_current_buf()]
    return node and node:get_text() or {}
  ]])
end

local function at(text)
  expect(table.concat(position(), "\n") == text, "Expected active placeholder " .. vim.inspect(text) .. ", got " .. vim.inspect(position()))
end

local function fresh(text)
  feed("<Esc>")
  lua([[
    require("cmp").close()
    vim.cmd("enew!")
    vim.bo.filetype = "go"
    vim.bo.expandtab = false
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { ... })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  ]], text or "")
end

local function run()
  lua([[
    local root, plugins = ...
    vim.fn.mkdir(vim.fn.stdpath("state"), "p")
    for _, name in ipairs({ "LuaSnip", "nvim-cmp", "cmp_luasnip" }) do
      local path = plugins .. "/" .. name
      assert(vim.fn.isdirectory(path) == 1, "Missing installed plugin: " .. path)
      vim.opt.runtimepath:append(path)
      vim.opt.runtimepath:append(path .. "/after")
    end
    vim.opt.runtimepath:prepend(root .. "/config")
    vim.cmd("runtime plugin/luasnip.lua")
    vim.cmd("runtime plugin/cmp.lua")
    vim.cmd("runtime after/plugin/cmp_luasnip.lua")
    -- Keep unrelated language-server startup out of this completion test.
    package.loaded["go_ide.lsp"] = { setup = function() end }
    require("plugins.go")[1].config()
    require("cmp").setup({ completion = { autocomplete = false }, sources = { { name = "luasnip" } } })
    vim.o.backspace = "indent,eol,start"
    vim.o.virtualedit = "onemore"
  ]], root, plugins)

  -- Registration must replace this batch without affecting unrelated snippets.
  lua([[
    local ls = require("luasnip")
    ls.add_snippets("go", { ls.snippet("qa_external", { ls.text_node("external") }) }, { key = "qa-external" })
    vim.cmd("GoSnippetsReload")
    vim.cmd("GoSnippetsReload")
    local counts = {}
    for _, snippet in ipairs(ls.get_snippets("go")) do
      if not snippet.invalidated then
        counts[snippet.trigger] = (counts[snippet.trigger] or 0) + 1
      end
    end
    for _, trigger in ipairs({ "func", "meth", "tys", "struct", "fmain", "main", "iferr", "test", "forr", "iface", "switch", "errf", "qa_external" }) do
      assert(counts[trigger] == 1, "Missing or duplicate trigger after reload: " .. trigger)
    end
    assert(vim.tbl_count(counts) == 13, vim.inspect(counts))
  ]])
  print("PASS keyed reload, all migrated aliases, and preservation of existing snippets")

  fresh()
  feed("ifunc<C-l>")
  expect(line() == "func FunctionName() (T1, error) {", "Function did not expand: " .. line())
  at("FunctionName")
  feed("Load<C-l>path string<C-l>")
  at("T1")
  feed("string<C-l>")
  at("error")
  feed("<C-h>")
  at("string")
  feed("<M-n>")
  expect(line() == "func Load(path string) error {", "Single-return choice failed: " .. line())
  at("error")
  feed("<M-n>")
  expect(line() == "func Load(path string) {", "No-return spacing failed: " .. line())
  feed("<M-p>")
  expect(line() == "func Load(path string) error {", "Reverse choice failed: " .. line())
  feed("<M-n><C-l>return")
  expect(rpc("nvim_buf_get_lines", 0, 1, 2, false)[1] == "\treturn", "Final body stop or literal tab failed")
  print("PASS function expansion, nested forward/backward stops, both choice keys, and empty-return spacing")

  for _, receiver in ipairs({ "Cache", "*Cache" }) do
    fresh()
    feed("imeth<C-l>c<C-l>" .. receiver .. "<C-l>Get<C-l>key string<C-l>")
    at("T1")
    expect(line() == "func (c " .. receiver .. ") Get(key string) (T1, error) {", "Editable receiver or method jumps failed: " .. line())
    feed("<M-n>")
    expect(line() == "func (c " .. receiver .. ") Get(key string) error {", "Method single return failed")
    feed("<M-n>")
    expect(line() == "func (c " .. receiver .. ") Get(key string) {", "Method no returns failed")
  end
  print("PASS value and pointer method receivers with all return choices")

  for _, trigger in ipairs({ "tys", "struct" }) do
    fresh()
    feed("i" .. trigger .. "<C-l>Person<C-l>Name<C-l>string<C-l>")
    expect(line() == "type Person struct {", "Struct alias failed: " .. trigger)
    expect(rpc("nvim_buf_get_lines", 0, 1, 2, false)[1] == "\tName string", "Struct field stops failed: " .. trigger)
  end
  for _, trigger in ipairs({ "fmain", "main" }) do
    fresh()
    feed("i" .. trigger .. "<C-l>println(1)")
    expect(line() == "func main() {", "Main alias failed: " .. trigger)
    expect(rpc("nvim_buf_get_lines", 0, 1, 2, false)[1] == "\tprintln(1)", "Main body stop failed: " .. trigger)
  end
  print("PASS struct and main alias expansion with editable fields")

  -- A real LSP-style completion snippet has separate argument placeholders.
  fresh()
  feed("i")
  lua([[require("luasnip").lsp_expand("Call(${1:left}, ${2:right})$0")]])
  feed("one<C-l>two<C-h>")
  at("one")
  feed("<C-l>")
  at("two")
  expect(line() == "Call(one, two)", "LSP argument placeholder movement changed the call")
  print("PASS forward/backward navigation through LSP-style function arguments")

  -- Dedicated jump keys must work while cmp owns an actual completion popup.
  fresh()
  feed("ifunc<C-l>Name<C-l>x int<C-l>")
  lua([[
    local cmp = require("cmp")
    cmp.register_source("qa_choice", {
      complete = function(_, _, done)
        done({ items = { { label = "string", insertText = "string" }, { label = "int", insertText = "int" } } })
      end,
    })
    cmp.setup.buffer({ sources = { { name = "qa_choice" } } })
  ]])
  feed("s")
  lua([[require("cmp").complete()]])
  expect(vim.wait(2000, function() return lua([[return require("cmp").visible()]]) end, 20), "Completion popup did not appear")
  feed("<C-l>")
  at("error")
  expect(line() == "func Name(x int) (s, error) {", "Jump changed the edited argument text: " .. line())
  expect(not lua([[return require("cmp").visible()]]), "Jump left completion popup open")
  print("PASS snippet jump through visible completion popup without changing text")

  -- Outside snippets Ctrl+H must retain ordinary backspace behavior.
  fresh()
  feed("iabc<C-h>")
  expect(line() == "ab", "Ctrl+H swallowed ordinary Insert-mode backspace")
  -- Existing mode-specific mappings must remain the fallback in Select mode.
  feed("<Esc>")
  lua([[
    vim.keymap.set("s", "<C-h>", function() vim.g.qa_select_fallback = true end, { buffer = true })
    require("cmp").core:prepare()
    vim.cmd("normal! gg0gh")
  ]])
  feed("<C-h>")
  expect(lua([[return vim.g.qa_select_fallback == true]]), "Select-mode fallback mapping was not preserved")
  print("PASS Insert backspace and Select-mode mapping fallback outside snippets")

  -- History must not jump back into a snippet after the cursor leaves its rows.
  fresh()
  feed("ifunc<C-l>Name<C-l>x int<C-l><Esc>")
  lua([[
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { "", "outside" })
    vim.api.nvim_win_set_cursor(0, { 5, 7 })
  ]])
  feed("a<C-h>")
  expect(rpc("nvim_win_get_cursor", 0)[1] == 5, "Ctrl+H re-entered an old snippet")
  expect(rpc("nvim_buf_get_lines", 0, 4, 5, false)[1] == "outsid", "Local guard did not preserve backspace outside a remembered snippet")
  print("PASS locality guard with snippet history enabled")
end

local ok, err = xpcall(run, debug.traceback)
vim.fn.jobstop(child)
vim.fn.delete(temporary, "rf")
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
end
print("All snippet interaction checks passed")
