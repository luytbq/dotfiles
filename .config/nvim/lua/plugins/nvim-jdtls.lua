return {
	"mfussenegger/nvim-jdtls",
	dependencies = { "folke/which-key.nvim" },
	ft = { "java" },
	opts = function()
		return {
			root_dir = LazyVim.lsp.get_raw_config("jdtls").default_config.root_dir,

			project_name = function(root_dir)
				return root_dir and vim.fs.basename(root_dir)
			end,

			jdtls_workspace_dir = function(project_name)
				return vim.fn.stdpath("cache") .. "/jdtls/" .. project_name .. "/workspace"
			end,

			-- config_linux|config_mac
			jdtls_config_system = function()
				---@diagnostic disable-next-line: undefined-field
				local system = vim.loop.os_uname().sysname
				if system == 'Darwin' then
					return 'config_mac'
				else
					return 'config_linux'
				end
			end,

		}
	end,
	config = function(_, opts)
		local attach_jdtls = function()
			local fname = vim.api.nvim_buf_get_name(0)
			local root_dir = opts.root_dir(fname)
			local project_name = opts.project_name(root_dir)


			local mason_registry = require("mason-registry")
			local jdtls_pkg = mason_registry.get_package("jdtls")
			local jdtls_install_path = jdtls_pkg:get_install_path()

			local config = {
				cmd = {

					-- 💀
					'java', -- or '/path/to/java21_or_newer/bin/java'
					-- depends on if `java` is in your $PATH env variable and if it points to the right version.

					'-Declipse.application=org.eclipse.jdt.ls.core.id1',
					'-Dosgi.bundles.defaultStartLevel=4',
					'-Declipse.product=org.eclipse.jdt.ls.core.product',
					'-Dlog.protocol=true',
					'-Dlog.level=ALL',
					'-Xmx1g',
					'--add-modules=ALL-SYSTEM',
					'--add-opens', 'java.base/java.util=ALL-UNNAMED',
					'--add-opens', 'java.base/java.lang=ALL-UNNAMED',

					-- '-Xms4g',
					'-XX:+UseParallelGC',
					'-XX:GCTimeRatio=4',
					'-XX:AdaptiveSizePolicyWeight=90',
					-- '-Dsun.zip.disableMemoryMapping=true',
					-- '-Xmx4G',
					'-Xms100m',

					-- 💀
					'-jar', jdtls_install_path .. '/plugins/org.eclipse.equinox.launcher_1.7.0.v20250331-1702.jar',
					-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^                                       ^^^^^^^^^^^^^^
					-- Must point to the                                                     Change this to
					-- eclipse.jdt.ls installation                                           the actual version


					-- 💀
					-- '-configuration', '/path/to/jdtls_install_location/config_SYSTEM',
					-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^        ^^^^^^
					-- Must point to the                      Change to one of `linux`, `win` or `mac`
					-- eclipse.jdt.ls installation            Depending on your system.
					'-configuration', jdtls_install_path .. '/' .. opts.jdtls_config_system(),

					-- 💀
					-- See `data directory configuration` section in the README
					'-data', opts.jdtls_workspace_dir(project_name)
				},

			}

			-- Existing server will be reused if the root_dir matches.
			require("jdtls").start_or_attach(config)
		end

		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "java" },
			callback = attach_jdtls,
		})

		-- Avoid race condition by calling attach the first time, since the autocmd won't fire.
		attach_jdtls()
	end,
}
