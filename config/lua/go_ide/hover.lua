-- Keep Neovim's Markdown renderer and Go syntax injection. The wrapper only
-- controls the card's appearance and adds close keys local to the card itself.
local M = {}
local methods = { 'textDocument/hover', 'textDocument/signatureHelp' }
local configured = false

local function is_documentation_window(win)
  if not vim.api.nvim_win_is_valid(win) then return false end
  for _, method in ipairs(methods) do
    -- Native open_floating_preview stores its focus_id on the resulting window.
    if vim.w[win][method] then return true end
  end
  return false
end

local function style_window(win)
  if not is_documentation_window(win) then return end
  local buf = vim.api.nvim_win_get_buf(win)
  vim.wo[win].winhighlight = table.concat({
    'Normal:GoIdeHoverNormal', 'NormalFloat:GoIdeHoverNormal',
    'FloatBorder:GoIdeHoverBorder', 'FloatTitle:GoIdeHoverTitle',
  }, ',')
  vim.wo[win].winblend = 0
  vim.wo[win].list = false
  vim.wo[win].spell = false
  vim.wo[win].cursorline = false
  vim.wo[win].scrolloff = 2

  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  for _, key in ipairs({ 'q', '<Esc>' }) do
    vim.keymap.set('n', key, close, {
      buffer = buf, silent = true, nowait = true, desc = 'Close documentation',
    })
  end
end

function M.setup()
  if configured then return end
  configured = true
  -- Fallbacks also let the wrapper work with a different user colourscheme.
  for name, target in pairs({
    GoIdeHoverNormal = 'NormalFloat',
    GoIdeHoverBorder = 'FloatBorder',
    GoIdeHoverTitle = 'FloatTitle',
  }) do
    vim.api.nvim_set_hl(0, name, { default = true, link = target })
  end
  local group = vim.api.nvim_create_augroup('GoIdeDocumentation', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'markdown',
    callback = function(args)
      -- Native hover sets its focus_id before assigning Markdown's filetype.
      for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do style_window(win) end
    end,
  })
  vim.api.nvim_create_autocmd('WinNew', {
    group = group,
    callback = function()
      -- Covers plaintext LSP results too. Wait until the native handler has
      -- attached its focus_id; unrelated floating windows are left untouched.
      vim.schedule(function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do style_window(win) end
      end)
    end,
  })
end

local function positive_integer(value, fallback)
  return type(value) == 'number' and value >= 1 and math.floor(value) or fallback
end

local function options(title)
  local settings = require('go_ide.settings')
  local columns, lines = vim.o.columns, vim.o.lines
  return {
    border = settings.hover_border or 'rounded',
    title = title,
    title_pos = 'left',
    -- Size to the content, with caps that leave the surrounding source visible.
    max_width = math.max(1, math.min(
      positive_integer(settings.hover_max_width, 100), math.floor(columns * 0.72), columns - 4
    )),
    max_height = math.max(1, math.min(
      positive_integer(settings.hover_max_height, 24), math.floor(lines * 0.45), lines - 4
    )),
    wrap = true,
    relative = 'cursor',
    anchor_bias = 'auto',
    focusable = true,
    focus = true,
  }
end

function M.open()
  M.setup()
  -- Calling again focuses the native popup: j/k, Ctrl-D/U, and gx keep their
  -- normal meanings there. Moving in the source dismisses an unfocused card.
  vim.lsp.buf.hover(options(' Documentation '))
end

function M.signature_help()
  M.setup()
  -- Preserve native overload cycling and active-parameter highlighting.
  vim.lsp.buf.signature_help(options(' Signature '))
end

return M
