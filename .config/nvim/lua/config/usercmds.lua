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

        -- Save the state to a JSON file
        local state_file = vim.fn.stdpath("data") .. "/editor_state.json"

        -- Read existing state file
        local state = {}
        local existing_file = io.open(state_file, "r")
        if existing_file then
            local content = existing_file:read("*all")
            existing_file:close()
            local ok, existing_state = pcall(vim.fn.json_decode, content)
            if ok and existing_state then
                state = existing_state
            end
        end

        -- Update tabstop state
        state.tabstop = tabWidth

        -- Write updated state back to file
        local json_str = vim.fn.json_encode(state)
        local file = io.open(state_file, "w")
        if file then
            file:write(json_str)
            file:close()
        end
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

        -- Save the state to a JSON file
        local state_file = vim.fn.stdpath("data") .. "/editor_state.json"

        -- Read existing state file
        local state = {}
        local existing_file = io.open(state_file, "r")
        if existing_file then
            local content = existing_file:read("*all")
            existing_file:close()
            local ok, existing_state = pcall(vim.fn.json_decode, content)
            if ok and existing_state then
                state = existing_state
            end
        end

        -- Update wrap state
        state.wrap = not current_wrap

        -- Write updated state back to file
        local json_str = vim.fn.json_encode(state)
        local file = io.open(state_file, "w")
        if file then
            file:write(json_str)
            file:close()
        end
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
