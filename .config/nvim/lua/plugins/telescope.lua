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

    local call_builtin_func = function(func, _opts)
      _opts = _opts or {}
      return function ()
        require('telescope.builtin')[func](_opts)
      end
    end

    map('n', '<leader>fi', call_builtin_func('live_grep'))
    map('n', '<leader>fs', call_builtin_func('resume'))
    map('n', '<leader>fb', call_builtin_func('buffers'))
    map('n', '<leader>fh', call_builtin_func('help_tags'))

    map('v', '<leader>fi', function()
      vim.cmd('normal! "vy')
      local text = vim.fn.getreg('v')
      call_builtin_func('live_grep', {
        default_text = text
      })()
    end, { noremap = true, silent = true })

    map('n', '<leader>ff', call_builtin_func('find_files'))

    require "config.telescope.multigrep".setup()
  end,
}
