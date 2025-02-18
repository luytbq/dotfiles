local map = vim.keymap.set

return {
  "nvim-telescope/telescope.nvim",

  -- ff, fg were handled by lazyvim
  map('n', '<leader>fi', "<cmd>Telescope live_grep<cr>", { desc = 'Telescope live grep' }),
  map('v', '<leader>fi', '"gy<cmd>Telescope live_grep<cr><C-r>g', { desc = 'Telescope live grep' }),
  map('n', '<leader>fs', "<cmd>Telescope resume<cr>", { desc = 'Telescope resume' }),
  map('n', '<leader>fb', "<cmd>Telescope buffers<cr>", { desc = 'Telescope buffers' }),
  map('n', '<leader>fh', "<cmd>Telescope help_tags<cr>", { desc = 'Telescope help tags' }),
}
