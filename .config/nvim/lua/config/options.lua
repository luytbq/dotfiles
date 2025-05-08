-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

opt.smoothscroll = false
opt.wrap = false

vim.opt_local.wrap = true
vim.b.autoformat = false
vim.g.autoformat = false


local map = vim.keymap.set
map("n", "<c-w><c-t>",
  function()
    vim.wo.wrap = not vim.wo.wrap
end)
map("n", "<c-w><c-t>", "<cmd>set wrap!<CR>")
