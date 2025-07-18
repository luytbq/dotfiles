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
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = { "*.go", "*.lua" },
    callback = function()
        vim.lsp.buf.format()
    end,
})
