return {
	{
		"Exafunction/windsurf.nvim",
		enabled = require("config.profiles").enabled("ai_nonfree"),
		dependencies = {
			"nvim-lua/plenary.nvim",
			"hrsh7th/nvim-cmp",
		},
		config = function()
			require("codeium").setup({
				enable_cmp_source = false,
				virtual_text = {
					enabled = true,

					-- These are the defaults

					-- Set to true if you never want completions to be shown automatically.
					manual = false,
					-- A mapping of filetype to true or false, to enable virtual text.
					filetypes = {},
					-- Whether to enable virtual text of not for filetypes not specifically listed above.
					default_filetype_enabled = true,
					-- How long to wait (in ms) before requesting completions after typing stops.
					idle_delay = 75,
					-- Priority of the virtual text. This usually ensures that the completions appear on top of
					-- other plugins that also add virtual text, such as LSP inlay hints, but can be modified if
					-- desired.
					virtual_text_priority = 65535,
					-- Set to false to disable all key bindings for managing completions.
					map_keys = true,
					-- The key to press when hitting the accept keybinding but no completion is showing.
					-- Defaults to \t normally or <c-n> when a popup is showing.
					accept_fallback = nil,
					-- Key bindings for managing completions in virtual text mode.
					key_bindings = {
						-- Accept the current completion.
						accept = "<M-]>",
						-- Accept the next word.
						accept_word = "<M-[>",
						-- Accept the next line.
						accept_line = false,
						-- Clear the virtual text.
						clear = false,
						-- Cycle to the next completion.
						next = false,
						-- Cycle to the previous completion.
						prev = false,
					},
				},
			})
			vim.api.nvim_set_keymap(
				"n",
				"<leader>tC",
				':lua local virtual_text = require("codeium.config").options.virtual_text; virtual_text.manual = not virtual_text.manual<CR>',
				{ noremap = true, silent = true, desc = "Toggle Codeium virtual text" }
			)
		end,
	},
	{
		"github/copilot.vim",
		enabled = require("config.profiles").enabled("ai_nonfree"),
	},
	{
		"CopilotC-Nvim/CopilotChat.nvim",
		-- enabled = require("config.profiles").enabled("ai_nonfree"),
		enabled = true,
		dependencies = {
			{ "nvim-lua/plenary.nvim", branch = "master" },
		},
		build = "make tiktoken",
		opts = {
			-- See Configuration section for options
			keymaps = {
				{ "<leader>cc", "<cmd>CopilotChat<cr>", desc = "CopilotChat" },
				{ "<leader>cq", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat Toggle" },
				{ "<leader>cr", "<cmd>CopilotChatReview<cr>", desc = "CopilotChat Review" },
				{ "<leader>cf", "<cmd>CopilotChatFix<cr>", desc = "CopilotChat Fix" },
			},
		},
	},
	-- {
	-- 	"yetone/avante.nvim",
	-- 	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
	-- 	-- ⚠️ must add this setting! ! !
	-- 	build = vim.fn.has("win32") ~= 0
	-- 			and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
	-- 		or "make",
	-- 	event = "VeryLazy",
	-- 	version = false, -- Never set this value to "*"! Never!
	-- 	---@module 'avante'
	-- 	---@type avante.Config
	-- 	opts = {
	-- 		-- add any opts here
	-- 		-- this file can contain specific instructions for your project
	-- 		instructions_file = "CLAUDE.md",
	-- 		-- for example
	-- 		provider = "copilot",
	-- 		-- providers = {
	-- 		-- 	claude = {
	-- 		-- 		endpoint = "https://api.anthropic.com",
	-- 		-- 		model = "claude-sonnet-4-20250514",
	-- 		-- 		timeout = 30000, -- Timeout in milliseconds
	-- 		-- 		extra_request_body = {
	-- 		-- 			temperature = 0.75,
	-- 		-- 			max_tokens = 20480,
	-- 		-- 		},
	-- 		-- 	},
	-- 		-- 	moonshot = {
	-- 		-- 		endpoint = "https://api.moonshot.ai/v1",
	-- 		-- 		model = "kimi-k2-0711-preview",
	-- 		-- 		timeout = 30000, -- Timeout in milliseconds
	-- 		-- 		extra_request_body = {
	-- 		-- 			temperature = 0.75,
	-- 		-- 			max_tokens = 32768,
	-- 		-- 		},
	-- 		-- 	},
	-- 		-- },
	-- 	},
	-- 	dependencies = {
	-- 		"nvim-lua/plenary.nvim",
	-- 		"MunifTanjim/nui.nvim",
	-- 		--- The below dependencies are optional,
	-- 		"nvim-mini/mini.pick", -- for file_selector provider mini.pick
	-- 		"nvim-telescope/telescope.nvim", -- for file_selector provider telescope
	-- 		"hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
	-- 		"ibhagwan/fzf-lua", -- for file_selector provider fzf
	-- 		"stevearc/dressing.nvim", -- for input provider dressing
	-- 		"folke/snacks.nvim", -- for input provider snacks
	-- 		"nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
	-- 		-- "zbirenbaum/copilot.lua", -- for providers='copilot'
	-- 		"github/copilot.vim",
	-- 		{
	-- 			-- support for image pasting
	-- 			"HakonHarnes/img-clip.nvim",
	-- 			event = "VeryLazy",
	-- 			opts = {
	-- 				-- recommended settings
	-- 				default = {
	-- 					embed_image_as_base64 = false,
	-- 					prompt_for_file_name = false,
	-- 					drag_and_drop = {
	-- 						insert_mode = true,
	-- 					},
	-- 					-- required for Windows users
	-- 					use_absolute_path = true,
	-- 				},
	-- 			},
	-- 		},
	-- 		{
	-- 			-- Make sure to set this up properly if you have lazy=true
	-- 			"MeanderingProgrammer/render-markdown.nvim",
	-- 			opts = {
	-- 				file_types = { "markdown", "Avante" },
	-- 			},
	-- 			ft = { "markdown", "Avante" },
	-- 		},
	-- 	},
	-- },
	--
	--

	-- {
	-- 	"zbirenbaum/copilot.lua",
	-- 	enabled = require("config.profiles").enabled("ai_nonfree"),
	-- 	dependencies = {
	-- 		"copilotlsp-nvim/copilot-lsp", -- (optional) for NES functionality
	-- 	},
	-- 	cmd = "Copilot",
	-- 	event = "BufReadPost",
	-- 	opts = {
	-- 		suggestion = {
	-- 			-- enabled = not vim.g.ai_cmp,
	-- 			enabled = true,
	-- 			auto_trigger = true,
	-- 			hide_during_completion = vim.g.ai_cmp,
	-- 			keymap = {
	-- 				accept = false, -- handled by nvim-cmp / blink.cmp
	-- 				next = "<M-]>",
	-- 				prev = "<M-[>",
	-- 			},
	-- 		},
	-- 		panel = { enabled = false },
	-- 	},
	-- },
}
