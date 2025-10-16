return {
    {
        "mfussenegger/nvim-dap",
        recommended = true,
        desc = "Debugging support. Requires language specific adapters to be configured. (see lang extras)",

        dependencies = {
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio",
            {
                "mason-org/mason.nvim",
                opts = { ensure_installed = { "java-debug-adapter", "java-test" } },
            },
            -- virtual text for the debugger
            {
                "theHamsta/nvim-dap-virtual-text",
                opts = {},
            },
            {
                "mason-org/mason.nvim",
                opts = { ensure_installed = { "java-debug-adapter", "java-test" } },
            },
        },

        -- stylua: ignore
        keys = {
            { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, desc = "Breakpoint Condition" },
            { "<leader>db", function() require("dap").toggle_breakpoint() end,                                    desc = "Toggle Breakpoint" },
            { "<leader>dc", function() require("dap").continue() end,                                             desc = "Run/Continue" },
            { "<leader>da", function() require("dap").continue({ before = get_args }) end,                        desc = "Run with Args" },
            { "<leader>dC", function() require("dap").run_to_cursor() end,                                        desc = "Run to Cursor" },
            { "<leader>dg", function() require("dap").goto_() end,                                                desc = "Go to Line (No Execute)" },
            { "<leader>di", function() require("dap").step_into() end,                                            desc = "Step Into" },
            { "<leader>dj", function() require("dap").down() end,                                                 desc = "Down" },
            { "<leader>dk", function() require("dap").up() end,                                                   desc = "Up" },
            { "<leader>dl", function() require("dap").run_last() end,                                             desc = "Run Last" },
            { "<leader>do", function() require("dap").step_out() end,                                             desc = "Step Out" },
            { "<leader>dO", function() require("dap").step_over() end,                                            desc = "Step Over" },
            { "<leader>dP", function() require("dap").pause() end,                                                desc = "Pause" },
            { "<leader>dr", function() require("dap").repl.toggle() end,                                          desc = "Toggle REPL" },
            { "<leader>ds", function() require("dap").session() end,                                              desc = "Session" },
            { "<leader>dt", function() require("dap").terminate() end,                                            desc = "Terminate" },
            { "<leader>dw", function() require("dap.ui.widgets").hover() end,                                     desc = "Widgets" },
        },

        opts = function()
            -- Simple configuration to attach to remote java debug process
            -- Taken directly from https://github.com/mfussenegger/nvim-dap/wiki/Java
            local dap = require("dap")
            -- local mason_path = vim.fn.stdpath("data") .. "/mason/packages/java-debug-adapter"
            -- local jar_patterns = {
            --     mason_path .. "/extension/server/com.microsoft.java.debug.plugin-*.jar",
            -- }
            -- local jar = vim.fn.glob(jar_patterns[1])
            local home = os.getenv("HOME")
            local mason_path = home .. "/.local/share/nvim/mason/packages/java-debug-adapter"
            local jar_path = mason_path .. "/extension/server/com.microsoft.java.debug.plugin-0.53.2.jar"

            dap.adapters.java = {
                type = 'executable',
                command = 'java',
                args = {
                    '-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005',
                    '-jar',
                    mason_path .. '/extension/server/com.microsoft.java.debug.plugin-0.53.2.jar',
                },
            }

            dap.configurations.java = {
                {
                    type = "java",
                    request = "launch",
                    name = "Launch file",
                    program = "${file}",
                },
                {
                    type = "java",
                    request = "attach",
                    name = "Attach to remote",
                    hostName = "127.0.0.1",
                    port = 5005,
                },
                {
                    type = 'java',
                    request = 'launch',
                    name = 'Launch Java Program',
                    mainClass = 'vn.onepay.wsp.Main', -- change to your class
                    projectName = 'myproject',
                }
            }
        end,

        config = function()
            require "dapui".setup()

            vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })

            for name, sign in pairs(LazyVim.config.icons.dap) do
                sign = type(sign) == "table" and sign or { sign }
                vim.fn.sign_define(
                    "Dap" .. name,
                    { text = sign[1], texthl = sign[2] or "DiagnosticInfo", linehl = sign[3], numhl = sign[3] }
                )
            end

            -- setup dap config by VsCode launch.json file
            local vscode = require("dap.ext.vscode")
            local json = require("plenary.json")
            vscode.json_decode = function(str)
                return vim.json.decode(json.json_strip_comments(str))
            end

            vim.api.nvim_create_user_command("DapOpen",
                function(cmd_args)
                    require "dapui".open()
                end,
                { desc = "DAP UI open" }
            )

            vim.api.nvim_create_user_command("DapClose",
                function(cmd_args)
                    require "dapui".close()
                end,
                { desc = "DAP UI close" }
            )
        end,
    }
}
