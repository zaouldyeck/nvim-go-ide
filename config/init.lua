-- A complete Go IDE, isolated with NVIM_APPNAME=nvim-go.
-- Personal preferences live in lua/go_ide/settings.lua.
if vim.fn.has('nvim-0.11') ~= 1 then
  error('nvim-go needs Neovim 0.11+. Start it with the bundled nvim-go launcher.')
end
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
require('go_ide.options')
require('go_ide.theme').setup()
require('go_ide.lazy')
require('go_ide.terminal').setup()
require('go_ide.go').setup()
require('go_ide.keymaps').setup()
require('go_ide.ui').setup()
