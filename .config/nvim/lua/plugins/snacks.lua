return {
    "folke/snacks.nvim",
    ---@type snacks.Config
    keys = {
        { "<leader>ff", function() Snacks.picker.smart() end, desc = "Smart Find Files", },
        { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
        { "<leader>fi", function() Snacks.picker.grep() end, desc = "Grep" },
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
