return { 
  "nvim-java/nvim-java",
  ---@param opts PluginLspOpts
  config = function(_, opts)
    require('java').setup()
    require('lspconfig').jdtls.setup({})
  end,
}
