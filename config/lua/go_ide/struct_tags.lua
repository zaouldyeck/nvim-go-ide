local M = {}

local tag_modes = {
  json = { tag = 'json', omitempty = false },
  ['json-omitempty'] = { tag = 'json', omitempty = true },
  yaml = { tag = 'yaml', omitempty = false },
  ['yaml-omitempty'] = { tag = 'yaml', omitempty = true },
}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO)
end

local function source_for(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local source = table.concat(lines, '\n')
  if vim.bo[buf].endofline then source = source .. '\n' end
  return source
end

local function cursor_offset(buf)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local before = vim.api.nvim_buf_get_lines(buf, 0, row - 1, false)
  local offset = col
  for _, line in ipairs(before) do offset = offset + #line + 1 end
  return offset
end

local function apply_patch(buf, patch)
  if type(patch) ~= 'table' or type(patch.start) ~= 'number'
    or type(patch['end']) ~= 'number' or type(patch.lines) ~= 'table' then
    notify('Struct tags: gomodifytags returned an invalid editor patch.', vim.log.levels.ERROR)
    return false
  end
  local views = {}
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
  end
  vim.api.nvim_buf_set_lines(buf, patch.start - 1, patch['end'], false, patch.lines)
  for win, view in pairs(views) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_call(win, function() vim.fn.winrestview(view) end)
    end
  end
  return true
end

function M.add(tag, omitempty)
  if tag ~= 'json' and tag ~= 'yaml' then
    notify('Supported automatic struct tags are json and yaml.', vim.log.levels.ERROR)
    return false
  end

  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= 'go' then
    notify('Struct tags are available in Go buffers.', vim.log.levels.WARN)
    return false
  end
  local filename = vim.api.nvim_buf_get_name(buf)
  if filename == '' then
    notify('Save or name this Go buffer before adding struct tags.', vim.log.levels.WARN)
    return false
  end

  local executable = require('go_ide.lsp').tool('gomodifytags')
  if vim.fn.executable(executable) ~= 1 then
    notify('gomodifytags is missing. Re-run install.sh to install the pinned Go tools.', vim.log.levels.ERROR)
    return false
  end

  local source = source_for(buf)
  local args = {
    executable,
    '-file', filename,
    '-offset', tostring(cursor_offset(buf)),
    '-add-tags', tag,
    '-transform', 'snakecase',
    '-format', 'json',
    '-modified',
  }
  if omitempty then
    vim.list_extend(args, { '-add-options', tag .. '=omitempty' })
  end

  -- gomodifytags' -modified mode reads an overlay archive from stdin, so
  -- unsaved Neovim edits are the source of truth. -format json returns only
  -- the affected line range, which keeps undo history and unrelated formatting
  -- untouched.
  local archive = filename .. '\n' .. tostring(#source) .. '\n' .. source
  local ok, result = pcall(function()
    return vim.system(args, {
      stdin = archive,
      text = true,
      cwd = vim.fs.dirname(filename),
    }):wait(5000)
  end)
  if not ok or not result or result.code ~= 0 then
    local reason = ok and result and vim.trim(result.stderr or '') or tostring(result)
    if reason == '' then reason = 'gomodifytags timed out or the cursor is not inside a struct.' end
    notify('Struct tags: ' .. reason, vim.log.levels.WARN)
    return false
  end

  local decoded_ok, patch = pcall(vim.json.decode, result.stdout or '')
  if not decoded_ok then
    notify('Struct tags: could not decode gomodifytags editor output.', vim.log.levels.ERROR)
    return false
  end
  if patch.errors and #patch.errors > 0 then
    notify('Struct tags: ' .. table.concat(patch.errors, '; '), vim.log.levels.WARN)
  end
  if not apply_patch(buf, patch) then return false end

  notify(string.format('Added %s tags%s to the struct.', tag, omitempty and ' with omitempty' or ''))
  return true
end

function M.protobuf()
  local filename = vim.api.nvim_buf_get_name(0)
  local generated = filename:match('%.pb%.go$') ~= nil
  local message
  if generated then
    message = 'This is generated protobuf Go code. Wire tags are owned by protoc; edit the .proto schema and regenerate instead.'
  else
    message = 'Protobuf wire tags require schema field numbers and wire types, so they cannot be safely inferred from a Go struct. Define the message in .proto and regenerate with protoc or Buf. For extra custom Go tags on generated messages, use @gotags with a protobuf tag-injection step.'
  end
  notify(message, vim.log.levels.WARN)
  return false
end

function M.pick()
  local choices = {
    { label = 'JSON', mode = 'json' },
    { label = 'JSON + omitempty', mode = 'json-omitempty' },
    { label = 'YAML', mode = 'yaml' },
    { label = 'YAML + omitempty', mode = 'yaml-omitempty' },
    { label = 'Protobuf tags (schema-safe guidance)', mode = 'protobuf' },
  }
  vim.ui.select(choices, {
    prompt = 'Struct tags',
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    if choice.mode == 'protobuf' then M.protobuf(); return end
    local mode = tag_modes[choice.mode]
    M.add(mode.tag, mode.omitempty)
  end)
end

function M.run(mode)
  if not mode or mode == '' then M.pick(); return true end
  if mode == 'protobuf' then return M.protobuf() end
  local selected = tag_modes[mode]
  if not selected then
    notify('Unknown tag mode: ' .. tostring(mode), vim.log.levels.ERROR)
    return false
  end
  return M.add(selected.tag, selected.omitempty)
end

function M.setup()
  vim.api.nvim_create_user_command('GoStructTags', function(opts)
    M.run(opts.args)
  end, {
    nargs = '?',
    complete = function(prefix)
      local values = { 'json', 'json-omitempty', 'yaml', 'yaml-omitempty', 'protobuf' }
      return vim.tbl_filter(function(value) return vim.startswith(value, prefix) end, values)
    end,
    desc = 'Add JSON/YAML tags to the struct under the cursor, or show protobuf guidance',
  })
end

return M
