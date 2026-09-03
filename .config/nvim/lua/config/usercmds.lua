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

-- Returns the (start, end) line numbers to use, exiting visual mode if active.
-- Relies on <Cmd> mappings not leaving the current mode before the handler runs,
-- so mode()/line('v')/line('.') still reflect the pending visual selection.
local function get_line_range()
    local mode = vim.fn.mode()
    if mode == 'v' or mode == 'V' or mode == '\22' then
        local l1 = vim.fn.line('v')
        local l2 = vim.fn.line('.')
        if l1 > l2 then l1, l2 = l2, l1 end
        vim.cmd('normal! \27')
        return l1, l2
    end
    local l = vim.fn.line('.')
    return l, l
end

vim.api.nvim_create_user_command('CopyPathMenu', function()
    local l1, l2 = get_line_range()
    local line_suffix = (l1 == l2) and (':' .. l1) or (':' .. l1 .. '-' .. l2)

    local items = {
        { label = 'Copy file name',                           get = function() return vim.fn.expand('%:t') end },
        { label = 'Copy file name with line number',          get = function() return vim.fn.expand('%:t') .. line_suffix end },
        { label = 'Copy related file path',                   get = function() return vim.fn.expand('%:.') end },
        { label = 'Copy related file path with line number',  get = function() return vim.fn.expand('%:.') .. line_suffix end },
        { label = 'Copy absolute file path',                  get = function() return vim.fn.expand('%:p') end },
        { label = 'Copy absolute file path with line number', get = function() return vim.fn.expand('%:p') .. line_suffix end },
        { label = 'Copy related dir path',                    get = function() return vim.fn.expand('%:.:h') end },
        { label = 'Copy absolute dir path',                   get = function() return vim.fn.expand('%:p:h') end },
    }

    vim.ui.select(items, {
        prompt = 'Copy path',
        format_item = function(item) return item.label end,
    }, function(choice)
        if not choice then return end
        local result = choice.get()
        vim.fn.setreg('+', result)
        vim.notify('Copied: ' .. result, vim.log.levels.INFO)
    end)
end, {})

-- Default workspace used by lua/plugins/nvim-jdtls.lua when no client is running.
local function jdtls_default_workspace()
  local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
  return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/workspace"
end

local function jdtls_workspace_of(client)
  local cmd = client.config.cmd
  if type(cmd) ~= "table" then
    return nil
  end
  for i, v in ipairs(cmd) do
    if v == "-data" and cmd[i + 1] then
      return cmd[i + 1]
    end
  end
  return nil
end

-- client:stop() only asks the server to exit; deleting the workspace or starting a
-- new server while the old one is still alive races with it.
local function jdtls_when_stopped(callback)
  local waited = 0
  local timer = assert(vim.uv.new_timer())
  timer:start(0, 100, vim.schedule_wrap(function()
    waited = waited + 100
    if #vim.lsp.get_clients({ name = "jdtls" }) > 0 and waited < 5000 then
      return
    end
    timer:stop()
    timer:close()
    callback()
  end))
end

vim.api.nvim_create_user_command("JdtlsClean", function()
  local client = vim.lsp.get_clients({ name = "jdtls" })[1]
  local workspace_dir = (client and jdtls_workspace_of(client)) or jdtls_default_workspace()

  local confirm = vim.fn.confirm("Delete jdtls workspace?\n" .. workspace_dir, "&Yes\n&No", 2)
  if confirm ~= 1 then
    print("Cancelled")
    return
  end

  -- nvim-jdtls is ft=java, so the config only exists once a Java buffer has been
  -- opened; re-enabling otherwise would launch lspconfig's default jdtls instead.
  local configured = vim.lsp.is_enabled("jdtls")
  if configured then
    vim.lsp.enable("jdtls", false)
  end

  jdtls_when_stopped(function()
    vim.fn.system({ "rm", "-rf", workspace_dir })
    print("Deleted " .. workspace_dir)

    if configured then
      vim.lsp.enable("jdtls", true)
      print("Jdtls restarting...")
    else
      print("Open a Java file to start jdtls")
    end
  end)
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

-- Strip a markdown marker from a line range.
-- Visual mode: applies to the selected lines. Normal mode (no range): cursor row.
local function strip_marker(cmd_args, pattern)
    local lines = vim.api.nvim_buf_get_lines(0, cmd_args.line1 - 1, cmd_args.line2, false)
    for i, line in ipairs(lines) do
        lines[i] = line:gsub(pattern, '')
    end
    vim.api.nvim_buf_set_lines(0, cmd_args.line1 - 1, cmd_args.line2, false, lines)
end

-- Remove markdown bold markers (**):  **text** -> text
vim.api.nvim_create_user_command('RemoveBold', function(cmd_args)
    strip_marker(cmd_args, '%*%*')
end, { range = true })

-- Remove markdown inline-code markers (`):  `variableA` -> variableA
vim.api.nvim_create_user_command('RemoveCode', function(cmd_args)
    strip_marker(cmd_args, '`')
end, { range = true })

-- format json
vim.api.nvim_create_user_command('JsonFormat', function()
  vim.cmd("'<,'>!jq")
end, { range = true })
vim.api.nvim_create_user_command('JsonMinify', function()
    vim.cmd("'<,'>!jq --compact-output")
end, { range = true })

