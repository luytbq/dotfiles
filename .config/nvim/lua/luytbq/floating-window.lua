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
	-- -- Trim each line
	-- for i, line in ipairs(selected_text) do
	-- 	selected_text[i] = vim.trim(line)
	-- end
	return selected_text
end


--- @class plugin.float_terminal.buf
--- @field buf integer Buffer
--- @field name string Buffer name
---
--- @class plugin.float_terminal.state
--- @field bufs plugin.float_terminal.buf[]
--- @field win integer
---
--- @class plugin.float_terminal.open_floating_window
--- @field win_opts? vim.api.keyset.win_config
--- @field buf integer Buffer
--- @field put_text? string[] Text to append to buffer
---

---@type plugin.float_terminal.state
local state = {
	bufs = {},
	win = -1,
}

---@param newest_buf plugin.float_terminal.buf
local reorder_state_bufs = function(newest_buf)
	if #state.bufs == 0 then
		return
	end
	local bufs = {}
	if vim.api.nvim_buf_is_valid(newest_buf.buf) then
		table.insert(bufs, newest_buf)
	end
	for _, buf in ipairs(state.bufs) do
		if buf.buf ~= newest_buf.buf and vim.api.nvim_buf_is_valid(buf.buf) then
			table.insert(bufs, buf)
		end
	end
	state.bufs = bufs
end

---@param args plugin.float_terminal.open_floating_window
local open_floating_window = function(args)
	if args == nil or not vim.api.nvim_buf_is_valid(args.buf) then
		print("invalid args: " .. vim.inspect(args))
		return
	end

	args.win_opts = args.win_opts or {}

	local win_width = args.win_opts.width or math.floor(vim.o.columns * 0.8)
	local win_height = args.win_opts.height or math.floor(vim.o.lines * 0.8)
	local win_start_col = math.floor((vim.o.columns - win_width) / 2)
	local win_start_row = math.floor((vim.o.lines - win_height) / 2)

	---@type vim.api.keyset.win_config
	local win_config = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = win_start_row,
		col = win_start_col,
		border = "rounded"
	}


	state.win = vim.api.nvim_open_win(args.buf, true, win_config)
	if vim.bo[args.buf].buftype ~= 'terminal' then
		vim.cmd.terminal()
	end

	-- TODO: make this works: get selected text and pass to terminal
	if args.put_text ~= nil and #args.put_text > 0 then
		vim.fn.chansend(vim.bo[args.buf].channel, args.put_text)
	end
end

local input_new_session = function()
	vim.ui.input({ prompt = "Enter session name: " }, function(name)
		if name == nil or name == "" then
			return
		end

		local buf = vim.api.nvim_create_buf(false, true)
		local bbuf = { buf = buf, name = name }
		table.insert(state.bufs, bbuf)
		open_floating_window({ buf = buf })
		reorder_state_bufs(bbuf)
	end)
end

vim.api.nvim_create_user_command("FloatTerm",
	---@param _ vim.api.keyset.create_user_command.command_args not used
	function(_)
		if vim.api.nvim_win_is_valid(state.win) then
			vim.api.nvim_win_close(state.win, true)
			return
		end

		state.win = -1

		if #state.bufs < 1 then
			input_new_session()
			return
		end

		local choices = {}
		for _, v in ipairs(state.bufs) do
			table.insert(choices, {
				buf = v.buf,
				name = v.name or "no name",
			})
		end
		table.insert(choices, { buf = -1, name = "Create new session ..." })

		vim.ui.select(choices, {
			prompt = "Select a session or create a new one",
			format_item = function(item)
				return item.name
			end
		}, function(choice)
			print('choice ' .. vim.inspect(choice))
			if choice == nil then
				return
			elseif choice.buf == -1 then
				input_new_session()
			else
				reorder_state_bufs(choice)
				open_floating_window({ buf = choice.buf })
			end
		end)
	end,
	{
		range = true
	}
)
