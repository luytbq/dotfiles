return {
  "mfussenegger/nvim-jdtls",
  dependencies = { "folke/which-key.nvim" },
  ft = { "java" },
  opts = function()
    return {
      jdtls_config_system = function()
        ---@diagnostic disable-next-line: undefined-field
        local system = vim.loop.os_uname().sysname
        if system == "Darwin" then
          return "config_mac"
        else
          return "config_linux"
        end
      end,
    }
  end,
  config = function(_, opts)
    local jdtls_path = vim.fn.stdpath("data") .. "/mason/packages/jdtls"
    local config_dir = jdtls_path .. "/" .. opts.jdtls_config_system()
    local launcher_jar = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_1.7.0.v20250519-0528.jar")

    local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
    local workspace_dir = vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/workspace"

    vim.lsp.config("jdtls", {
      cmd = {
        "java",
        "-Declipse.application=org.eclipse.jdt.ls.core.id1",
        "-Dosgi.bundles.defaultStartLevel=4",
        "-Declipse.product=org.eclipse.jdt.ls.core.product",
        "-Dlog.protocol=true",
        "-Dlog.level=ALL",
        "-Xms1g",
        "-Xmx4g",
        "-XX:+UseParallelGC",
        "-XX:GCTimeRatio=4",
        "-XX:AdaptiveSizePolicyWeight=90",
        "--add-modules=ALL-SYSTEM",
        "--add-opens",
        "java.base/java.util=ALL-UNNAMED",
        "--add-opens",
        "java.base/java.lang=ALL-UNNAMED",

        "-jar",
        launcher_jar,
        "-configuration",
        config_dir,
        "-data",
        workspace_dir,
      },
      settings = {
        java = {
          -- your custom settings
        },
      },
    })
    vim.lsp.enable("jdtls")
  end,
}
