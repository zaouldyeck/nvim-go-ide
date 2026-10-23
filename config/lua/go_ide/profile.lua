local M = {}

local function ms_since_start()
  local start = tonumber(vim.g.go_ide_start_ns)
  if not start then return nil end
  return ((vim.uv or vim.loop).hrtime() - start) / 1e6
end

local function profile_lines()
  local s = require('go_ide.settings')
  local ok, lazy = pcall(require, 'lazy')
  local stats = ok and lazy.stats() or {}
  local startup = tonumber(vim.g.go_ide_startup_ms) or ms_since_start()
  local budget = tonumber(s.startup_budget_ms) or 180
  local clients = vim.lsp.get_clients({ name = 'gopls' })
  local memory = collectgarbage('count') / 1024
  local loaded = stats.loaded or 0
  local count = stats.count or 0
  local pct = count > 0 and math.floor((loaded / count) * 100 + 0.5) or 0
  local lines = {
    'Startup',
    string.format('  %.1f ms to editor ready   budget: %d ms   %s',
      startup or 0, budget, (startup or 0) <= budget and '✓' or '△'),
    '',
    'Plugins',
    string.format('  %d / %d loaded (%d%%)', loaded, count, pct),
    '',
    'Runtime',
    string.format('  Lua memory: %.1f MiB', memory),
    string.format('  gopls clients: %d', #clients),
  }
  if #clients > 0 then
    for _, client in ipairs(clients) do
      lines[#lines + 1] = '    ' .. (client.config.root_dir or 'standalone file')
    end
  end
  local buf = vim.api.nvim_get_current_buf()
  if vim.b[buf].go_ide_large_file then
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Current buffer: large-file mode'
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = 'Use :Lazy profile for plugin-by-plugin timings.'
  return lines
end

function M.show()
  local lines = profile_lines()
  local width = 72
  for _, line in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(line) + 4) end
  width = math.min(width, math.max(40, vim.o.columns - 8))
  local height = math.min(#lines + 2, math.max(8, vim.o.lines - 6))
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'goideprofile'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' IDE Profile ',
    title_pos = 'center',
  })
  vim.wo[win].winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle'
  for _, key in ipairs({ 'q', '<Esc>' }) do
    vim.keymap.set('n', key, function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end, { buffer = buf, silent = true })
  end
end

function M.setup()
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
      vim.schedule(function()
        vim.g.go_ide_startup_ms = ms_since_start()
      end)
    end,
  })
  vim.api.nvim_create_user_command('GoIdeProfile', M.show, {
    desc = 'Show startup/runtime profile for the Go IDE',
  })
end

return M
