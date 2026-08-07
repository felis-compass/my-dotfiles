return { -- Autoformat
	"stevearc/conform.nvim",
	lazy = false,
	keys = {
		{
			"<leader>f",
			function()
				require("conform").format({ async = true, lsp_fallback = true })
			end,
			mode = "",
			desc = "[F]ormat buffer",
		},
	},
	opts = {
		notify_on_error = false,
		-- format_on_save = function(bufnr)
		-- 	-- Disable "format_on_save lsp_fallback" for languages that don't
		-- 	-- have a well standardized coding style. You can add additional
		-- 	-- languages here or re-enable it for the disabled ones.
		-- 	local disable_filetypes = { c = true, cpp = true, javascript = true, typescript = true, java = true }
		-- 	return {
		-- 		timeout_ms = 500,
		-- 		lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
		-- 	}
		-- end,

		formatters = {
			-- Curretnly not used
			google_java_format_aosp = {
				command = "google-java-format",
				args = { "-", "--aosp" },
			},

			-- If maven exist then try to use spotless, else fallback to google java format
			-- Currently does not handle the case where maven exits but spotless plugin not exists
			-- Currently not used
			java_format_custom = {
				cwd = require("conform.util").root_file({ "mvnw" }),
				command = function()
					local file = io.open("./mvnw")
					if file ~= nil then
						return "./mvnw"
					end
					return "google-java-format"
				end,
				args = function(arg1, ctx)
					local file = io.open("./mvnw")
					if file ~= nil then
						return {
							"spotless:apply",
							"-DspotlessIdeHook=" .. ctx.filename,
							"-DspotlessIdeHookUseStdIn",
							"-DspotlessIdeHookUseStdOut",
							"--quiet",
						}
					end
					return {
						"-",
						"--aosp",
					}
				end,
			},
		},
		formatters_by_ft = {
			lua = { "stylua" },
			-- Conform can also run multiple formatters sequentially
			-- python = { "isort", "black" },
			--
			-- You can use a sub-list to tell conform to run *until* a formatter
			-- is found.
			html = { "prettier" },
			css = { "prettier" },
			javascript = { "prettier" },
			typescript = { "prettier" },
			java = { "spotless_maven" }, -- Turns out this will automatically fallback to lsp default formatting if not errors occurs
			-- java = { "java_format_custom" },
		},
	},
}
