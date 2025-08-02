-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

opt.smoothscroll = false

vim.b.autoformat = false
vim.g.autoformat = false
vim.g.editorconfig = false

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.o.expandtab = true

-- vim.lsp.set_log_level(vim.log.levels.DEBUG)

local utils = require("config.utils")

-- Load editor state from file
-- local state_file = vim.fn.stdpath("data") .. "/editor_config.json"
local project_config = utils.get_project_config()
if project_config then
    if project_config.wrap ~= nil then
        opt.wrap = project_config.wrap
    end

    if project_config.tabstop ~= nil then
        opt.tabstop = project_config.tabstop
        opt.softtabstop = project_config.tabstop
        opt.shiftwidth = project_config.tabstop
    end
end
