return {
    {
        "yetone/avante.nvim",
        event = "VeryLazy",
        version = false, -- Never set this value to "*"! Never!
        mode = "legacy",
        opts = {
            provider = "openai",
            providers = {
                openai = {
                    endpoint = "https://api.openai.com/v1",
                    model = "gpt-4o", -- your desired model (or use gpt-4o, etc.)
                    timeout = 30000,  -- Timeout in milliseconds, increase this for reasoning models
                    extra_request_body = {
                        temperature = 0,
                        max_completion_tokens = 8192, -- Increase this to include reasoning tokens (for reasoning models)
                        -- reasoning_effort = "medium",  -- low|medium|high, only used for reasoning models
                    },
                },
                ollama = {
                    -- model = "qwq:32b",
                    -- model = "llama3.2:latest",
                    model = "devstral:latest",
                },
            },
            rag_service = {
                enabled = false,                     -- Enables the RAG service
                host_mount = os.getenv("HOME"),      -- Host mount path for the rag service
                provider = "openai",                 -- The provider to use for RAG service (e.g. openai or ollama)
                llm_model = "",                      -- The LLM model to use for RAG service
                embed_model = "",                    -- The embedding model to use for RAG service
                endpoint = "http://localhost:11434", -- The API endpoint for RAG service
            },
            vendors = {

            }
        },
        -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
        build = "make",
        -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "stevearc/dressing.nvim",
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            --- The below dependencies are optional,
            "echasnovski/mini.pick",         -- for file_selector provider mini.pick
            "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
            "hrsh7th/nvim-cmp",              -- autocompletion for avante commands and mentions
            "ibhagwan/fzf-lua",              -- for file_selector provider fzf
            "nvim-tree/nvim-web-devicons",   -- or echasnovski/mini.icons
            "zbirenbaum/copilot.lua",        -- for providers='copilot'
            {
                -- support for image pasting
                "HakonHarnes/img-clip.nvim",
                event = "VeryLazy",
                opts = {
                    -- recommended settings
                    default = {
                        embed_image_as_base64 = false,
                        prompt_for_file_name = false,
                        drag_and_drop = {
                            insert_mode = true,
                        },
                        -- required for Windows users
                        use_absolute_path = true,
                    },
                },
            },
            {
                -- Make sure to set this up properly if you have lazy=true
                'MeanderingProgrammer/render-markdown.nvim',
                opts = {
                    file_types = { "markdown", "Avante" },
                },
                ft = { "markdown", "Avante" },
            },
        },
    },

    {
        "CopilotC-Nvim/CopilotChat.nvim",
        -- https://github.com/CopilotC-Nvim/CopilotChat.nvim?tab=readme-ov-file
        dependencies = {
            { "github/copilot.vim" },                       -- or zbirenbaum/copilot.lua
            { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
        },
        build = "make tiktoken",
        opts = function()
            return {

                system_prompt = 'COPILOT_INSTRUCTIONS', -- System prompt to use (can be specified manually in prompt via /).

                model = 'gpt-4.1',                      -- Default model to use, see ':CopilotChatModels' for available models (can be specified manually in prompt via $).
                tools = nil,                            -- Default tool or array of tools (or groups) to share with LLM (can be specified manually in prompt via @).
                sticky = nil,                           -- Default sticky prompt or array of sticky prompts to use at start of every new chat (can be specified manually in prompt via >).

                resource_processing = false,            -- Enable intelligent resource processing (skips unnecessary resources to save tokens)

                temperature = 0.1,                      -- Result temperature
                headless = false,                       -- Do not write to chat buffer and use history (useful for using custom processing)
                callback = nil,                         -- Function called when full response is received
                remember_as_sticky = true,              -- Remember config as sticky prompts when asking questions

                -- default selection
                -- see select.lua for implementation
                selection = require('CopilotChat.select').visual,

                -- default window options
                window = {
                    layout = 'vertical',    -- 'vertical', 'horizontal', 'float', 'replace', or a function that returns the layout
                    width = 0.5,            -- fractional width of parent, or absolute width in columns when > 1
                    height = 0.5,           -- fractional height of parent, or absolute height in rows when > 1
                    -- Options below only apply to floating windows
                    relative = 'editor',    -- 'editor', 'win', 'cursor', 'mouse'
                    border = 'single',      -- 'none', single', 'double', 'rounded', 'solid', 'shadow'
                    row = nil,              -- row position of the window, default is centered
                    col = nil,              -- column position of the window, default is centered
                    title = 'Copilot Chat', -- title of chat window
                    footer = nil,           -- footer of chat window
                    zindex = 1,             -- determines if window is on top or below other floating windows
                },

                show_help = true,                 -- Shows help message as virtual lines when waiting for user input
                show_folds = true,                -- Shows folds for sections in chat
                highlight_selection = true,       -- Highlight selection
                highlight_headers = true,         -- Highlight headers in chat, disable if using markdown renderers (like render-markdown.nvim)
                auto_follow_cursor = true,        -- Auto-follow cursor in chat
                auto_insert_mode = false,         -- Automatically enter insert mode when opening window and on new prompt
                insert_at_end = false,            -- Move cursor to end of buffer when inserting text
                clear_chat_on_new_prompt = false, -- Clears chat on every new prompt

                -- Static config starts here (can be configured only via setup function)

                debug = false,                                                   -- Enable debug logging (same as 'log_level = 'debug')
                log_level = 'info',                                              -- Log level to use, 'trace', 'debug', 'info', 'warn', 'error', 'fatal'
                proxy = nil,                                                     -- [protocol://]host[:port] Use this proxy
                allow_insecure = false,                                          -- Allow insecure server connections

                chat_autocomplete = true,                                        -- Enable chat autocompletion (when disabled, requires manual `mappings.complete` trigger)

                log_path = vim.fn.stdpath('state') .. '/CopilotChat.log',        -- Default path to log file
                history_path = vim.fn.stdpath('data') .. '/copilotchat_history', -- Default path to stored history

                headers = {
                    user = '## User ',         -- Header to use for user questions
                    assistant = '## Copilot ', -- Header to use for AI answers
                    tool = '## Tool ',         -- Header to use for tool calls
                },

                separator = '───', -- Separator to use in chat

                -- default providers
                -- see config/providers.lua for implementation
                providers = require('CopilotChat.config.providers'),

                -- default functions
                -- see config/functions.lua for implementation
                functions = require('CopilotChat.config.functions'),

                -- default prompts
                -- see config/prompts.lua for implementation
                prompts = require('CopilotChat.config.prompts'),

                -- default mappings
                -- see config/mappings.lua for implementation
                mappings = require('CopilotChat.config.mappings'),
            }
        end,
    }
}
