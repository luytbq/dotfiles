-- better quick fix
return {
  'kevinhwang91/nvim-bqf',
	config = function(opts)
		require"bqf".setup({
      preview = {
        auto_preview = false,
      },
		})
	end,
}
