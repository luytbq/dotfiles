---@return string
local get_visual_selected = function()
	local restore_reg = vim.fn.getreg('v')
	vim.cmd('normal! "vy')
	local selected_text = vim.fn.getreg('v')
	vim.fn.setreg('v', restore_reg)
	return selected_text
end

return {
    -- "folke/snacks.nvim",
    "snacks.nvim",
    ---@type snacks.Config
    keys = {
        { "<leader>ff", function() Snacks.picker.smart() end, desc = "Smart Find Files", },
        { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
        { "<leader>fi", mode = "n", function() Snacks.picker.grep() end, desc = "Grep" },
        { "<leader>fi", mode = "v", function()
            Snacks.picker.grep({ search = get_visual_selected() })
            end,
            desc = "Grep Visual Selection",
        },
    },
    opts = {
        dashboard = {
            preset = {
                pick = function(cmd, opts)
                return LazyVim.pick(cmd, opts)()
                end,
                header = [[

,---,---,---,---,---,---,---,---,---,---,---,---,---,-------,
|1/2| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 | + | ' | <-    |
|---'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-----|
| ->| | Q | W | E | R | T | Y | U | I | O | P | ] | ^ |     |
|-----',--',--',--',--',--',--',--',--',--',--',--',--'|    |
| Caps | A | S | D | F | G | H | J | K | L | \ | [ | * |    |
|----,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'-,-'---'----|
|    | < | Z | X | C | V | B | N | M | , | . | - |          |
|----'-,-',--'--,'---'---'---'---'---'---'-,-'---',--,------|
| ctrl |  | alt |                          |altgr |  | ctrl |
'------'  '-----'--------------------------'------'  '------'


Hello, World!


        ]],
                -- stylua: ignore
                ---@type snacks.dashboard.Item[]
                keys = {
                { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
                { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
                { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
                { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
                { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
                { icon = " ", key = "s", desc = "Restore Session", section = "session" },
                { icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
                { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
                { icon = " ", key = "q", desc = "Quit", action = ":qa" },
                },
            },
            },
        picker = {
            win = {
                input = {
                    keys = {
                        ["<c-j>"] = false,
                        ["<c-k>"] = false,
                    },
                },
                list = {
                    keys = {
                        ["<c-j>"] = false,
                        ["<c-k>"] = false,
                    },
                },
            },
        },

    },
}
