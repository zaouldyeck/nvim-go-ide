-- Native Neovim 0.11 LSP configuration. No Mason or legacy lspconfig API.
local M = {}
local formatting = {}

function M.tool(name)
  local private = vim.fn.stdpath("data") .. "/bin/" .. name
  return vim.fn.executable(private) == 1 and private or name
end

local function setting(name, default)
  local global = vim.g["go_ide_" .. name]
  if global ~= nil then return global end
  local ok, settings = pcall(require, "go_ide.settings")
  if ok and settings[name] ~= nil then return settings[name] end
  return default
end

-- goimports also applies gofmt. Feed the unsaved buffer over stdin, then apply
-- only changed lines so cursors, marks, folds and undo history stay useful.
function M.format(buf)
  buf = (not buf or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if formatting[buf] or not vim.api.nvim_buf_is_valid(buf) then return false end
  if vim.bo[buf].filetype ~= "go" then
    if #vim.lsp.get_clients({ bufnr = buf }) > 0 then
      vim.lsp.buf.format({ bufnr = buf, async = false, timeout_ms = 10000 })
      return true
    end
    return false
  end
  local filename = vim.api.nvim_buf_get_name(buf)
  if filename == "" or not vim.bo[buf].modifiable then return false end
  local executable = M.tool("goimports")
  if vim.fn.executable(executable) ~= 1 then
    vim.notify("goimports is missing. Re-run the installer to install Go tools.", vim.log.levels.WARN)
    return false
  end
  formatting[buf] = true
  local before = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
  local args = { executable, "-srcdir", filename }
  if vim.g.go_ide_goimports_local and vim.g.go_ide_goimports_local ~= "" then
    vim.list_extend(args, { "-local", vim.g.go_ide_goimports_local })
  end
  local ok, result = pcall(function()
    return vim.system(args, {
      stdin = before, text = true, cwd = vim.fs.dirname(filename),
    }):wait(10000)
  end)
  formatting[buf] = nil
  if not ok or result.code ~= 0 then
    local reason = ok and vim.trim(result.stderr or "Formatting timed out") or tostring(result)
    if reason == "" then reason = "Formatting timed out or was interrupted" end
    vim.notify("goimports: " .. reason .. "\nOriginal buffer preserved; saving is still allowed.", vim.log.levels.WARN)
    return false
  end
  local after = result.stdout or ""
  if before == after then return true end
  local views = {}
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  end
  local lines = vim.split(after, "\n", { plain = true })
  if lines[#lines] == "" then table.remove(lines) end
  local hunks = vim.diff(before, after, { result_type = "indices" })
  for index = #hunks, 1, -1 do
    local hunk = hunks[index]
    local first = hunk[2] == 0 and hunk[1] or hunk[1] - 1
    local replacement = {}
    for line = hunk[3], hunk[3] + hunk[4] - 1 do
      replacement[#replacement + 1] = lines[line]
    end
    vim.api.nvim_buf_call(buf, function() pcall(vim.cmd, "undojoin") end)
    vim.api.nvim_buf_set_lines(buf, first, first + hunk[2], false, replacement)
  end
  for win, view in pairs(views) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_call(win, function() vim.fn.winrestview(view) end)
    end
  end
  return true
end

function M.toggle_inlay_hints()
  local buf = vim.api.nvim_get_current_buf()
  local enabled = not vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
  vim.lsp.inlay_hint.enable(enabled, { bufnr = buf })
  vim.notify("Inlay hints " .. (enabled and "on" or "off"))
end

function M.toggle_codelens()
  vim.g.go_ide_codelens = not setting("codelens", true)
  if vim.g.go_ide_codelens then
    vim.lsp.codelens.refresh()
  else
    vim.lsp.codelens.clear()
  end
  vim.notify("Code lenses " .. (vim.g.go_ide_codelens and "on" or "off"))
end

function M.restart()
  vim.lsp.enable("gopls", false)
  vim.defer_fn(function() vim.lsp.enable("gopls", true) end, 200)
  vim.notify("Restarting gopls…")
end

function M.setup()
  if M._configured then return end
  M._configured = true
  vim.diagnostic.config({
    virtual_text = false,
    virtual_lines = false,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "●",
        [vim.diagnostic.severity.WARN] = "▲",
        [vim.diagnostic.severity.INFO] = "●",
        [vim.diagnostic.severity.HINT] = "·",
      },
    },
    float = { border = "rounded", source = "if_many" },
  })
  local capabilities = require("cmp_nvim_lsp").default_capabilities()
  local external_roots = {}
  local go_path = M.tool("go")
  if vim.fn.executable(go_path) == 1 then
    local ok, result = pcall(function()
      return vim.system({ go_path, "env", "-json", "GOROOT", "GOMODCACHE" }, {
        text = true, cwd = vim.uv.os_tmpdir(), env = { GOTOOLCHAIN = "local" },
      }):wait(5000)
    end)
    if ok and result.code == 0 then
      local decoded, dirs = pcall(vim.json.decode, result.stdout or "")
      if decoded then
        for _, directory in pairs(dirs) do
          if directory ~= "" then external_roots[#external_roots + 1] = directory .. "/" end
        end
      end
    end
  end
  -- When following definitions into GOROOT or the module cache, reuse the
  -- active workspace rather than starting a server on a dependency checkout.
  local function root_dir(buf, on_dir)
    local filename = vim.api.nvim_buf_get_name(buf)
    local active = vim.lsp.get_clients({ name = "gopls" })
    local looks_external = filename:find("/pkg/mod/", 1, true)
    for _, directory in ipairs(external_roots) do
      if filename:sub(1, #directory) == directory then looks_external = true; break end
    end
    if looks_external and #active > 0 then
      on_dir(active[1].config.root_dir)
      return
    end
    on_dir(vim.fs.root(buf, "go.work") or vim.fs.root(buf, "go.mod")
      or vim.fs.root(buf, ".git") or vim.fs.dirname(filename))
  end
  vim.lsp.config("gopls", {
    cmd = { M.tool("gopls") },
    capabilities = capabilities,
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
    root_dir = root_dir,
    settings = {
      gopls = {
        completeUnimported = true,
        usePlaceholders = true,
        staticcheck = true,
        semanticTokens = true,
        analyses = { nilness = true, unusedparams = true },
        hints = {
          assignVariableTypes = false,
          compositeLiteralFields = false,
          compositeLiteralTypes = false,
          constantValues = false,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = false,
        },
        codelenses = {
          generate = true, gc_details = false, test = true,
          tidy = true, upgrade_dependency = true, vendor = true,
        },
      },
    },
  })
  vim.lsp.enable("gopls")
  local group = vim.api.nvim_create_augroup("GoIDE_LSP", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group, pattern = "*.go",
    callback = function(event)
      if setting("format_on_save", true) and vim.b[event.buf].go_ide_format_on_save ~= false then
        M.format(event.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(event)
      local client = vim.lsp.get_client_by_id(event.data.client_id)
      if not client then return end
      if client:supports_method("textDocument/inlayHint", event.buf) then
        vim.lsp.inlay_hint.enable(setting("inlay_hints", false), { bufnr = event.buf })
      end
      if client:supports_method("textDocument/codeLens", event.buf) and setting("codelens", true) then
        vim.lsp.codelens.refresh({ bufnr = event.buf })
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
    group = group,
    callback = function(event)
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = event.buf })) do
        if client:supports_method("textDocument/codeLens", event.buf) and setting("codelens", true) then
          vim.lsp.codelens.refresh({ bufnr = event.buf })
        end
      end
    end,
  })
  vim.api.nvim_create_user_command("GoFormat", function() M.format() end, { desc = "Format Go and organize imports" })
  vim.api.nvim_create_user_command("GoImports", function() M.format() end, { desc = "Organize Go imports and format" })
  vim.api.nvim_create_user_command("GoFormatToggle", function()
    vim.g.go_ide_format_on_save = not setting("format_on_save", true)
    vim.notify("Format on save " .. (vim.g.go_ide_format_on_save and "on" or "off"))
  end, { desc = "Toggle Go format on save" })
  vim.api.nvim_create_user_command("GoLspRestart", M.restart, { desc = "Restart gopls" })
  vim.api.nvim_create_user_command("GoInlayHints", M.toggle_inlay_hints, { desc = "Toggle Go inlay hints" })
  vim.api.nvim_create_user_command("GoCodeLens", M.toggle_codelens, { desc = "Toggle Go code lenses" })
end

return M
