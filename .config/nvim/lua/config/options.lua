-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

opt.smoothscroll = false

vim.b.autoformat = false
vim.g.autoformat = false
vim.g.editorconfig = false

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.o.expandtab = true

-- vim.lsp.set_log_level(vim.log.levels.DEBUG)

-- Load wrap state from file
local state_file = vim.fn.stdpath("data") .. "/wrap_state.json"
local file = io.open(state_file, "r")
if file then
    local content = file:read("*all")
    file:close()

    -- Parse JSON and set wrap state
    local ok, state = pcall(vim.fn.json_decode, content)
    if ok and state and state.wrap ~= nil then
        vim.opt.wrap = state.wrap
    end
end
