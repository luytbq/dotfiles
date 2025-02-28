-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

opt.smoothscroll = false
opt.wrap = false

vim.opt_local.wrap = true
vim.b.autoformat = false
vim.g.autoformat = false
vim.o.tabstop = 4
vim.o.shiftwidth = 4
