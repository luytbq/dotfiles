return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  opts = {},
  config = function(_, opts)
    require("render-markdown").setup(opts)
    vim.api.nvim_create_user_command("MarkdownRender", function(args)
      if args.args == "toggle" then
        require("render-markdown").toggle()
      end
    end, { nargs = 1 })
  end,
}
