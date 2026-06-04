-- Treesitter incremental selection.
--
-- The nvim-treesitter `main` branch removed the built-in `incremental_selection`
-- module, so reimplement the old behaviour with the core `vim.treesitter` API:
--   <C-space> (normal)  -> select the node under the cursor
--   <C-space> (visual)  -> grow selection to the parent node
--   <bs>      (visual)  -> shrink back to the previous node
--
-- Per-buffer stack of selected nodes so growing/shrinking is stateful.
local M = {}

---@type table<integer, TSNode[]>
local stacks = {}

local function range_eq(a, b)
    local ar1, ac1, ar2, ac2 = a:range()
    local br1, bc1, br2, bc2 = b:range()
    return ar1 == br1 and ac1 == bc1 and ar2 == br2 and ac2 == bc2
end

---Select `node`'s range as a charwise visual selection.
---@param node TSNode
local function select_node(node)
    local srow, scol, erow, ecol = node:range() -- 0-indexed; end col exclusive

    -- Convert the exclusive end column into an inclusive cursor position.
    if ecol > 0 then
        ecol = ecol - 1
    else
        erow = erow - 1
        ecol = math.max(vim.fn.col({ erow + 1, "$" }) - 2, 0)
    end

    -- Drop any current visual mode first, otherwise `normal! v` would toggle it off.
    if vim.fn.mode():match("[vV\22]") then
        vim.cmd("silent! normal! \27") -- <Esc>
    end

    vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
    vim.cmd("normal! v")
    vim.api.nvim_win_set_cursor(0, { erow + 1, ecol })
end

function M.init()
    local buf = vim.api.nvim_get_current_buf()
    local ok, node = pcall(vim.treesitter.get_node)
    if not ok or not node then
        return
    end
    stacks[buf] = { node }
    select_node(node)
end

function M.increment()
    local buf = vim.api.nvim_get_current_buf()
    local stack = stacks[buf]
    if not stack or #stack == 0 then
        return M.init()
    end

    local node = stack[#stack]
    local parent = node:parent()
    -- Skip parents that cover the exact same range (no visible growth).
    while parent and range_eq(parent, node) do
        parent = parent:parent()
    end

    if parent then
        stack[#stack + 1] = parent
        select_node(parent)
    else
        select_node(node) -- already at the root; keep current selection
    end
end

function M.decrement()
    local buf = vim.api.nvim_get_current_buf()
    local stack = stacks[buf]
    if not stack or #stack == 0 then
        return
    end
    if #stack > 1 then
        stack[#stack] = nil
    end
    select_node(stack[#stack])
end

return M
