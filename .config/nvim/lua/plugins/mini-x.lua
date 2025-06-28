return {
	{
		"echasnovski/mini.pairs",
		event = "VeryLazy",
		opts = {
			modes = { insert = true, command = false, terminal = false },
		},
		config = function(_, opts)
			LazyVim.mini.pairs(opts)
		end,
	},
}
