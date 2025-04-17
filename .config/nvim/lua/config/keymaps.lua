local map = vim.keymap.set
-- local del = vim.keymap.del

-- <C-c> also clear search highlights
map({ "n", "i", "v" }, "<c-c>", "<cmd>noh<cr><esc>")
map({ "n" }, "<leader>va", "<Esc>ggVG")

-- Execute lua code
map("n", "<space>x", ":.lua<CR>")
map("v", "<space>x", ":lua<CR>")

-- Quickfix navigation
X_QUICKFIX_OPENING = false
map("n", "<space>1o", -- toggle the quickfix list window
  function()
  if not X_QUICKFIX_OPENING then
    vim.cmd("copen")
    X_QUICKFIX_OPENING = true
  else
    vim.cmd("cclose")
    X_QUICKFIX_OPENING = false
  end
end)
map("n", "<space>11", "<cmd>cprev<CR>")
map("n", "<space>12", "<cmd>cnext<CR>")

-- Change paste behavior: keep register after overwrite text
map({ "v" }, "p", "pgvy")

map("n", "<A-j>", ":m .+1<CR>==") -- move line up(n)
map("n", "<A-k>", ":m .-2<CR>==") -- move line down(n)
map("v", "<A-j>", ":m '>+1<CR>gv=gv") -- move line up(v)
map("v", "<A-k>", ":m '<-2<CR>gv=gv") -- move line down(v)

map({"n", "v"}, "[t", "<cmd>tabprev<CR>")
map({"n", "v"}, "]t", "<cmd>tabnext<CR>")
