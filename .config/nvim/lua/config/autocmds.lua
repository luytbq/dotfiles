-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- disable auto format
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "*.java", "*.ts", "*.js", "*.vue", "*.html" },
  callback = function()
    vim.b.autoformat = false
  end,
})

-- before writing buffer, remove all trailing spaces
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
    local save_cursor = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, save_cursor)
  end,
})

-- before writing buffer with specified pattern, re-indent it
-- vim.api.nvim_create_autocmd("BufWritePre", {
--     pattern = { "*.go", "*.lua" },
--     callback = function()
--         vim.lsp.buf.format()
--     end,
-- })
--

-- CopilotChat Auto-command to customize chat buffer behavior
vim.api.nvim_create_autocmd('BufEnter', {
  pattern = 'copilot-*',
  callback = function()
    vim.opt_local.relativenumber = false
    vim.opt_local.number = false
    vim.opt_local.conceallevel = 0
  end,
})

-- Snacks diff: highlight rõ dòng thêm/xóa
-- Phải gọi trực tiếp vì ColorScheme event đã fire trước khi file này load (VeryLazy).
-- Snacks dùng `default = true` nên chỉ set nếu group chưa tồn tại — gọi sớm để giữ giá trị của mình.
local function set_snacks_diff_hl()
  vim.api.nvim_set_hl(0, "SnacksDiffAdd",          { fg = "#9be9a8", bg = "#1f3a2a" })
  vim.api.nvim_set_hl(0, "SnacksDiffDelete",       { fg = "#ffb3b3", bg = "#3a1f1f" })
  vim.api.nvim_set_hl(0, "SnacksDiffAddLineNr",    { fg = "#9be9a8", bg = "#1f3a2a" })
  vim.api.nvim_set_hl(0, "SnacksDiffDeleteLineNr", { fg = "#ffb3b3", bg = "#3a1f1f" })
end
set_snacks_diff_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_snacks_diff_hl })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.conceallevel = 2
    vim.opt_local.concealcursor = 'i'
    vim.diagnostic.enable(false)
  end,
})
