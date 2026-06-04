-- nvim-treesitter is on the `main` branch (the rewrite). LazyVim core already
-- drives it correctly in lua/lazyvim/plugins/treesitter.lua: it sets
-- branch="main", runs TS.setup, installs parsers, and registers the FileType
-- autocmd that calls vim.treesitter.start for highlight / indent / folds.
--
-- This file used to carry the OLD master-branch spec (highlight={enable=true},
-- a custom `config` calling TS.setup with module opts, etc.). On `main` that
-- config replaced LazyVim's working one but did nothing — so highlighting fell
-- back to legacy regex syntax and broke on regex-heavy files.
--
-- Keep this override minimal: only add languages LazyVim's default list omits.
-- Highlight, indent, folds and the textobjects `move` keymaps (]f ]c ]a …) all
-- come from LazyVim. Incremental selection (<C-space>/<bs>) was removed from the
-- `main` branch and is reimplemented in lua/config/ts-incremental.lua.
return {
    "nvim-treesitter/nvim-treesitter",
    opts = {
        -- opts_extend = { "ensure_installed" } (set by LazyVim) makes this a
        -- list-append, not a replace.
        ensure_installed = {
            "go",
            "java",
        },
    },
}
