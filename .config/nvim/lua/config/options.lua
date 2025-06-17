-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

opt.smoothscroll = false

vim.b.autoformat = false
vim.g.autoformat = false

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.o.expandtab = false

-- vim.lsp.set_log_level(vim.log.levels.DEBUG)
