return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    picker = {
      win = {
        input = {
          keys = {
            ["<c-j>"] = false,
            ["<c-k>"] = false
          }
        },
        list = {
          keys = {
            ["<c-j>"] = false,
            ["<c-k>"] = false
          }
        }
      },
    }
  },
}
