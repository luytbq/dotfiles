local map = vim.keymap.set
-- local del = vim.keymap.del

-- <C-c> also clear search highlights
map({ "n", "i", "v" }, "<c-c>", "<cmd>noh<cr><esc>")
map({ "n" }, "<leader>va", "<Esc>ggVG")

-- Execute lua code
map("n", "<leader>x", ":%lua<CR>")
map("v", "<leader>x", ":lua<CR>")

-- Quickfix navigation
X_QUICKFIX_OPENING = false
map("n", "<leader>qo", -- toggle the quickfix list window
    function()
        if not X_QUICKFIX_OPENING then
            vim.cmd("copen")
            X_QUICKFIX_OPENING = true
        else
            vim.cmd("cclose")
            X_QUICKFIX_OPENING = false
        end
    end)
map("n", "[q", "<cmd>cprev<CR>")
map("n", "]q", "<cmd>cnext<CR>")

-- change paste behavior: keep register after overwrite text
map({ "v" }, "p", "pgvy")

map("n", "<A-j>", ":m .+1<CR>==")     -- move line up(n)
map("n", "<A-k>", ":m .-2<CR>==")     -- move line down(n)
map("v", "<A-j>", ":m '>+1<CR>gv=gv") -- move line up(v)
map("v", "<A-k>", ":m '<-2<CR>gv=gv") -- move line down(v)

-- Tab navigation
map({ "n", "v" }, "[t", "<cmd>tabprev<CR>")
map({ "n", "v" }, "]t", "<cmd>tabnext<CR>")

map({ "i", "t" }, "<esc><esc>", "<c-\\><c-n>")
map({ "i", "t" }, "<c-\\><c-\\>", "<c-\\><c-n>")

map({ "n", "i", "v" }, "<leader>ft", "<cmd>FloatTerm<cr>", { desc = "Open/Next Floating Terminal" })
map({ "n", "i", "v", "t" }, "<c-/>", "<cmd>FloatTerm<cr>", { desc = "Open/Next Floating Terminal" })
map({ "n", "i", "v", "t" }, "<c-_>", "<cmd>FloatTerm<cr>", { desc = "Open/Next Floating Terminal" })
map({ "n" }, "]\\", "<cmd>FloatTermNext<cr>", { desc = "Next Floating Terminal" })
map({ "n" }, "[\\", "<cmd>FloatTermPrev<cr>", { desc = "Previous Floating Terminal" })
map({ "n" }, "<leader>tn", "<cmd>FloatTermNew<cr>", { desc = "New Floating Terminal Buffer" })
map({ "n" }, "<leader>td", "<cmd>FloatTermDel<cr>", { desc = "Delete Current Floating Terminal Buffer" })
map({ "v" }, "<c-/>", "<cmd>FloatTermVisual<cr>", { desc = "Send selected text to Floating Terminal" })
map({ "v" }, "<c-_>", "<cmd>FloatTermVisual<cr>", { desc = "Send selected text to Floating Terminal" })

map({ "n", "v" }, "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>", { desc = "LSP buffer code action" })

vim.schedule(function()
  map({ "n", "v" }, "<leader>cp", "<cmd>CopyPathAbsolute<cr>", { desc = "Copy Path Absolute" })
  map("n", "<leader>cP", "<cmd>CopyPathAbsolute with-line-number<cr>", { desc = "Copy Path Absolute with line number" })
  -- Use ':' (not <Cmd>) in visual mode so the '<,'> range is passed to the command
  map("v", "<leader>cP", ":CopyPathAbsolute with-line-number<cr>", { desc = "Copy Path Absolute with line number" })
end)


-- Treesitter incremental selection (the `main` branch dropped the built-in module)
local ts_inc = require("config/ts-incremental")
map("n", "<C-space>", ts_inc.init, { desc = "TS: init selection" })
map("x", "<C-space>", ts_inc.increment, { desc = "TS: increment selection" })
map("x", "<bs>", ts_inc.decrement, { desc = "TS: decrement selection" })

require("config/usercmds")
require("config/luasnip")
