local path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
local revision = '306a05526ada86a7b30af95c5cc81ffba93fef97'
if not (vim.uv or vim.loop).fs_stat(path) then
  if vim.env.NVIM_GO_CHECK_ONLY == '1' then
    error('Plugin manager is missing. Run bash install.sh to complete installation.')
  end
  local out = vim.fn.system({ 'git', 'clone', '--filter=blob:none', 'https://github.com/folke/lazy.nvim.git', path })
  if vim.v.shell_error ~= 0 then error('Cannot download lazy.nvim. Check network and git.\n' .. out) end
  out = vim.fn.system({ 'git', '-C', path, 'checkout', revision })
  if vim.v.shell_error ~= 0 then error('Cannot check out the pinned plugin manager.\n' .. out) end
end
vim.opt.rtp:prepend(path)
require('lazy').setup({
  spec = { { import = 'plugins.ui' }, { import = 'plugins.go' } },
  defaults = { lazy = true },
  lockfile = vim.fn.stdpath('config') .. '/lazy-lock.json',
  install = { missing = vim.env.NVIM_GO_CHECK_ONLY ~= '1' },
  checker = { enabled = false },
  change_detection = { enabled = true, notify = false },
  rocks = { enabled = false },
  ui = { border = 'rounded' },
  performance = { rtp = { disabled_plugins = { 'netrwPlugin', 'tohtml' } } },
})
