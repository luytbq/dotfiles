-- lua/config/utils.lua
local m = {}

m.get_all_projects_config = function()
  local state_file = vim.fn.stdpath("data") .. "/editor_config.json"
  local existing_file = io.open(state_file, "r")
  local all_projects = {}

  if existing_file then
    local file_content = existing_file:read("*all")
    existing_file:close()
    local ok, all_projects_json = pcall(vim.fn.json_decode, file_content)
    if ok and all_projects_json then
      all_projects = all_projects_json
    end
  end

  return all_projects
end

m.get_project_config = function()
  local cwd = vim.loop.cwd()
  local config = {}

  local all_projects = m.get_all_projects_config()
  if all_projects[cwd] then
    config = all_projects[cwd]
  else
    -- If no config exists for the current project, create a default one
    config = {
      tabstop = 2,
      wrap = false
    }
  end
  return config
end

m.save_project_config = function(config)
  local cwd = vim.loop.cwd()
  local state_file = vim.fn.stdpath("data") .. "/editor_config.json"
  local all_projects = m.get_all_projects_config()

  local current_config = all_projects[cwd] or {}

  -- Merge the new config with the existing one
  for key, value in pairs(config) do
    current_config[key] = value
  end
  -- Update the project config
  all_projects[cwd] = current_config

  -- Write the updated config back to the file
  local json_str = vim.fn.json_encode(all_projects)
  local file = io.open(state_file, "w")
  if file then
    file:write(json_str)
    file:close()
  end
end


return m
