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

vim.api.nvim_create_user_command('CopyPath', function()
    vim.fn.setreg('+', vim.fn.expand('%:p'))
end, {})

vim.api.nvim_create_user_command('CopyPathRelative', function()
    vim.fn.setreg('+', vim.fn.expand('%'))
end, {})

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

