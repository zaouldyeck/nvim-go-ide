local M = {}

function M.check()
  local health = vim.health
  health.start("Go IDE")
  if vim.fn.has("nvim-0.11") == 1 then health.ok("Neovim " .. tostring(vim.version()))
  else health.error("Neovim 0.11 or newer is required. Run the supplied installer.") end
  health.info("Profile: " .. (vim.env.NVIM_APPNAME or "nvim"))
  health.info("Config: " .. vim.fn.stdpath("config"))
  health.info("Tools: " .. vim.fn.stdpath("data") .. "/bin")
  for _, name in ipairs({ "go", "gopls", "goimports", "dlv", "benchstat", "git", "rg" }) do
    local command = require("go_ide.lsp").tool(name)
    if vim.fn.executable(command) == 1 then
      health.ok(name .. ": " .. vim.fn.exepath(command))
    else health.error(name .. " missing. Re-run the installer or follow its prerequisite instructions.") end
  end
  if vim.fn.executable(require("go_ide.lsp").tool("go")) == 1 then
    local result = vim.system({ require("go_ide.lsp").tool("go"), "version" }, { text = true }):wait(5000)
    if result.code == 0 then health.info(vim.trim(result.stdout or "")) end
  end
  local ok = pcall(vim.treesitter.language.add, "go")
  if ok then health.ok("Go Tree-sitter parser is installed")
  else health.error("Go Tree-sitter parser missing. Run :TSInstallSync go") end
  if vim.fn.executable("cc") == 1 or vim.fn.executable("gcc") == 1 or vim.fn.executable("clang") == 1 then
    health.ok("C compiler available for syntax parser installation")
  else health.warn("No C compiler: existing parsers work, but reinstalling them requires one.") end
  if vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 0 then
    health.warn("Wayland clipboard helper missing. Fedora: sudo dnf install wl-clipboard")
  elseif vim.fn.has("clipboard") == 1 then health.ok("Clipboard provider detected")
  else health.warn("No system clipboard provider detected. Terminal OSC 52 copying may still work.") end
  if vim.env.SSH_TTY then
    health.info("SSH session: clipboard and font rendering depend on your local terminal.")
  end
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    local stats = lazy.stats()
    health.info(string.format("Plugins loaded: %d/%d", stats.loaded or 0, stats.count or 0))
  end
  if vim.g.go_ide_startup_ms then
    local budget = require("go_ide.settings").startup_budget_ms or 180
    local message = string.format("Startup: %.1f ms (budget %d ms)", vim.g.go_ide_startup_ms, budget)
    if vim.g.go_ide_startup_ms <= budget then health.ok(message) else health.warn(message) end
  end
  local root = require("go_ide.project").root(vim.api.nvim_buf_get_name(0))
  local project = require("go_ide.project").config(root)
  if #project.build_tags > 0 then health.info("Build tags: " .. table.concat(project.build_tags, ", ")) end
  if #project.go_test_args > 0 then health.info("Project test args: " .. table.concat(project.go_test_args, " ")) end
  if vim.b.go_ide_large_file then health.info("Current buffer is in large-file mode") end
  local clients = vim.lsp.get_clients({ name = "gopls" })
  if #clients > 0 then
    for _, client in ipairs(clients) do health.ok("gopls workspace: " .. (client.config.root_dir or "standalone file")) end
  else health.info("gopls not attached yet. Open a .go file in a Go module and wait for indexing.") end
end

return M
