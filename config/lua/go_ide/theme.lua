local M = {}
function M.setup()
  local s = require('go_ide.settings')
  local c = s.colors
  local frame = s.editor_borders ~= false and (c.frame or c.inline_code or c.gutter) or c.border
  vim.cmd('highlight clear')
  vim.g.colors_name = 'go-night'
  local function h(name, fg, bg, extra)
    vim.api.nvim_set_hl(0, name, vim.tbl_extend('force', { fg = fg, bg = bg }, extra or {}))
  end
  h('Normal', c.fg, c.bg); h('NormalNC', c.fg, c.bg)
  h('NormalFloat', c.fg, c.panel); h('FloatBorder', c.gutter, c.panel)
  h('FloatTitle', c.blue, c.panel, { bold = true })
  h('GoIdeHoverNormal', c.fg, c.panel)
  h('GoIdeHoverBorder', c.blue, c.panel)
  h('GoIdeHoverTitle', c.blue, c.panel, { bold = true })
  -- Native Markdown links retain the screenshot's teal label and code backdrop.
  -- Language-specific groups leave injected Go signature highlighting intact.
  h('@markup.link.label.markdown_inline', c.link, nil, { underline = false })
  h('@markup.raw.markdown_inline', c.link, c.inline_code, { underline = false })
  h('CursorLine', nil, c.line); h('CursorLineNr', c.orange, c.bg, { bold = true })
  h('LineNr', c.gutter, c.bg); h('SignColumn', c.gutter, c.bg)
  h('EndOfBuffer', c.bg, c.bg); h('WinSeparator', frame, c.bg)
  h('Visual', nil, c.visual); h('Search', c.fg, c.search)
  h('IncSearch', c.bg, c.orange); h('CurSearch', c.bg, c.orange)
  h('MatchParen', c.orange, c.selection, { bold = true })
  h('NonText', c.gutter); h('Whitespace', c.gutter)
  h('Comment', c.comment, nil, { italic = true })
  h('Constant', c.orange); h('String', c.green); h('Character', c.green)
  h('Number', c.orange); h('Boolean', c.coral); h('Float', c.orange)
  h('Identifier', c.fg); h('Function', c.blue)
  for _, name in ipairs({ 'Statement', 'Conditional', 'Repeat', 'Keyword', 'PreProc', 'Exception' }) do
    h(name, c.purple, nil, { italic = true })
  end
  h('Operator', c.cyan); h('Type', c.teal); h('Special', c.cyan); h('Delimiter', c.fg_dim)
  h('Error', c.red); h('ErrorMsg', c.red); h('WarningMsg', c.yellow)
  h('Todo', c.bg, c.yellow, { bold = true })
  h('Directory', c.blue); h('Title', c.blue, nil, { bold = true })
  h('Folded', c.muted, c.panel); h('FoldColumn', c.gutter, c.bg)
  h('Pmenu', c.fg, c.panel); h('PmenuSel', c.fg, c.selection)
  h('PmenuSbar', nil, c.selection); h('PmenuThumb', nil, c.muted)
  h('StatusLine', c.fg_dim, c.bg); h('StatusLineNC', c.muted, c.panel)
  h('WinBar', c.fg_dim, c.bg); h('WinBarNC', c.muted, c.bg)
  h('GoIdeEditorFrame', c.fg_dim, c.bg, { underline = true, sp = frame })
  h('TabLine', c.fg_dim, c.tab); h('TabLineFill', c.muted, c.tab)
  h('TabLineSel', c.fg, c.bg)
  for name, color in pairs({ Error = c.red, Warn = c.yellow, Info = c.blue, Hint = c.teal }) do
    h('Diagnostic' .. name, color)
    h('DiagnosticSign' .. name, color, c.bg)
    h('DiagnosticUnderline' .. name, nil, nil, { undercurl = true, sp = color })
    h('DiagnosticVirtualText' .. name, color, c.panel)
    h('DiagnosticFloating' .. name, color, c.panel)
  end
  h('LspReferenceRead', nil, c.selection); h('LspReferenceWrite', nil, c.selection)
  h('LspReferenceText', nil, c.selection); h('LspInlayHint', c.muted, c.panel)
  h('LspCodeLens', c.muted); h('LspSignatureActiveParameter', c.yellow, c.selection, { bold = true })
  local syntax = {
    ['@variable'] = c.fg, ['@variable.parameter'] = c.yellow,
    ['@variable.member'] = c.member, ['@variable.builtin'] = c.coral,
    ['@function'] = c.blue, ['@function.call'] = c.blue,
    ['@function.method'] = c.blue, ['@function.method.call'] = c.blue,
    ['@function.builtin'] = c.blue, ['@type'] = c.teal, ['@type.builtin'] = c.teal,
    ['@type.definition'] = c.teal, ['@constructor'] = c.teal,
    ['@module'] = c.cyan, ['@property'] = c.member,
    ['@keyword'] = c.purple, ['@keyword.function'] = c.purple,
    ['@keyword.type'] = c.purple, ['@keyword.import'] = c.purple,
    ['@keyword.return'] = c.purple, ['@keyword.conditional'] = c.purple,
    ['@keyword.repeat'] = c.purple, ['@keyword.operator'] = c.purple,
    ['@keyword.exception'] = c.purple, ['@keyword.coroutine'] = c.purple,
    ['@string'] = c.green, ['@string.escape'] = c.cyan,
    ['@string.special'] = c.cyan, ['@number'] = c.orange,
    ['@boolean'] = c.coral, ['@constant.builtin'] = c.coral,
    ['@punctuation.bracket'] = c.fg_dim, ['@punctuation.delimiter'] = c.fg_dim,
    ['@operator'] = c.cyan, ['@attribute'] = c.yellow,
    ['@lsp.type.type'] = c.teal, ['@lsp.type.struct'] = c.teal,
    ['@lsp.type.interface'] = c.teal, ['@lsp.type.typeParameter'] = c.teal,
    ['@lsp.type.function'] = c.blue, ['@lsp.type.method'] = c.blue,
    ['@lsp.type.parameter'] = c.yellow, ['@lsp.type.variable'] = c.fg,
    ['@lsp.type.property'] = c.member, ['@lsp.type.namespace'] = c.cyan,
    ['@lsp.type.string'] = c.green, ['@lsp.type.number'] = c.orange,
    ['@lsp.type.operator'] = c.cyan,
  }
  for name, color in pairs(syntax) do
    h(name, color, nil, name:match('^@keyword') and { italic = true } or nil)
  end
  -- Tree-sitter owns keyword styling, including the screenshot's italic forms.
  vim.api.nvim_set_hl(0, '@lsp.type.keyword', {})
  h('NeoTreeNormal', c.fg_dim, c.panel); h('NeoTreeNormalNC', c.fg_dim, c.panel)
  h('NeoTreeEndOfBuffer', c.bg, c.panel); h('NeoTreeWinSeparator', frame, c.panel)
  h('NeoTreeCursorLine', nil, c.selection)
  h('NeoTreeRootName', c.fg_dim, c.panel, { bold = true, italic = true })
  h('NeoTreeDirectoryName', c.fg_dim); h('NeoTreeDirectoryIcon', c.blue)
  h('NeoTreeFileName', c.fg_dim); h('NeoTreeFileNameOpened', c.fg_dim)
  h('NeoTreeFileIcon', c.fg_dim); h('NeoTreeIndentMarker', c.gutter)
  h('NeoTreeExpander', c.gutter)
  h('NeoTreeDimText', c.hidden, nil, { italic = true })
  h('NeoTreeMessage', c.hidden, nil, { italic = true })
  h('NeoTreeDotfile', c.muted); h('NeoTreeHiddenByName', c.muted)
  h('NeoTreeFilterTerm', c.cyan)
  h('NeoTreeGitAdded', c.green); h('NeoTreeGitModified', c.yellow)
  h('NeoTreeGitUntracked', c.green); h('NeoTreeGitIgnored', c.muted)
  h('NeoTreeGitStaged', c.green); h('NeoTreeGitUnstaged', c.yellow)
  h('NeoTreeGitDeleted', c.red); h('NeoTreeGitRenamed', c.blue)
  h('NeoTreeGitConflict', c.red); h('NeoTreeModified', c.yellow)
  for name, color in pairs({ Error = c.red, Warn = c.yellow, Info = c.blue, Hint = c.teal }) do
    h('NeoTreeDiagnostic' .. name, color)
  end
  h('DevIconGo', c.go_icon); h('DevIconGoMod', c.go_icon); h('DevIconGoSum', c.go_icon); h('DevIconGoWork', c.go_icon)
  h('IblIndent', c.gutter); h('IblScope', c.muted)
  h('GitSignsAdd', c.green); h('GitSignsChange', c.blue); h('GitSignsDelete', c.red)
  h('DiffAdd', nil, c.diff_add); h('DiffChange', nil, c.diff_change)
  h('DiffDelete', c.red, c.diff_delete); h('DiffText', nil, c.diff_text)
  h('TelescopeNormal', c.fg, c.panel); h('TelescopeBorder', c.gutter, c.panel)
  h('TelescopeSelection', nil, c.selection); h('TelescopeMatching', c.blue, nil, { bold = true })
  h('TelescopePromptPrefix', c.accent); h('TelescopeTitle', c.blue, c.panel, { bold = true })
  h('WhichKey', c.cyan); h('WhichKeyGroup', c.purple); h('WhichKeyDesc', c.fg)
  h('WhichKeyNormal', c.fg, c.panel); h('WhichKeyBorder', c.gutter, c.panel)
  h('NavicText', c.fg_dim); h('NavicSeparator', c.muted)
  for _, kind in ipairs({ 'Function', 'Method', 'Constructor' }) do h('NavicIcons' .. kind, c.blue) end
  for _, kind in ipairs({ 'Struct', 'Class', 'Interface', 'TypeParameter' }) do h('NavicIcons' .. kind, c.teal) end
  h('AerialNormal', c.fg_dim, c.panel); h('AerialLine', nil, c.selection)
  h('AerialGuide', c.gutter)
  h('CmpItemAbbr', c.fg); h('CmpItemAbbrMatch', c.blue, nil, { bold = true })
  h('CmpItemAbbrMatchFuzzy', c.blue, nil, { bold = true }); h('CmpItemMenu', c.muted)
  h('CmpItemAbbrDeprecated', c.muted, nil, { strikethrough = true })
  for _, kind in ipairs({ 'Function', 'Method', 'Constructor' }) do h('CmpItemKind' .. kind, c.blue) end
  for _, kind in ipairs({ 'Class', 'Struct', 'Interface', 'TypeParameter' }) do h('CmpItemKind' .. kind, c.teal) end
  h('CmpItemKindVariable', c.fg); h('CmpItemKindKeyword', c.purple); h('CmpItemKindSnippet', c.yellow)
  h('CodewindowBackground', nil, c.bg); h('CodewindowBorder', c.border, c.bg)
  h('CodewindowUnderline', c.muted); h('CodewindowBoundsBackground', nil, c.panel)
  h('CodewindowError', c.red); h('CodewindowWarn', c.yellow)
  h('DapBreakpoint', c.red); h('DapStopped', c.yellow, c.selection)
  h('DapUINormal', c.fg, c.panel); h('DapUIVariable', c.fg)
  h('DapUIScope', c.cyan); h('DapUIType', c.teal); h('DapUIValue', c.fg)
  h('DapUIModifiedValue', c.yellow); h('DapUIDecoration', c.gutter)
  h('DapUIThread', c.green); h('DapUIStoppedThread', c.yellow)
  h('DapUIFrameName', c.fg); h('DapUISource', c.blue); h('DapUILineNumber', c.muted)
  h('DapUIFloatNormal', c.fg, c.panel); h('DapUIFloatBorder', c.gutter, c.panel)
  h('DapUIWatchesEmpty', c.muted); h('DapUIWatchesValue', c.green); h('DapUIWatchesError', c.red)
  h('DapUIBreakpointsPath', c.cyan); h('DapUIBreakpointsInfo', c.green)
  h('DapUIBreakpointsCurrentLine', c.yellow, nil, { bold = true })
  h('DapUIPlayPause', c.green); h('DapUIRestart', c.green); h('DapUIStop', c.red)
  for _, name in ipairs({ 'DapUIStepOver', 'DapUIStepInto', 'DapUIStepBack', 'DapUIStepOut' }) do h(name, c.blue) end
  h('DapUIUnavailable', c.muted)
  h('GoIdePanelActive', c.cyan, c.selection, { bold = true })
  h('GoIdePanelInactive', c.fg_dim, c.panel)
  h('GoIdePanelFill', c.muted, c.panel)
  local terminal = { c.panel, c.red, c.green, c.yellow, c.blue, c.mauve, c.cyan, c.fg_dim,
    c.gutter, c.red, c.green, c.yellow, c.blue, c.purple, c.teal, c.fg }
  for index, color in ipairs(terminal) do vim.g['terminal_color_' .. (index - 1)] = color end
end
return M
