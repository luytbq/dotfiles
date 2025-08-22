local M = {}

--- Get visually selected text as lines
---@return string[]
local function get_selected_text()
    local restore_reg = vim.fn.getreg('v')
    vim.cmd('normal! "vy')
    local selected_text = vim.fn.getreg('v', true)
    vim.fn.setreg('v', restore_reg)
    if type(selected_text) == "string" then
        return vim.split(vim.trim(selected_text), "\n")
    else
        return selected_text
    end
end

--- @class plugin.float_terminal.buf
--- @field id integer buffer id
--- @field name? string buffer name
---
--- @class plugin.float_terminal.win
--- @field id integer window id
--- @field name? string window name
---
--- @class plugin.float_terminal.state
--- @field buffers plugin.float_terminal.buf[]
--- @field curr_buffer plugin.float_terminal.buf
--- @field window plugin.float_terminal.win
--- @field window_open boolean
---
--- @class plugin.float_terminal.open_floating_window
--- @field buffer? plugin.float_terminal.buf
--- @field put_text? string[] Text to append to buffer
---

---@type plugin.float_terminal.state
local state = {
    buffers = {},
    curr_buffer = { id = -1 },
    window = { id = -1 },
    window_open = false,
}

-- Utility
local function clean_state_buffers()
    ---@type plugin.float_terminal.buf[]
    local buffers = {}
    for i, v in ipairs(state.buffers) do
        if vim.api.nvim_buf_is_valid(v.id) then
            v.name = "#" .. i
            table.insert(buffers, v)
        end
    end
    state.buffers = buffers
end

---@param first table
---@param second table
---@return table
local function merge_table(first, second)
    for k, v in pairs(second) do first[k] = v end
    return first
end

-- Buffer management
---@return plugin.float_terminal.buf
local function create_new_buffer()
    clean_state_buffers()
    local len = #state.buffers
    ---@type plugin.float_terminal.buf
    local buffer = {
        id = vim.api.nvim_create_buf(false, true),
        name = "#" .. (len + 1)
    }
    table.insert(state.buffers, buffer)
    return buffer
end

---@return plugin.float_terminal.buf|nil
local function get_prev_buffer()
    clean_state_buffers()
    if #state.buffers == 0 then return nil end
    if #state.buffers == 1 then return state.buffers[1] end
    local last_idx = -1
    for idx, buf in ipairs(state.buffers) do
        if buf.id == state.curr_buffer.id then last_idx = idx end
    end
    if last_idx == 1 then
        return state.buffers[#state.buffers]
    else
        return state.buffers[last_idx - 1]
    end
end

---@return plugin.float_terminal.buf|nil
local function get_next_buffer()
    clean_state_buffers()
    if #state.buffers == 0 then return nil end
    if #state.buffers == 1 then return state.buffers[1] end
    local last_idx = -1
    for idx, buf in ipairs(state.buffers) do
        if buf.id == state.curr_buffer.id then last_idx = idx end
    end
    if last_idx == #state.buffers then
        return state.buffers[1]
    else
        return state.buffers[last_idx + 1]
    end
end

---@return boolean
local function is_win_open()
    return state.window_open and vim.api.nvim_win_is_valid(state.window.id)
end

---@return string
local function get_title()
    return '=============== ' .. state.curr_buffer.name .. ' / ' .. #state.buffers .. ' ==============='
end

---@param buffer plugin.float_terminal.buf
local function set_buffer(buffer)
    state.curr_buffer = buffer
    vim.api.nvim_win_set_buf(state.window.id, buffer.id)
    vim.api.nvim_win_set_config(state.window.id, { title = get_title() })
end

---@return vim.api.keyset.win_config
local function calculate_win_config()
    local win_width = math.floor(vim.o.columns * 0.8)
    local win_height = math.floor(vim.o.lines * 0.8)
    local win_start_col = math.floor((vim.o.columns - win_width) / 2)
    local win_start_row = math.floor((vim.o.lines - win_height) / 2)
    return {
        title = get_title(),
        title_pos = 'center',
        relative = "editor",
        width = win_width,
        height = win_height,
        row = win_start_row,
        col = win_start_col,
        border = "rounded"
    }
end

---@param args plugin.float_terminal.open_floating_window
local function open_floating_term(args)
    if args == nil or args.buffer == nil or not vim.api.nvim_buf_is_valid(args.buffer.id) then
        print("invalid args: " .. vim.inspect(args))
        return
    end
    state.curr_buffer = args.buffer
    local win_config = calculate_win_config()
    if is_win_open() then
        set_buffer(state.curr_buffer)
    elseif not vim.api.nvim_win_is_valid(state.window.id) then
        state.window.id = vim.api.nvim_open_win(state.curr_buffer.id, true, win_config)
    end
    if vim.bo[state.curr_buffer.id].buftype ~= 'terminal' then
        vim.cmd.terminal()
    end
    if args.put_text ~= nil and #args.put_text > 0 then
        vim.fn.chansend(vim.bo[state.curr_buffer.id].channel, args.put_text)
    end
    state.window_open = true
end

local function close_floating_term()
    vim.api.nvim_win_close(state.window.id, true)
    state.window_open = false
end

---@param args plugin.float_terminal.open_floating_window|nil
local function new_floating_term(args)
    args = args or {}
    local buffer = create_new_buffer()
    open_floating_term(merge_table(args, { buffer = buffer }))
end

---@param args plugin.float_terminal.open_floating_window|nil
local function open_current_buf(args)
    args = args or {}
    if not vim.api.nvim_buf_is_valid(state.curr_buffer.id) then
        new_floating_term(args)
    else
        open_floating_term(merge_table(args, { buffer = state.curr_buffer }))
        clean_state_buffers()
    end
end

local function prev_floating_term()
    local buffer = get_prev_buffer()
    if buffer ~= nil and vim.api.nvim_buf_is_valid(buffer.id) then
        open_floating_term({ buffer = buffer })
    end
end

local function next_floating_term()
    local buffer = get_next_buffer()
    if buffer ~= nil and vim.api.nvim_buf_is_valid(buffer.id) then
        open_floating_term({ buffer = buffer })
    end
end

vim.api.nvim_create_user_command("FloatTermClose", close_floating_term, {})
vim.api.nvim_create_user_command("FloatTermNew", new_floating_term, {})
vim.api.nvim_create_user_command("FloatTermNext", next_floating_term, {})
vim.api.nvim_create_user_command("FloatTermPrev", prev_floating_term, {})
vim.api.nvim_create_user_command("FloatTermVisual", function()
    local selected_text = get_selected_text()
    if #state.buffers < 1 then
        new_floating_term({ put_text = selected_text })
    elseif is_win_open() then
        print("Not supported")
        return
    else
        open_current_buf({ put_text = selected_text })
    end
end, { range = true, nargs = "*" })

vim.api.nvim_create_user_command("FloatTerm", function()
    if #state.buffers < 1 then
        new_floating_term()
    elseif is_win_open() then
        close_floating_term()
    else
        open_current_buf()
    end
end, { range = true })

vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("float-term-resized", { clear = true }),
    callback = function()
        local win_config = calculate_win_config()
        if vim.api.nvim_win_is_valid(state.window.id) then
            vim.api.nvim_win_set_config(state.window.id, win_config)
        end
    end
})

return M
