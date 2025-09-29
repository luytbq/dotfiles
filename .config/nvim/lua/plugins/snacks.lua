---@return string
local get_visual_selected = function()
	local restore_reg = vim.fn.getreg('v')
	vim.cmd('normal! "vy')
	local selected_text = vim.fn.getreg('v')
	vim.fn.setreg('v', restore_reg)
	return selected_text
end

return {
    "folke/snacks.nvim",
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
