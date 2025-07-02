local map = vim.keymap.set

return {
	'nvim-telescope/telescope.nvim',
	tag = '0.1.8',
	dependencies = { 'nvim-lua/plenary.nvim', build = 'make' },
	config = function(opts)
		require('telescope').setup {
			defaults = {
				layout_strategy = 'horizontal',
				layout_config = { width = 0.95 },
			},
			pickers = {
				buffers = {
					theme = "dropdown",
					layout_config = { width = 0.95 },
				},
				marks = {
					attach_mappings = function(_, map)
						map({ "i", "n" }, "<C-d>", require("telescope.actions").delete_mark)
						return true
					end,
				},
				live_grep = {
					theme = "ivy",
				}
			},
		}

		local call_builtin_func = function(func, _opts)
			_opts = _opts or {}
			return function()
				require('telescope.builtin')[func](_opts)
			end
		end

		-- map('n', '<leader>fi', call_builtin_func('live_grep'))
		map('n', '<leader>fr', call_builtin_func('resume'))
		map('n', '<leader>fs', call_builtin_func('lsp_document_symbols'))
		map('n', '<leader>fb', call_builtin_func('buffers'))
		map('n', '<leader>fh', call_builtin_func('help_tags'))
		map('n', '<leader>ff', call_builtin_func('find_files'))
		map('n', '<leader>fm', call_builtin_func('marks'))

		require "config.telescope.multigrep".setup()
	end,
}
