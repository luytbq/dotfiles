---@diagnostic disable: unused-function, unused-local

local create_floating_window = function(opts)
  opts = opts or {}

  local width = opts.width or math.floor(vim.o.columns * 0.8)
  local height = opts.height or math.floor(vim.o.lines * 0.8)
  local start_col = math.floor((vim.o.columns - width) / 2)
  local start_row = math.floor((vim.o.lines - height) / 2)

  ---@type vim.api.keyset.win_config
  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    row = start_row,
    col = start_col,
    border = "rounded"
  }

  print('hello')

  local buf = vim.api.nvim_create_buf(false, true) -- not-listed and throw-away
  vim.api.nvim_open_win(buf, true, win_config)
end

-- vim.keymap.set({"n", "v"}, "<leader>ee", function()
--   create_floating_window()
-- end)
