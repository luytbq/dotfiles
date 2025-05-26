---@diagnostic disable: unused-function, unused-local

--
-- TODO: remove invalid buf from state.bufs
--

---comment
---@return string[]
local get_selected_text = function()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	print('start_post ' .. vim.inspect(start_pos))
	print('end_post ' .. vim.inspect(end_pos))

	local start_line = start_pos[2] - 1
	local start_col = start_pos[3] - 1
	local end_line = end_pos[2] - 1
	local end_col = end_pos[3]

	print('start_line ' .. vim.inspect(start_line))
	print('start_col ' .. vim.inspect(start_col))
	print('end_line ' .. vim.inspect(end_line))
	print('end_col ' .. vim.inspect(end_col))
	if start_line == 0 or end_line == 0 then
		return {}
	end

	local selected_text = vim.api.nvim_buf_get_text(0, start_line, start_col, end_line, end_col, {})
	return selected_text
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
--- @field buffer plugin.float_terminal.buf
--- @field put_text? string[] Text to append to buffer
---

---@type plugin.float_terminal.state
local state = {
	buffers = {},
	curr_buffer = { id = -1 },
	window = { id = -1 },
	window_open = false,
}

---@return plugin.float_terminal.buf
local create_new_buffer = function()
	local len = #state.buffers
	local buffer = { id = vim.api.nvim_create_buf(false, true), name = '#' .. (len + 1) }
	table.insert(state.buffers, buffer)
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

	-- TODO: make this works: get selected text and pass to terminal
	if args.put_text ~= nil and #args.put_text > 0 then
		vim.fn.chansend(vim.bo[args.buffer].channel, args.put_text)
	end

	if is_win_open() then
		set_buffer(state.curr_buffer)
	elseif not vim.api.nvim_win_is_valid(state.window.id) then
		state.window.id = vim.api.nvim_open_win(state.curr_buffer.id, true, win_config)
	end
	if vim.bo[state.curr_buffer.id].buftype ~= 'terminal' then
		vim.cmd.terminal()
	end
	state.window_open = true
end

local close_floating_term = function()
	vim.api.nvim_win_close(state.window.id, true)
	state.window_open = false
end

local new_floating_term = function()
	local buffer = create_new_buffer()
	open_floating_term({ buffer = buffer })
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

local open_current_buf = function()
	open_floating_term({ buffer = state.curr_buffer })
end

vim.api.nvim_create_user_command("FloatTermClose", close_floating_term, {})
vim.api.nvim_create_user_command("FloatTermNew", new_floating_term, {})
vim.api.nvim_create_user_command("FloatTermNext", next_floating_term, {})
vim.api.nvim_create_user_command("FloatTermPrev", prev_floating_term, {})

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
