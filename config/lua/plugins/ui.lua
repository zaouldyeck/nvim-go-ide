local s = require('go_ide.settings')
local c = s.colors
local chrome = c.chrome or c.tab
local active_tab = c.active_tab or c.selection
local tab_highlights = {
  fill = { bg = chrome },
  background = { fg = c.muted, bg = chrome, italic = false },
  buffer_visible = { fg = c.fg_dim, bg = chrome, italic = false },
  buffer_selected = { fg = c.fg, bg = active_tab, bold = true, italic = false },
  separator = { fg = chrome, bg = chrome },
  separator_visible = { fg = chrome, bg = chrome },
  separator_selected = { fg = active_tab, bg = chrome },
  offset_separator = { fg = c.panel, bg = c.panel },
}
-- Inactive tabs blend into the bar. The selected tab gets a darker body and
-- Nerd Font semicircle separators, which gives it a soft rounded-card shape.
for _, suffix in ipairs({ '', '_visible', '_selected' }) do
  local bg = suffix == '_selected' and active_tab or chrome
  for name, color in pairs({
    close_button = c.muted, modified = c.yellow, duplicate = c.muted,
    numbers = c.fg_dim, diagnostic = c.fg_dim,
    error = c.red, error_diagnostic = c.red,
    warning = c.yellow, warning_diagnostic = c.yellow,
    info = c.blue, info_diagnostic = c.blue,
    hint = c.teal, hint_diagnostic = c.teal,
  }) do
    tab_highlights[name .. suffix] = { fg = color, bg = bg, italic = false }
  end
end
local plain_icons = {}
for _, kind in ipairs({ 'File', 'Module', 'Namespace', 'Package', 'Class', 'Method', 'Property', 'Field', 'Constructor', 'Enum', 'Interface', 'Function', 'Variable', 'Constant', 'String', 'Number', 'Boolean', 'Array', 'Object', 'Key', 'Null', 'EnumMember', 'Struct', 'Event', 'Operator', 'TypeParameter' }) do
  plain_icons[kind] = ''
end
return {
  {
    'nvim-tree/nvim-web-devicons',
    opts = {
      color_icons = true,
      override_by_extension = { go = { icon = '', color = c.go_icon, name = 'Go' } },
      override_by_filename = {
        ['go.mod'] = { icon = '', color = c.go_icon, name = 'GoMod' },
        ['go.sum'] = { icon = '', color = c.go_icon, name = 'GoSum' },
        ['go.work'] = { icon = '', color = c.go_icon, name = 'GoWork' },
      },
    },
  },
  {
    'nvim-neo-tree/neo-tree.nvim', branch = 'v3.x',
    dependencies = { 'nvim-lua/plenary.nvim', 'MunifTanjim/nui.nvim', 'nvim-tree/nvim-web-devicons' },
    init = function()
      -- Netrw is disabled for this profile. Neo-tree clears its FileExplorer
      -- group during setup; create the empty group so that cleanup is valid.
      vim.api.nvim_create_augroup('FileExplorer', { clear = false })
    end,
    opts = {
      popup_border_style = 'rounded',
      enable_diagnostics = true, enable_modified_markers = true,
      window = {
        position = 'left', width = s.explorer_width,
        mappings = {
          ['<C-b>'] = 'close_window', -- keep the global Explorer shortcut in this pane
          ['l'] = 'open', ['h'] = 'close_node',
        },
      },
      default_component_configs = {
        -- Neo-tree supplies the complete :~ root path and clips at the right edge.
        icon = {
          folder_closed = s.icons and '' or '', folder_open = s.icons and '' or '',
          folder_empty = s.icons and '' or '', folder_empty_open = s.icons and '' or '',
          default = s.icons and '' or '',
          provider = not s.icons and function(icon) icon.text = ''; return icon end or nil,
        },
        indent = {
          padding = 1, indent_size = 2,
          expander_collapsed = s.icons and '' or '+', expander_expanded = s.icons and '' or '-',
        },
        name = { use_git_status_colors = false },
        modified = { symbol = '[+] ', highlight = 'NeoTreeModified' },
        diagnostics = {
          symbols = { error = 'E', warn = 'W', info = 'I', hint = 'H' },
          highlights = {
            error = 'NeoTreeDiagnosticError', warn = 'NeoTreeDiagnosticWarn',
            info = 'NeoTreeDiagnosticInfo', hint = 'NeoTreeDiagnosticHint',
          },
        },
        git_status = {
          symbols = {
            added = '', modified = '', deleted = 'D', renamed = 'R',
            untracked = '', ignored = '', unstaged = 'M', staged = 'S', conflict = '!',
          },
        },
        file_size = { enabled = false }, type = { enabled = false },
        last_modified = { enabled = false }, created = { enabled = false },
      },
      filesystem = {
        bind_to_cwd = true,
        follow_current_file = { enabled = true },
        group_empty_dirs = true,
        hijack_netrw_behavior = 'open_default',
        use_libuv_file_watcher = true,
        filtered_items = {
          visible = false, hide_dotfiles = true, hide_gitignored = true,
          show_hidden_count = true,
        },
      },
    },
  },
  {
    'akinsho/bufferline.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      options = {
        mode = 'buffers', numbers = 'none',
        separator_style = s.icons and { '', '' } or 'thin',
        indicator = { style = 'none' },
        diagnostics = 'nvim_lsp', diagnostics_update_in_insert = false,
        diagnostics_indicator = function(count) return ' ' .. count end,
        modified_icon = '●', buffer_close_icon = '×', close_icon = '×',
        show_buffer_icons = s.icons, show_buffer_close_icons = false, show_close_icon = false,
        always_show_bufferline = s.always_show_tabs, enforce_regular_tabs = false,
        max_name_length = 24, tab_size = 18, truncate_names = true,
        -- Let the sidebar background provide separation; no vertical divider.
        offsets = { { filetype = 'neo-tree', text = 'Explorer', text_align = 'left', padding = 0, separator = false } },
        close_command = function(buf) require('go_ide.ui').close_buffer(buf) end,
        right_mouse_command = function(buf) require('go_ide.ui').close_buffer(buf) end,
        custom_filter = function(buf) return vim.bo[buf].buftype == '' end,
      },
      highlights = tab_highlights,
    },
  },
  { 'SmiteshP/nvim-navic', opts = { highlight = true, icons = not s.icons and plain_icons or nil, separator = '  ›  ', depth_limit = 5, lsp = { auto_attach = true, preference = { 'gopls' } } } },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons', 'SmiteshP/nvim-navic' },
    opts = {
      options = {
        theme = s.statusline_theme,
        icons_enabled = s.icons,
        component_separators = s.icons and { left = '', right = '' } or { left = '|', right = '|' },
        section_separators = s.icons and { left = '', right = '' } or { left = '', right = '' },
        globalstatus = false,
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'branch', 'diff', { 'diagnostics', sources = { 'nvim_diagnostic' } } },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'encoding', 'fileformat', 'filetype' },
        lualine_y = { 'progress' }, lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {}, lualine_b = {}, lualine_c = { 'filename' },
        lualine_x = { 'location' }, lualine_y = {}, lualine_z = {},
      },
      extensions = { 'quickfix', 'aerial', 'nvim-dap-ui' },
    },
  },
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-ui-select.nvim' },
    opts = {
      defaults = {
        prompt_prefix = '  > ', selection_caret = '  ',
        borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
        path_display = { 'truncate' }, sorting_strategy = 'ascending',
        layout_config = { prompt_position = 'top', width = 0.86, height = 0.8 },
        file_ignore_patterns = { '^.git/' },
        mappings = { i = { ['<Esc>'] = 'close', ['<C-j>'] = 'move_selection_next', ['<C-k>'] = 'move_selection_previous' } },
      },
      pickers = {
        find_files = { hidden = true, find_command = { 'rg', '--files', '--hidden', '-g', '!.git' } },
        live_grep = { additional_args = function() return { '--hidden', '-g', '!.git' } end },
      },
    },
    config = function(_, opts)
      opts.extensions = opts.extensions or {}
      opts.extensions['ui-select'] = {
        require('telescope.themes').get_dropdown({ previewer = false }),
      }
      require('telescope').setup(opts)
      require('telescope').load_extension('ui-select')
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter', branch = 'master',
    -- This frozen API is deliberately paired with Neovim 0.11.7.
    -- The installer performs synchronous, checked parser installation.
    config = function()
      require('nvim-treesitter.configs').setup({
        ensure_installed = {}, auto_install = false,
        highlight = { enable = true, additional_vim_regex_highlighting = false },
        indent = { enable = true, disable = { 'go' } },
      })
    end,
  },
  { 'lukas-reineke/indent-blankline.nvim', main = 'ibl', opts = { indent = { char = '│', tab_char = '»' }, scope = { enabled = true, show_start = false, show_end = false } } },
  {
    'stevearc/aerial.nvim', branch = 'nvim-0.11',
    dependencies = { 'nvim-tree/nvim-web-devicons', 'nvim-treesitter/nvim-treesitter' },
    opts = { backends = { 'lsp', 'treesitter' }, icons = not s.icons and plain_icons or nil, layout = { min_width = 28, max_width = 42, default_direction = 'right' }, show_guides = true },
  },
  {
    'gorbit99/codewindow.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      auto_enable = false, minimap_width = s.minimap_width, width_multiplier = 4,
      window_border = 'none', z_index = 5, screen_bounds = 'background',
      exclude_filetypes = { 'help', 'neo-tree', 'neo-tree-popup', 'aerial', 'lazy', 'qf', 'Trouble', 'goideoutput', 'dap-repl', 'dapui_scopes', 'dapui_stacks', 'dapui_watches', 'dapui_breakpoints', 'dapui_console' },
      max_lines = 5000, use_git = false,
    },
  },
  { 'folke/trouble.nvim', opts = { focus = true, auto_close = false, warn_no_results = false, open_no_results = true, win = { position = 'bottom', size = 12 }, preview = { type = 'main' } } },
  { 'folke/which-key.nvim', opts = { preset = 'modern', delay = 350, icons = { mappings = s.icons }, win = { border = 'rounded' } } },
  {
    'lewis6991/gitsigns.nvim',
    opts = { signs = { add = { text = '│' }, change = { text = '│' }, delete = { text = '_' }, topdelete = { text = '‾' }, changedelete = { text = '│' } }, current_line_blame = false },
  },
  {
    'windwp/nvim-autopairs', event = 'InsertEnter', opts = { check_ts = true },
    config = function(_, opts)
      require('nvim-autopairs').setup(opts)
      require('cmp').event:on('confirm_done', require('nvim-autopairs.completion.cmp').on_confirm_done())
    end,
  },
}
