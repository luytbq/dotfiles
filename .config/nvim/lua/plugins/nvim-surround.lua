return {
  "echasnovski/mini.surround",
  keys = function(_, keys)
    -- Populate the keys based on the user's options
    local opts = LazyVim.opts("mini.surround")
    local mappings = {
      { opts.mappings.add, desc = "Add Surrounding", mode = { "n", "v" } },
      { opts.mappings.delete, desc = "Delete Surrounding" },
      { opts.mappings.find, desc = "Find Right Surrounding" },
      { opts.mappings.find_left, desc = "Find Left Surrounding" },
      { opts.mappings.highlight, desc = "Highlight Surrounding" },
      { opts.mappings.replace, desc = "Replace Surrounding" },
      { opts.mappings.update_n_lines, desc = "Update `MiniSurround.config.n_lines`" },
    }
    mappings = vim.tbl_filter(function(m)
      return m[1] and #m[1] > 0
    end, mappings)
    return vim.list_extend(mappings, keys)
  end,
  opts = {
    mappings = {
      add = "gsa", -- Add surrounding in Normal and Visual modes
      delete = "gsd", -- Delete surrounding
      find = "gsf", -- Find surrounding (to the right)
      find_left = "gsF", -- Find surrounding (to the left)
      highlight = "gsh", -- Highlight surrounding
      replace = "gsr", -- Replace surrounding
      update_n_lines = "gsn", -- Update `n_lines`
    },
  },
}

-- return {
--     -- NOTE : Trying out Mini surrond 
--     {
--        "kylechui/nvim-surround",
--         enabled = false,
--         event = { 'BufReadPre', "BufNewFile" },
--         version = "*", -- Use for stability; omit to use `main` branch for the latest features
--         config = true,
--     },
--     --
--     -- HACK; The Key Commands -> for help run ;h nvim-surround.usage
--     --
--     --     Old text                    Command         New text
--     -- --------------------------------------------------------------------------------
--     --     surr*ound_words             ysiw)           (surround_words)
--     --     *make strings               ys$"            "make strings"
--     --     [delete ar*ound me!]        ds]             delete around me!
--     --     remove <b>HTML t*ags</b>    dst             remove HTML tags
--     --     'change quot*es'            cs'"            "change quotes"
--     --     <b>or tag* types</b>        csth1<CR>       <h1>or tag types</h1>
--     --     delete(functi*on calls)     dsf             function calls
--     --
-- }
