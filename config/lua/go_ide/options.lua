local s = require('go_ide.settings')
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.go_ide_format_on_save = s.format_on_save
local o = vim.opt
o.termguicolors = true
o.background = 'dark'
o.number = true
o.relativenumber = s.relative_numbers
o.cursorline = true
o.signcolumn = 'yes:1'
o.mouse = 'a'
o.clipboard = 'unnamedplus'
o.wrap = false
o.scrolloff = 5
o.sidescrolloff = 8
o.splitright = true
o.splitbelow = true
o.ignorecase = true
o.smartcase = true
o.incsearch = true
o.hlsearch = true
o.inccommand = 'split'
o.updatetime = 250
o.timeoutlen = 400
o.ttimeoutlen = 10
o.completeopt = 'menu,menuone,noselect'
o.pumheight = 12
o.undofile = true
o.undolevels = 10000
o.backup = false
o.writebackup = true
o.swapfile = false
o.autoread = true
o.hidden = true
o.confirm = true
o.exrc = false
o.modeline = false
o.expandtab = true
o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4
o.smartindent = true
o.showmode = false
o.laststatus = 2
o.showtabline = s.always_show_tabs and 2 or 0
o.cmdheight = 1
o.shortmess:append('cI')
o.fillchars = { eob = ' ', fold = ' ', vert = '│', horiz = '─' }
o.list = s.show_whitespace
o.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
o.foldlevel = 99
o.foldlevelstart = 99
o.foldmethod = 'expr'
o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
o.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize' }
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'go', 'gomod', 'gowork' },
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
  end,
})
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function() vim.highlight.on_yank({ higroup = 'Visual', timeout = 140 }) end,
})
vim.api.nvim_create_autocmd({ 'FocusGained', 'TermClose', 'TermLeave' }, {
  callback = function()
    if vim.fn.getcmdwintype() == '' then vim.cmd('checktime') end
  end,
})
