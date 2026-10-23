local s = require('go_ide.settings')
local c = s.colors
local plain_icons = {}
for _, kind in ipairs({ 'File', 'Module', 'Namespace', 'Package', 'Class', 'Method', 'Property', 'Field', 'Constructor', 'Enum', 'Interface', 'Function', 'Variable', 'Constant', 'String', 'Number', 'Boolean', 'Array', 'Object', 'Key', 'Null', 'EnumMember', 'Struct', 'Event', 'Operator', 'TypeParameter' }) do
  plain_icons[kind] = ''
end
return {
  {
    'nvim-tree/nvim-web-devicons',
    lazy = true,
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
    lazy = true,
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
  { 'SmiteshP/nvim-navic', lazy = false, opts = { highlight = true, icons = not s.icons and plain_icons or nil, separator = '  ›  ', depth_limit = 5, lsp = { auto_attach = true, preference = { 'gopls' } } } },
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      enable = s.sticky_context ~= false,
      multiwindow = true,
      max_lines = s.sticky_context_lines or 2,
      min_window_height = 12,
      line_numbers = true,
      multiline_threshold = 3,
      trim_scope = 'outer',
      mode = 'cursor',
      separator = nil,
      zindex = 19,
      on_attach = function(buf)
        return vim.bo[buf].buftype == '' and vim.bo[buf].filetype ~= ''
      end,
    },
  },
  {
    'j-hui/fidget.nvim',
    lazy = false,
    config = function()
      local notification = require('fidget.notification')
      require('fidget').setup({
        progress = {
          suppress_on_insert = true,
          display = {
            done_ttl = 1.2,
            progress_icon = { 'dots' },
            done_icon = '✓',
            group_style = 'GoIdeNotifyTitle',
            progress_style = 'GoIdeNotifyProgress',
            done_style = 'GoIdeNotifyDone',
          },
        },
        notification = {
          override_vim_notify = true,
          configs = {
            default = vim.tbl_extend('force', notification.default_config, {
              name = false, icon = false, ttl = 2.2,
              annote_style = 'GoIdeNotifyTitle',
              info_style = 'GoIdeNotifyInfo',
              warn_style = 'GoIdeNotifyWarn',
              error_style = 'GoIdeNotifyError',
            }),
          },
          view = {
            stack_upwards = true, align = 'message', reflow = true,
            group_separator = '', line_margin = 1,
          },
          window = {
            normal_hl = 'GoIdeNotifyNormal', winblend = 0, border = 'rounded',
            max_width = 52, max_height = 8, x_padding = 1, y_padding = 1,
            align = 'bottom', h_align = 'right', relative = 'editor',
            avoid = { 'neo-tree', 'aerial', 'Trouble', 'dapui_scopes', 'dapui_stacks' },
          },
        },
      })
    end,
  },
  {
    'folke/flash.nvim',
    lazy = true,
    opts = {
      labels = 'asdfghjklqwertyuiopzxcvbnm',
      modes = { char = { enabled = false } },
      label = { uppercase = false, rainbow = { enabled = false } },
      highlight = { backdrop = true, matches = true },
    },
  },
  {
    'stevearc/quicker.nvim',
    lazy = true,
    opts = {
      opts = { number = false, relativenumber = false, signcolumn = 'auto', winfixheight = true, wrap = false },
      keys = {
        { '>', function() require('quicker').expand({ before = 2, after = 2, add_to_existing = true }) end, desc = 'Expand context' },
        { '<', function() require('quicker').collapse() end, desc = 'Collapse context' },
      },
      edit = { enabled = true, autosave = 'unmodified' },
      highlight = { treesitter = true, lsp = true, load_buffers = false },
      follow = { enabled = true },
      trim_leading_whitespace = 'common',
    },
  },
  {
    'nvim-lualine/lualine.nvim',
    lazy = false,
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
    lazy = true,
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
    event = { 'BufReadPost', 'BufNewFile' },
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
  { 'lukas-reineke/indent-blankline.nvim', main = 'ibl', event = { 'BufReadPost', 'BufNewFile' }, opts = { indent = { char = '│', tab_char = '»' }, scope = { enabled = true, show_start = false, show_end = false } } },
  {
    'stevearc/aerial.nvim', branch = 'nvim-0.11',
    cmd = { 'AerialToggle', 'AerialOpen', 'AerialNavToggle' },
    dependencies = { 'nvim-tree/nvim-web-devicons', 'nvim-treesitter/nvim-treesitter' },
    opts = { backends = { 'lsp', 'treesitter' }, icons = not s.icons and plain_icons or nil, layout = { min_width = 28, max_width = 42, default_direction = 'right' }, show_guides = true },
  },
  {
    'gorbit99/codewindow.nvim',
    lazy = true,
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      auto_enable = false, minimap_width = s.minimap_width, width_multiplier = 4,
      window_border = 'none', z_index = 5, screen_bounds = 'background',
      exclude_filetypes = { 'help', 'neo-tree', 'neo-tree-popup', 'aerial', 'lazy', 'qf', 'Trouble', 'goideoutput', 'dap-repl', 'dapui_scopes', 'dapui_stacks', 'dapui_watches', 'dapui_breakpoints', 'dapui_console' },
      max_lines = 5000, use_git = false,
    },
  },
  { 'folke/trouble.nvim', cmd = { 'Trouble' }, opts = { focus = true, auto_close = false, warn_no_results = false, open_no_results = true, win = { position = 'bottom', size = 12 }, preview = { type = 'main' } } },
  { 'folke/which-key.nvim', event = 'VeryLazy', opts = { preset = 'modern', delay = 350, icons = { mappings = s.icons }, win = { border = 'rounded' } } },
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
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
