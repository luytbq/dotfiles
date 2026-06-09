local utils = require("config.utils")

vim.api.nvim_create_user_command("SetTabStop",
    function(cmd_args)
        -- Toggle between 2 and 4 if no args provided
        local current_tabstop = vim.o.tabstop
        local tabWidth = tonumber(cmd_args.args)

        if not tabWidth then
            tabWidth = current_tabstop == 2 and 4 or 2
        end

        -- Update tab settings
        vim.cmd("set tabstop=" .. tabWidth)
        vim.cmd("set softtabstop=" .. tabWidth)
        vim.cmd("set shiftwidth=" .. tabWidth)

        -- Save the config
        utils.save_project_config({ tabstop = tabWidth })
    end,
    {
        nargs = "?" -- Optional argument
    }
)

-- ToggleWrap command to toggle line wrapping with state persistence
vim.api.nvim_create_user_command("ToggleWrap",
    function()
        -- Toggle the wrap state
        local current_wrap = vim.wo.wrap
        vim.wo.wrap = not current_wrap

        -- Save the config
        utils.save_project_config({ wrap = current_wrap })
    end,
    { nargs = 0 }
)

vim.api.nvim_create_user_command("Format",
    function()
        vim.lsp.buf.format()
    end,
    {
        nargs = 0 -- see :h command-nargs
    }
)

vim.api.nvim_create_user_command("EditorConfig",
    function()
        -- Find .editorconfig in cwd or parent
        local editorconfig_path = vim.fn.findfile(".editorconfig", ".;")
        if editorconfig_path == "" then
            return
        end

        -- Run sed to update or add the setting
        -- Replace line if exists
        local sed_cmd = string.format([[
			if grep -q '^\s*trim_trailing_whitespace\s*=' %s; then
				sed -i 's/^\s*trim_trailing_whitespace\s*=.*/trim_trailing_whitespace = false/' %s
			fi
		]], editorconfig_path, editorconfig_path)

        vim.fn.system({ "bash", "-c", sed_cmd })
    end,
    { nargs = 0 }
)

-- command to run maven test for the current buffer using "mvn test -Dtest=TestClassName"
vim.api.nvim_create_user_command("MavenTest",
    function()
        local file_path = vim.fn.expand("%:p")
        local file_name = vim.fn.expand("%:t:r") -- Get the file name without extension
        local cmd = "mvn test -Dtest=" .. file_name
        -- Run the command
        vim.cmd("!" .. cmd)
    end,
    { nargs = 0 }
)

local function copy_path(path, cmd_args)
    local result
    if cmd_args.args == 'with-line-number' then
        if cmd_args.line1 == cmd_args.line2 then
            result = path .. ':' .. cmd_args.line1
        else
            result = path .. ':' .. cmd_args.line1 .. '-' .. cmd_args.line2
        end
    else
        result = path
    end
    vim.fn.setreg('+', result)
    vim.notify('Copied: ' .. result, vim.log.levels.INFO)
end

local line_number_complete = function() return { 'with-line-number' } end

vim.api.nvim_create_user_command('CopyPath', function(cmd_args)
    copy_path(vim.fn.expand('%:.'), cmd_args)
end, { range = true, nargs = '?', complete = line_number_complete })

vim.api.nvim_create_user_command('CopyPathAbsolute', function(cmd_args)
    copy_path(vim.fn.expand('%:p'), cmd_args)
end, { range = true, nargs = '?', complete = line_number_complete })

vim.api.nvim_create_user_command("JdtlsClean", function()
  -- find the jdtls client explicitly
  local jdtls_client
  for _, client in pairs(vim.lsp.get_active_clients()) do
    if client.name == "jdtls" then
      jdtls_client = client
      break
    end
  end

  if not jdtls_client then
    -- print("No active jdtls client")
    -- if no active jdtls client, try to find default data path:
    -- ~/.cache/nvim/jdtls/{project_name}/workspace where project_name is the name of the current working directory
    -- then prompt to delete that

    local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
    local workspace_dir = vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/workspace"
    local confirm = vim.fn.confirm(
      "Delete jdtls workspace?\n" .. workspace_dir,
      "&Yes\n&No",
      2
    )
    if confirm == 1 then
      vim.fn.system({ "rm", "-rf", workspace_dir })
      print("Deleted " .. workspace_dir)

    -- restart jdtls by automaticaly running :LspRestart
    vim.defer_fn(function()
        vim.cmd("LspRestart")
        print("Jdtls restarting...")
    end, 500)

    else
      print("Cancelled")
    end
    return
  end

  local cmd = jdtls_client.config.cmd or {}
  for i, v in ipairs(cmd) do
    if v == "-data" and cmd[i + 1] then
      local path = cmd[i + 1]
      local confirm = vim.fn.confirm(
        "Delete jdtls workspace?\n" .. path,
        "&Yes\n&No",
        2
      )
      if confirm == 1 then
        vim.fn.system({ "rm", "-rf", path })
        print("Deleted " .. path)

        -- stop only jdtls
        jdtls_client.stop()

        -- reattach (LazyVim auto-triggers on buffer)
        vim.defer_fn(function()
          vim.cmd("edit") -- reopen current buffer to trigger LSP attach
          print("Jdtls restarting...")
        end, 500)
      else
        print("Cancelled")
      end
      return
    end
  end

  print("No -data found in jdtls command")
end, {})

-- Toggle AI suggestions:
--   1. copilot.vim   (ghost text from github/copilot.vim)
--   2. copilot.lua   (suggestion engine from zbirenbaum/copilot.lua, via LazyVim extra)
--   3. copilot-cmp   (cmp source from zbirenbaum/copilot-cmp, via LazyVim extra)
vim.g.ai_suggestions_enabled = true
vim.api.nvim_create_user_command("ToggleAI", function()
    vim.g.ai_suggestions_enabled = not vim.g.ai_suggestions_enabled
    if vim.g.ai_suggestions_enabled then
        -- 1. copilot.vim
        vim.g.copilot_enabled = true
        vim.cmd("silent! Copilot enable")

        -- 2. copilot.lua (zbirenbaum)
        local ok_suggestion, suggestion = pcall(require, "copilot.suggestion")
        if ok_suggestion then
            require("copilot.command").enable()
        end

        -- 3. copilot-cmp source
        local ok_cmp, cmp = pcall(require, "cmp")
        if ok_cmp then
            local sources = cmp.get_config().sources or {}
            local has_copilot = false
            for _, s in ipairs(sources) do
                if s.name == "copilot" then has_copilot = true break end
            end
            if not has_copilot then
                table.insert(sources, 1, { name = "copilot", group_index = 1, priority = 100 })
                cmp.setup({ sources = sources })
            end
        end

        print("AI suggestions: ON")
    else
        -- 1. copilot.vim
        vim.g.copilot_enabled = false
        vim.cmd("silent! Copilot disable")
        vim.cmd("silent! call copilot#Clear()")

        -- 2. copilot.lua (zbirenbaum)
        local ok_suggestion, suggestion = pcall(require, "copilot.suggestion")
        if ok_suggestion then
            suggestion.dismiss()
            require("copilot.command").disable()
        end

        -- 3. copilot-cmp source
        local ok_cmp, cmp = pcall(require, "cmp")
        if ok_cmp then
            local sources = cmp.get_config().sources or {}
            local filtered = {}
            for _, s in ipairs(sources) do
                if s.name ~= "copilot" then table.insert(filtered, s) end
            end
            cmp.setup({ sources = filtered })
        end

        print("AI suggestions: OFF")
    end
end, { nargs = 0 })

vim.api.nvim_create_user_command('ToggleSpelling', function()
    vim.opt_local.spell = not vim.opt_local.spell:get()
    local state = vim.opt_local.spell:get() and "enabled" or "disabled"
    vim.notify("Spelling " .. state .. " [" .. vim.opt_local.spelllang:get()[1] .. "]", vim.log.levels.INFO)
end, { nargs = 0 })

vim.api.nvim_create_user_command('SetSpelllang', function(cmd_args)
    local lang = cmd_args.args
    vim.opt_local.spelllang = lang
    vim.opt_local.spell = true
    vim.notify("Spelllang set to: " .. lang, vim.log.levels.INFO)
end, {
    nargs = 1,
    complete = function()
        return { "en", "vi", "en,vi" }
    end,
})

vim.api.nvim_create_user_command('ToggleDiagnostic', function()
    if vim.diagnostic.is_enabled() then
        vim.diagnostic.enable(false)
        vim.notify("Diagnostics disabled", vim.log.levels.INFO)
    else
        vim.diagnostic.enable()
        vim.notify("Diagnostics enabled", vim.log.levels.INFO)
    end
end, { nargs = 0 })

-- format json
vim.api.nvim_create_user_command('JsonFormat', function()
  vim.cmd("'<,'>!jq")
end, { range = true })
vim.api.nvim_create_user_command('JsonMinify', function()
    vim.cmd("'<,'>!jq --compact-output")
end, { range = true })

