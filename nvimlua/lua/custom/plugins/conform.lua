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
			-- NOTE: a couple of unused, commented-out custom Java formatters
			-- (google_java_format_aosp / java_format_custom) used to live here.
			-- They called `require("conform.util")` eagerly at spec-definition
			-- time, which crashes on a from-scratch install (conform.nvim isn't
			-- on the runtimepath yet the first time lazy.nvim parses this spec).
			-- Removed since neither was referenced by formatters_by_ft below.
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
