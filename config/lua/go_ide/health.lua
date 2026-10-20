local M = {}

function M.check()
  local health = vim.health
  health.start("Go IDE")
  if vim.fn.has("nvim-0.11") == 1 then health.ok("Neovim " .. tostring(vim.version()))
  else health.error("Neovim 0.11 or newer is required. Run the supplied installer.") end
  health.info("Profile: " .. (vim.env.NVIM_APPNAME or "nvim"))
  health.info("Config: " .. vim.fn.stdpath("config"))
  health.info("Tools: " .. vim.fn.stdpath("data") .. "/bin")
  for _, name in ipairs({ "go", "gopls", "goimports", "dlv", "git", "rg" }) do
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
  local clients = vim.lsp.get_clients({ name = "gopls" })
  if #clients > 0 then
    for _, client in ipairs(clients) do health.ok("gopls workspace: " .. (client.config.root_dir or "standalone file")) end
  else health.info("gopls not attached yet. Open a .go file in a Go module and wait for indexing.") end
end

return M
