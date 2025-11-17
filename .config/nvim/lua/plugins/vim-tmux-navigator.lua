return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
    "TmuxNavigatorProcessList",
  },
  keys = {
    { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
    { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
    { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
    { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
    { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
    { "<c-h>", "<cmd>TmuxNavigateLeft<cr>" , mode = "v" },
    { "<c-j>", "<cmd>TmuxNavigateDown<cr>" , mode = "v" },
    { "<c-k>", "<cmd>TmuxNavigateUp<cr>" , mode = "v" },
    { "<c-l>", "<cmd>TmuxNavigateRight<cr>" , mode = "v"},
  },
}
