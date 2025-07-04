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
