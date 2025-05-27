---@diagnostic disable: unused-function, unused-local

---@param args vim.api.keyset.create_user_command.command_args
---@return string[]
local get_selected_text = function(args)
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
--- @field win_opts? vim.api.keyset.win_config
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

local clean_state_buffers = function()
	---@type plugin.float_terminal.buf[]
	local buffers = {}
	for _, v in ipairs(state.buffers) do
		if vim.api.nvim_buf_is_valid(v.id) then
			table.insert(buffers, v)
		end
	end
	state.buffers = buffers
end

---@param first table
---@param second table
---@return table
local merge_table = function(first, second)
	for k, v in pairs(second) do first[k] = v end
	return first
end

---@return plugin.float_terminal.buf
local create_new_buffer = function()
	local len = #state.buffers
	local buffer = { id = vim.api.nvim_create_buf(false, true), name = '#' .. (len + 1) }
	table.insert(state.buffers, buffer)
	clean_state_buffers()
	return buffer
end

---@return plugin.float_terminal.buf|nil
local get_prev_buffer = function()
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
local get_next_buffer = function()
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
local is_win_open = function()
	return state.window_open and vim.api.nvim_win_is_valid(state.window.id)
end

---@param buffer plugin.float_terminal.buf
local set_buffer = function(buffer)
	state.curr_buffer = buffer
	vim.api.nvim_win_set_buf(state.window.id, buffer.id)
	vim.api.nvim_win_set_config(state.window.id, { title = state.curr_buffer.name })
end

---@param args plugin.float_terminal.open_floating_window
local open_floating_term = function(args)
	clean_state_buffers()
	if args == nil or args.buffer == nil or not vim.api.nvim_buf_is_valid(args.buffer.id) then
		print("invalid args: " .. vim.inspect(args))
		return
	end

	state.curr_buffer = args.buffer

	args.win_opts = args.win_opts or {}
	local win_width = args.win_opts.width or math.floor(vim.o.columns * 0.8)
	local win_height = args.win_opts.height or math.floor(vim.o.lines * 0.8)
	local win_start_col = math.floor((vim.o.columns - win_width) / 2)
	local win_start_row = math.floor((vim.o.lines - win_height) / 2)

	---@type vim.api.keyset.win_config
	local win_config = {
		title = state.curr_buffer.name,
		relative = "editor",
		width = win_width,
		height = win_height,
		row = win_start_row,
		col = win_start_col,
		border = "rounded"
	}

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

local close_floating_term = function()
	vim.api.nvim_win_close(state.window.id, true)
	state.window_open = false
end

---@param args plugin.float_terminal.open_floating_window|nil
local new_floating_term = function(args)
	args = args or {}
	local buffer = create_new_buffer()
	open_floating_term(merge_table(args, { buffer = buffer }))
end

---@param args plugin.float_terminal.open_floating_window|nil
local open_current_buf = function(args)
	args = args or {}
	open_floating_term(merge_table(args, { buffer = state.curr_buffer }))
end

local prev_floating_term = function()
	local buffer = get_prev_buffer()
	if buffer ~= nil and vim.api.nvim_buf_is_valid(buffer.id) then
		open_floating_term({ buffer = buffer })
	end
end

local next_floating_term = function()
	local buffer = get_next_buffer()
	if buffer ~= nil and vim.api.nvim_buf_is_valid(buffer.id) then
		open_floating_term({ buffer = buffer })
	end
end

vim.api.nvim_create_user_command("FloatTermClose", close_floating_term, {})
vim.api.nvim_create_user_command("FloatTermNew", new_floating_term, {})
vim.api.nvim_create_user_command("FloatTermNext", next_floating_term, {})
vim.api.nvim_create_user_command("FloatTermPrev", prev_floating_term, {})
vim.api.nvim_create_user_command("FloatTermVisual", function(args)
	local selected_text = get_selected_text(args)
	if #state.buffers < 1 then
		new_floating_term({ put_text = selected_text })
	elseif is_win_open() then
		print("Not supported")
		return
	else
		open_current_buf({ put_text = selected_text })
	end
end, { range = true, nargs = "*" })

vim.api.nvim_create_user_command("FloatTerm",
	---@param _ vim.api.keyset.create_user_command.command_args not used
	function(_)
		if #state.buffers < 1 then
			new_floating_term()
		elseif is_win_open() then
			close_floating_term()
		else
			open_current_buf()
		end
	end,
	{
		range = true
	}
)
