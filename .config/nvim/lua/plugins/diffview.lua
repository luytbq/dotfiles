return {
  lazy = false,
  "sindrets/diffview.nvim",
  
  opts = {
    -- change merge_tool's layout
    view = {
      x = {
        layout = "diff4_horizontal",
      },
    },
  },

  keys = {
    { "<leader>dv", group = "Diff view" },
    { "<leader>dvo", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open", mode = "n" },
    { "<leader>dvw", "<cmd>DiffviewOpen -- %<cr>", desc = "Diffview Open current file change", mode = "n" },
    { "<leader>dvc", "<cmd>DiffviewClose<cr>", desc = "Diffview Close", mode = "n" },
    { "<leader>dvf", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview File History", mode = "n" },
    { "<leader>dvr", "<cmd>DiffviewRefresh<cr>", desc = "Diffview Refresh", mode = "n" },

    -- print usage
    { "<leader>dvh", function()
      print([[Source: https://github.com/sindrets/diffview.nvim?tab=readme-ov-file#Usage

Usage:
 :DiffviewOpen
 :DiffviewOpen HEAD~2
 :DiffviewOpen HEAD~4..HEAD~2
 :DiffviewOpen d4a7b0d
 :DiffviewOpen d4a7b0d^!
 :DiffviewOpen d4a7b0d..519b30e
 :DiffviewOpen origin/main...HEAD

 :DiffviewOpen HEAD~2 -- lua/diffview plugin
 :DiffviewClose: Close the current diffview. You can also use :tabclose.
 :DiffviewToggleFiles: Toggle the file panel.
 :DiffviewFocusFiles: Bring focus to the file panel.
 :DiffviewRefresh

 :DiffviewFileHistory
 :DiffviewFileHistory %
 :DiffviewFileHistory path/to/some/file.txt
 :DiffviewFileHistory path/to/some/directory
 :DiffviewFileHistory include/this and/this :!but/not/this
 :DiffviewFileHistory --range=origin..HEAD
 :DiffviewFileHistory --range=feat/example-branch
 :'<,'>DiffviewFileHistory]])
    end, desc = "DiffView Print Usage", mode = "n" },
  }
}
