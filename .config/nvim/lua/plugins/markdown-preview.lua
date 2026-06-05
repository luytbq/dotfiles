return {
  -- LazyVim's markdown extra binds <leader>cp -> MarkdownPreviewToggle on the
  -- iamcco plugin with ft = "markdown", shadowing the global CopyPathAbsolute
  -- map inside markdown buffers. Disable it here so <leader>cp stays consistent.
  {
    "iamcco/markdown-preview.nvim",
    keys = {
      -- Must match the original id, which includes ft, to actually disable it.
      { "<leader>cp", false, ft = "markdown" },
    },
  },
  {
    "selimacerbas/markdown-preview.nvim",
    dependencies = { "selimacerbas/live-server.nvim" },
    config = function()
      require("markdown_preview").setup({
        -- all optional; sane defaults shown
        port = 8421,
        open_browser = true,
        debounce_ms = 300,
      })
    end,
  },
}
