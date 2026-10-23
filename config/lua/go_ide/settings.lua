-- Change these preferences, then restart nvim-go.
return {
  icons = true,                 -- false if you prefer plain text over Nerd Font icons
  auto_explorer = true,
  explorer_width = 34,
  statusline_theme = 'horizon', -- keep the original per-pane Horizon status bars
  breadcrumbs = true,          -- VS Code-like file/symbol context below the tabs; toggle with Space u b
  editor_top_padding = true,   -- one blank row above code when breadcrumbs are hidden
  always_show_tabs = true,      -- keep the file-tab strip visible like a GUI editor
  minimap = true,               -- enabled automatically on sufficiently wide editor windows
  minimap_min_columns = 140,
  minimap_width = 10,
  sticky_context = true,        -- pin the current Go type/function while scrolling
  sticky_context_lines = 2,
  inline_diagnostics = true,    -- show the current line's diagnostic below the source line
  responsive_layout = true,     -- collapse secondary chrome on narrow terminal windows
  explorer_hide_below = 108,
  explorer_restore_above = 122,
  test_gutter = true,           -- persistent pass/fail markers until the test file changes
  startup_budget_ms = 180,      -- shown by :GoIdeProfile; informational, not a hard failure
  workspace_auto_restore = true,
  workspace_max_recent = 20,
  large_file_bytes = 2 * 1024 * 1024,
  large_file_lines = 20000,
  format_on_save = true,
  inlay_hints = false,          -- keep the source uncluttered; toggle with Space c i
  codelens = true,
  relative_numbers = true,      -- relative distances, with an amber current line number
  show_whitespace = true,      -- subtle » markers for Go tabs and dots for trailing spaces
  terminal_height = 13,
  hover_max_width = 100,       -- wide documentation, constrained to the available editor
  hover_max_height = 24,
  hover_border = 'rounded',
  -- Palette sampled from your current Neovim screenshot.
  colors = {
    bg = '#1a1b26', bg_inactive = '#181923', panel = '#16161e', tab = '#16161e', chrome = '#171821',
    float_border = '#52638b',
    active_tab = '#24283b', selection = '#292e42',
    line = '#292e42', border = '#1c1e2b', fg = '#c0caf5', fg_dim = '#a9b1d6',
    muted = '#565f89', hidden = '#424455', gutter = '#3b4261', comment = '#565f89',
    coral = '#f7768e', teal = '#0db9d7', purple = '#9d7cd8', mauve = '#bb9af7',
    orange = '#ff9e64', blue = '#7aa2f7', cyan = '#7dcfff', green = '#9ece6a',
    red = '#f7768e', yellow = '#e0af68', accent = '#25b2bc', go_icon = '#00add8',
    member = '#73daca', visual = '#283457', search = '#3d59a1',
    link = '#2ac3de', inline_code = '#414868',
    diff_add = '#20303b', diff_change = '#1f2942', diff_delete = '#3b2533',
    diff_text = '#394b70',
  },
}
