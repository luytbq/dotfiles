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

-- Load editor state from file
local state_file = vim.fn.stdpath("data") .. "/editor_state.json"
local file = io.open(state_file, "r")
if file then
  local content = file:read("*all")
  file:close()

  -- Parse JSON and set states
  local ok, state = pcall(vim.fn.json_decode, content)
  if ok and state then
    -- Set wrap state if exists
    if state.wrap ~= nil then
      opt.wrap = state.wrap
    end

    -- Set tabstop state if exists
    if state.tabstop ~= nil then
      opt.tabstop = state.tabstop
      opt.softtabstop = state.tabstop
      opt.shiftwidth = state.tabstop
    end
  end

end
