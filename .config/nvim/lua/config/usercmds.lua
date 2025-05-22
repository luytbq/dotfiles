-- vim.api.nvim_create_user_command("SetTabStop",
--     function(cmd_args)
--         local tabWidth = cmd_args.args or 4
--         vim.cmd("set tabstop=" .. tabWidth)
--         vim.cmd("set softtabstop=" .. tabWidth)
--         vim.cmd("set shiftwidth=" .. tabWidth)
--     end,
--     {
--         nargs=1 -- see :h command-nargs
--     }
-- )

vim.api.nvim_create_user_command("Format",
    function()
        vim.lsp.buf.format()
    end,
    {
        nargs=0 -- see :h command-nargs
    }
)

