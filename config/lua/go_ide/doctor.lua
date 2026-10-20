-- Non-interactive installation checks. Detailed runtime diagnostics: :GoIdeHealth.
local M = {}

function M.run()
  local failed = {}
  local function check(label, ok, detail)
    print((ok and 'PASS ' or 'FAIL ') .. label .. (detail and ': ' .. detail or ''))
    if not ok then failed[#failed + 1] = label end
  end
  check('Neovim 0.11+', vim.fn.has('nvim-0.11') == 1, tostring(vim.version()))
  check('Isolated profile', vim.env.NVIM_APPNAME == 'nvim-go', vim.env.NVIM_APPNAME or 'unset')
  check('Startup', vim.v.errmsg == '', vim.v.errmsg ~= '' and vim.v.errmsg or nil)
  for _, name in ipairs({ 'go', 'gopls', 'goimports', 'dlv', 'git', 'rg' }) do
    local executable = require('go_ide.lsp').tool(name)
    check(name, vim.fn.executable(executable) == 1, vim.fn.exepath(executable))
  end
  for _, name in ipairs({ 'cmp', 'neo-tree', 'bufferline', 'telescope', 'aerial', 'codewindow', 'trouble', 'dap', 'dapui' }) do
    local ok, result = pcall(require, name)
    check('Plugin ' .. name, ok, not ok and tostring(result) or nil)
  end
  local parser_ok, parser_error = pcall(vim.treesitter.language.add, 'go')
  check('Go parser', parser_ok, not parser_ok and tostring(parser_error) or nil)
  for _, name in ipairs({ 'GoRun', 'GoTest', 'GoFormat', 'GoCoverage', 'GoDebugTest', 'GoTerminal', 'GoIdeHealth' }) do
    check('Command ' .. name, vim.fn.exists(':' .. name) == 2)
  end
  if #failed > 0 then error('Installation checks failed: ' .. table.concat(failed, ', ')) end
  print('Installation checks passed. Open a Go module and use :GoIdeHealth for live LSP and clipboard status.')
end

return M
