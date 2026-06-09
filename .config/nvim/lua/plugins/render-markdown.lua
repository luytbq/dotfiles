return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  opts = {},
  config = function(_, opts)
    require("render-markdown").setup(opts)
    vim.api.nvim_create_user_command("ToggleMarkdownRender", function(args)
        require("render-markdown").toggle()
    end, { nargs = 1 })
  end,
}
