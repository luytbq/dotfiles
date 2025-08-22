local utils = require("config.utils")

vim.api.nvim_create_user_command("SetTabStop",
    function(cmd_args)
        -- Toggle between 2 and 4 if no args provided
        local current_tabstop = vim.o.tabstop
        local tabWidth = tonumber(cmd_args.args)

        if not tabWidth then
            tabWidth = current_tabstop == 2 and 4 or 2
        end

        -- Update tab settings
        vim.cmd("set tabstop=" .. tabWidth)
        vim.cmd("set softtabstop=" .. tabWidth)
        vim.cmd("set shiftwidth=" .. tabWidth)

        -- Save the config
        utils.save_project_config({ tabstop = tabWidth })
    end,
    {
        nargs = "?" -- Optional argument
    }
)

-- ToggleWrap command to toggle line wrapping with state persistence
vim.api.nvim_create_user_command("ToggleWrap",
    function()
        -- Toggle the wrap state
        local current_wrap = vim.wo.wrap
        vim.wo.wrap = not current_wrap

        -- Save the config
        utils.save_project_config({ wrap = current_wrap })
    end,
    { nargs = 0 }
)

vim.api.nvim_create_user_command("Format",
    function()
        vim.lsp.buf.format()
    end,
    {
        nargs = 0 -- see :h command-nargs
    }
)

vim.api.nvim_create_user_command("EditorConfig",
    function()
        -- Find .editorconfig in cwd or parent
        local editorconfig_path = vim.fn.findfile(".editorconfig", ".;")
        if editorconfig_path == "" then
            return
        end

        -- Run sed to update or add the setting
        -- Replace line if exists
        local sed_cmd = string.format([[
			if grep -q '^\s*trim_trailing_whitespace\s*=' %s; then
				sed -i 's/^\s*trim_trailing_whitespace\s*=.*/trim_trailing_whitespace = false/' %s
			fi
		]], editorconfig_path, editorconfig_path)

        vim.fn.system({ "bash", "-c", sed_cmd })
    end,
    { nargs = 0 }
)

-- command to run maven test for the current buffer using "mvn test -Dtest=TestClassName"
vim.api.nvim_create_user_command("MavenTest",
    function()
        local file_path = vim.fn.expand("%:p")
        local file_name = vim.fn.expand("%:t:r") -- Get the file name without extension
        local cmd = "mvn test -Dtest=" .. file_name
        -- Run the command
        vim.cmd("!" .. cmd)
    end,
    { nargs = 0 }
)

vim.api.nvim_create_user_command('CopyPath', function()
    vim.fn.setreg('+', vim.fn.expand('%:p'))
end, {})

vim.api.nvim_create_user_command('CopyPathRelative', function()
    vim.fn.setreg('+', vim.fn.expand('%'))
end, {})
