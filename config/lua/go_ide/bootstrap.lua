local M = {}
M.parsers = { 'go', 'gomod', 'gosum', 'gowork', 'lua', 'vim', 'vimdoc', 'query', 'json', 'yaml', 'bash', 'markdown', 'markdown_inline' }
function M.run()
  if vim.v.errmsg ~= '' then error('Neovim startup failed: ' .. vim.v.errmsg) end
  require('lazy').restore({ wait = true, show = false })
  require('lazy').load({ plugins = { 'nvim-treesitter' }, wait = true })
  local plugins = require('lazy.core.config').plugins
  for name, plugin in pairs(plugins) do
    if not plugin._.installed then error('Plugin installation failed: ' .. name) end
    for _, task in ipairs(plugin._.tasks or {}) do
      if task:has_errors() then error('Plugin task failed: ' .. name .. '\n' .. task:output()) end
    end
  end
  -- Bang is essential: an existing parser otherwise prompts on reinstall,
  -- which would block a headless installer indefinitely.
  vim.cmd('TSInstallSync! ' .. table.concat(M.parsers, ' '))
  for _, lang in ipairs(M.parsers) do
    local ok, err = pcall(vim.treesitter.language.add, lang)
    if not ok then error('Parser installation failed for ' .. lang .. ': ' .. tostring(err)) end
  end
  print('nvim-go: all plugins and ' .. #M.parsers .. ' parsers installed successfully.')
end
return M
