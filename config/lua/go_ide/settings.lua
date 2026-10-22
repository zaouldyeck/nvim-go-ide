-- Change these preferences, then restart nvim-go.
return {
  icons = true,                 -- false if you prefer plain text over Nerd Font icons
  auto_explorer = true,
  explorer_width = 40,
  statusline_theme = 'horizon', -- your rose Normal / cyan Insert bar, on both ends
  breadcrumbs = false,         -- toggle with Space u b when you want symbol context
  editor_top_padding = true,   -- one blank row above code when breadcrumbs are hidden
  editor_borders = true,       -- subtle header rule and aligned pane dividers
  always_show_tabs = false,     -- file tabs appear automatically with multiple files
  minimap = false,              -- toggle with Space m m; automatically sized for wide editors
  minimap_min_columns = 160,
  minimap_width = 12,
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
    bg = '#1a1b26', panel = '#16161e', tab = '#16161e', selection = '#292e42',
    line = '#292e42', border = '#1c1e2b', frame = '#52638b', fg = '#c0caf5', fg_dim = '#a9b1d6',
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
