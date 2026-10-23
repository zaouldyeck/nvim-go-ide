local M = {}

local function settings()
  return require('go_ide.settings')
end

function M.is_large(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  return vim.b[buf].go_ide_large_file == true
end

local function disable_expensive_features(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.b[buf].go_ide_large_file = true
  vim.diagnostic.enable(false, { bufnr = buf })
  pcall(vim.treesitter.stop, buf)
  pcall(vim.lsp.inlay_hint.enable, false, { bufnr = buf })
  if package.loaded.ibl then pcall(require('ibl').setup_buffer, buf, { enabled = false }) end
  vim.bo[buf].syntax = ''
end

local function maybe_mark_by_size(buf, file)
  if file == '' then return end
  local stat = (vim.uv or vim.loop).fs_stat(file)
  if stat and stat.type == 'file' and stat.size >= settings().large_file_bytes then
    vim.b[buf].go_ide_large_file = true
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('GoIDE_LargeFiles', { clear = true })
  vim.api.nvim_create_autocmd('BufReadPre', {
    group = group,
    callback = function(event)
      maybe_mark_by_size(event.buf, event.file)
    end,
  })
  vim.api.nvim_create_autocmd('BufReadPost', {
    group = group,
    callback = function(event)
      if vim.api.nvim_buf_line_count(event.buf) >= settings().large_file_lines then
        vim.b[event.buf].go_ide_large_file = true
      end
      if M.is_large(event.buf) then
        disable_expensive_features(event.buf)
        vim.schedule(function()
          vim.notify('Large-file mode: expensive diagnostics/UI disabled for this buffer')
        end)
      end
    end,
  })
  vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    callback = function(event)
      if not M.is_large(event.buf) then return end
      local id = event.data and event.data.client_id
      if id then vim.schedule(function() pcall(vim.lsp.buf_detach_client, event.buf, id) end) end
    end,
  })
  vim.api.nvim_create_user_command('GoLargeFileInfo', function()
    local buf = vim.api.nvim_get_current_buf()
    local file = vim.api.nvim_buf_get_name(buf)
    local stat = file ~= '' and (vim.uv or vim.loop).fs_stat(file) or nil
    vim.notify(string.format(
      'large-file mode: %s\nsize: %s\nlines: %d',
      M.is_large(buf) and 'on' or 'off',
      stat and string.format('%.1f MiB', stat.size / 1024 / 1024) or 'unsaved',
      vim.api.nvim_buf_line_count(buf)
    ))
  end, { desc = 'Show large-file mode state for the current buffer' })
end

return M
