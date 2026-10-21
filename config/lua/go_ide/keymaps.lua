local M = {}

function M.setup()
  local function map(modes, lhs, rhs, description)
    vim.keymap.set(modes, lhs, rhs, { desc = description, silent = true })
  end
  local function telescope(name)
    return function() require('telescope.builtin')[name]() end
  end
  local function go(name, argument)
    return function() require('go_ide.go')[name](argument) end
  end
  local function dap(name)
    return function() require('dap')[name]() end
  end

  map({ 'n', 'i', 'x' }, '<C-s>', '<Cmd>write<CR>', 'Save file')
  map('n', '<leader>ww', '<Cmd>write<CR>', 'Save file')
  map('n', '<leader>wq', '<Cmd>wq<CR>', 'Save and close window')
  map('n', '<leader>qq', '<Cmd>confirm qall<CR>', 'Quit editor')
  map('n', '<leader>bd', function() require('go_ide.ui').close_buffer() end, 'Close buffer')
  map('n', '<Tab>', '<Cmd>BufferLineCycleNext<CR>', 'Next file tab')
  map('n', '<S-Tab>', '<Cmd>BufferLineCyclePrev<CR>', 'Previous file tab')
  -- Terminals often encode Tab and Ctrl-I identically. Keep jump-forward available.
  map('n', '<leader>jf', '<C-i>', 'Jump forward')
  map('n', '<leader>jb', '<C-o>', 'Jump back')
  map('n', '<Esc>', '<Cmd>nohlsearch<CR>', 'Clear search highlight')

  map('n', '<C-p>', telescope('find_files'), 'Find file')
  map('n', '<leader>ff', telescope('find_files'), 'Find file')
  map('n', '<leader>fg', telescope('live_grep'), 'Search project text')
  map('n', '<leader>fb', telescope('buffers'), 'Find open buffer')
  map('n', '<leader>fr', telescope('oldfiles'), 'Recent files')
  map('n', '<leader>fc', telescope('commands'), 'Command palette')
  map('n', '<leader>fs', telescope('lsp_document_symbols'), 'File symbols')
  map('n', '<leader>fS', telescope('lsp_dynamic_workspace_symbols'), 'Workspace symbols')
  -- Keep the familiar search keys alongside the Find menu.
  map('n', '<leader>sf', telescope('find_files'), 'Find file')
  map('n', '<leader>sg', telescope('live_grep'), 'Search project text')
  map('n', '<leader>sw', telescope('grep_string'), 'Search word under cursor')
  map('n', '<leader>sr', telescope('resume'), 'Resume last search')
  map('n', '<leader>sh', telescope('help_tags'), 'Search help')
  map('n', '<leader>sk', telescope('keymaps'), 'Search keymaps')
  map('n', '<leader>ss', telescope('builtin'), 'Choose a Telescope search')
  map('n', '<leader>sd', telescope('diagnostics'), 'Search diagnostics')
  map('n', '<leader>s.', telescope('oldfiles'), 'Recent files')
  map('n', '<leader><leader>', telescope('buffers'), 'Find open buffer')
  map('n', '<leader>/', function()
    require('telescope.builtin').current_buffer_fuzzy_find(
      require('telescope.themes').get_dropdown({ previewer = false })
    )
  end, 'Fuzzy search current file')
  map('n', '<leader>s/', function()
    require('telescope.builtin').live_grep({ grep_open_files = true, prompt_title = 'Search Open Files' })
  end, 'Search text in open files')
  map('n', '<leader>sn', function()
    require('telescope.builtin').find_files({ cwd = vim.fn.stdpath('config'), prompt_title = 'Neovim Configuration' })
  end, 'Find Neovim configuration file')
  map('n', '<C-b>', function() require('go_ide.explorer').toggle() end, 'Toggle Explorer')
  map('n', '<leader>e', function() require('go_ide.explorer').toggle() end, 'Toggle Explorer')
  map('n', '<leader>E', function() require('go_ide.explorer').reveal() end, 'Reveal file in Explorer')
  map('n', '<leader>o', '<Cmd>AerialToggle<CR>', 'Toggle symbol outline')
  map('n', '<leader>mm', function() require('go_ide.ui').toggle_minimap() end, 'Toggle minimap')

  map('n', '<leader>xx', function() require('go_ide.ui').open_panel('problems') end, 'Problems panel')
  map('n', '<leader>xd', function() vim.diagnostic.open_float(nil, { scope = 'line' }) end, 'Line diagnostic')
  map('n', '<leader>xn', function() vim.diagnostic.jump({ count = 1, float = true }) end, 'Next diagnostic')
  map('n', '<leader>xp', function() vim.diagnostic.jump({ count = -1, float = true }) end, 'Previous diagnostic')
  map('n', 'gd', vim.lsp.buf.definition, 'Go to definition')
  map('n', '<F12>', vim.lsp.buf.definition, 'Go to definition')
  map('n', 'gr', telescope('lsp_references'), 'Find references')
  map('n', 'gi', vim.lsp.buf.implementation, 'Go to implementation')
  map('n', 'gy', vim.lsp.buf.type_definition, 'Go to type definition')
  map('n', 'K', function() require('go_ide.hover').open() end, 'Hover documentation (again to focus)')
  map('i', '<C-k>', function() require('go_ide.hover').signature_help() end, 'Signature help')
  map('n', '<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
  map('n', '<F2>', vim.lsp.buf.rename, 'Rename symbol')
  map({ 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action, 'Code action')
  map('n', '<leader>cf', function() require('go_ide.lsp').format() end, 'Format and organize imports')
  map('n', '<leader>ci', function() require('go_ide.lsp').toggle_inlay_hints() end, 'Toggle inlay hints')
  map('n', '<leader>cl', vim.lsp.codelens.run, 'Run code lens')
  map('n', '<leader>cm', go('mod_tidy'), 'Tidy Go module dependencies')

  map('n', '<leader>tt', go('test', 'nearest'), 'Test nearest')
  map('n', '<leader>tp', go('test', 'package'), 'Test package')
  map('n', '<leader>tf', go('test', 'file'), 'Test file')
  map('n', '<leader>ta', go('test', 'all'), 'Test module')
  map('n', '<leader>to', go('toggle_output'), 'Toggle test output')
  map('n', '<leader>tc', go('coverage'), 'Run coverage')
  map('n', '<leader>tC', go('clear_coverage'), 'Clear coverage')
  map('n', '<leader>ts', go('stop'), 'Stop Go task')
  map('n', '<leader>rr', go('run'), 'Run Go package')
  -- Ex command completion parses arguments into a list without invoking a shell.
  map('n', '<leader>ra', ':GoRun ', 'Run Go package with arguments')

  map('n', '<F9>', dap('toggle_breakpoint'), 'Toggle breakpoint')
  map('n', '<leader>db', dap('toggle_breakpoint'), 'Toggle breakpoint')
  map('n', '<F5>', dap('continue'), 'Debug: start or continue')
  map('n', '<leader>dc', dap('continue'), 'Debug: start or continue')
  map('n', '<F10>', dap('step_over'), 'Debug: step over')
  map('n', '<leader>do', dap('step_over'), 'Debug: step over')
  map('n', '<F11>', dap('step_into'), 'Debug: step into')
  map('n', '<leader>di', dap('step_into'), 'Debug: step into')
  map('n', '<S-F11>', dap('step_out'), 'Debug: step out')
  map('n', '<leader>dO', dap('step_out'), 'Debug: step out')
  map('n', '<leader>dr', function() require('go_ide.debug').debug_test() end, 'Debug nearest test')
  map('n', '<leader>dR', function() require('go_ide.debug').debug_last_test() end, 'Debug last test')
  map('n', '<leader>du', function() require('dapui').toggle() end, 'Toggle debugger panels')
  map({ 'n', 'x' }, '<leader>de', function() require('dapui').eval() end, 'Evaluate expression')
  map('n', '<leader>dt', dap('terminate'), 'Stop debugger')
  map('n', '<leader>dp', dap('pause'), 'Pause debugger')
  map('n', '<leader>dB', function()
    vim.ui.input({ prompt = 'Breakpoint condition: ' }, function(condition)
      if condition and condition ~= '' then require('dap').set_breakpoint(condition) end
    end)
  end, 'Conditional breakpoint')

  map('n', '<leader>`', function() require('go_ide.terminal').toggle() end, 'Toggle terminal')
  map('t', '<Esc><Esc>', '<C-\\><C-n>', 'Leave terminal input mode')
  map('n', '<C-h>', '<C-w>h', 'Focus left pane')
  map('n', '<C-j>', '<C-w>j', 'Focus lower pane')
  map('n', '<C-k>', '<C-w>k', 'Focus upper pane')
  map('n', '<C-l>', '<C-w>l', 'Focus right pane')
  map('n', '<leader>wv', '<Cmd>vsplit<CR>', 'Split vertically')
  map('n', '<leader>ws', '<Cmd>split<CR>', 'Split horizontally')
  map('n', '<leader>wc', '<Cmd>close<CR>', 'Close pane')
  map('n', '<leader>w=', '<C-w>=', 'Equalize pane sizes')
  map('n', '<A-j>', '<Cmd>move .+1<CR>==', 'Move line down')
  map('n', '<A-k>', '<Cmd>move .-2<CR>==', 'Move line up')
  map('x', '<A-j>', ":move '>+1<CR>gv=gv", 'Move selection down')
  map('x', '<A-k>', ":move '<-2<CR>gv=gv", 'Move selection up')

  map('n', '<leader>gh', function() require('gitsigns').preview_hunk() end, 'Preview Git hunk')
  map('n', '<leader>gb', function() require('gitsigns').blame_line({ full = true }) end, 'Git blame line')
  map('n', '<leader>gs', function() require('gitsigns').stage_hunk() end, 'Stage Git hunk')
  map('n', '<leader>gu', function()
    if vim.fn.confirm('Discard changes in this Git hunk?', '&Discard\n&Cancel', 2) == 1 then
      require('gitsigns').reset_hunk()
    end
  end, 'Reset Git hunk (confirm)')
  map('n', '<leader>gn', function() require('gitsigns').nav_hunk('next') end, 'Next Git hunk')
  map('n', '<leader>gp', function() require('gitsigns').nav_hunk('prev') end, 'Previous Git hunk')

  map('n', '<leader>ui', '<Cmd>GoIdeHealth<CR>', 'IDE health check')
  map('n', '<leader>us', '<Cmd>GoIdeSettings<CR>', 'IDE settings')
  map('n', '<leader>uh', '<Cmd>GoIdeGuide<CR>', 'Getting-started guide')
  map('n', '<leader>ub', '<Cmd>GoIdeBreadcrumbs<CR>', 'Toggle symbol breadcrumbs')
  map('n', '<leader>un', function()
    vim.wo.relativenumber = not vim.wo.relativenumber
  end, 'Toggle relative line numbers')

  require('which-key').add({
    { '<leader>b', group = 'Buffers' }, { '<leader>c', group = 'Code' },
    { '<leader>d', group = 'Debug' }, { '<leader>f', group = 'Find' },
    { '<leader>g', group = 'Git' }, { '<leader>j', group = 'Jump history' },
    { '<leader>m', group = 'Minimap' }, { '<leader>q', group = 'Quit' },
    { '<leader>r', group = 'Run / rename' }, { '<leader>s', group = 'Search' }, { '<leader>t', group = 'Tests' },
    { '<leader>u', group = 'Preferences / help' }, { '<leader>w', group = 'Windows / save' },
    { '<leader>x', group = 'Problems' },
  })
end

return M
