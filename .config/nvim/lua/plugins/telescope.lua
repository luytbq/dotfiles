local map = vim.keymap.set

return {
  'nvim-telescope/telescope.nvim', tag = '0.1.8',
  dependencies = { 'nvim-lua/plenary.nvim', build = 'make' },
  config = function(opts)
    require('telescope').setup{
      pickers = {
        find_files = {
          theme = "ivy"
        },
        -- live_grep = {
        --   theme = "ivy"
        -- }
      },
    }

    map('v', '<leader>fi', '"gy<cmd>Telescope live_grep<cr><C-r>g', { desc = 'Telescope live grep' })
    map('n', '<leader>fs', "<cmd>Telescope resume<cr>", { desc = 'Telescope resume' })
    map('n', '<leader>fb', "<cmd>Telescope buffers<cr>", { desc = 'Telescope buffers' })
    map('n', '<leader>fh', "<cmd>Telescope help_tags<cr>", { desc = 'Telescope help tags' })
    map('n', '<leader>fi', function()
      require('telescope.builtin').live_grep(){}
    end)
    map('n', '<leader>ff', function()
      require('telescope.builtin').find_files{}
    end)
    map('n', '<leader>fv', function()
      require('telescope.builtin').find_files{
        cwd = vim.fn.stdpath'config'
      }
    end)
    map('n', '<leader>fp', function()
      require('telescope.builtin').find_files{
        ---@diagnostic disable-next-line: param-type-mismatch
        cwd = vim.fs.joinpath(vim.fn.stdpath('data'), 'lazy')
      }
    end)

    require "config.telescope.multigrep".setup()
  end,
}
