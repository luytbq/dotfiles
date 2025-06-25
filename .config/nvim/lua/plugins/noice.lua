return {
	"folke/noice.nvim",
	opts = {
		presets = {
			lsp_doc_border = true,
		},
		routes = {
			{
				filter = {
					event = "lsp",
					kind = "progress",
					cond = function(message)
						local client = vim.tbl_get(message.opts, "progress", "client")
						if client ~= "jdtls" then
							return false
						end

						local content = vim.tbl_get(message.opts, "progress", "message")
						if content == nil then
							return false
						end

						return string.find(content, "Validate") or string.find(content, "Publish")
					end,
				},
				opts = { skip = true },
			},
		},
	},
}
