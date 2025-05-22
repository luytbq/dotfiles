
return {
	"L3MON4D3/LuaSnip",
	opts = function()
		---@diagnostic disable-next-line: duplicate-set-field
		LazyVim.cmp.actions.snippet_forward = function()
			if require("luasnip").jumpable(1) then
				vim.schedule(function()
					require("luasnip").jump(1)
				end)
				return true
			end
		end
		---@diagnostic disable-next-line: duplicate-set-field
		LazyVim.cmp.actions.snippet_stop = function()
			if require("luasnip").expand_or_jumpable() then -- or just jumpable(1) is fine?
				require("luasnip").unlink_current()
				return true
			end
		end
	end,
	config = function(opts)
		-- https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#config-options
		require"luasnip".setup({
			history = true,
			update_events = {"TextChanged", "TextChangedI"}
		})
	end,
}
