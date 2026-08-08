return {
	{
		"CopilotC-Nvim/CopilotChat.nvim",
		enabled = require("config.profiles").enabled("ai_nonfree"),
		-- enabled = true,
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

	{
		"zbirenbaum/copilot.lua",
		enabled = require("config.profiles").enabled("ai_nonfree"),
		cmd = "Copilot",
		build = ":Copilot auth",
		event = "BufReadPost",
		config = function()
			require("copilot").setup({

				suggestion = {
					enabled = not vim.g.ai_cmp,
					auto_trigger = true,
					hide_during_completion = vim.g.ai_cmp,
					keymap = {
						accept = "<Tab>", -- handled by nvim-cmp / blink.cmp
						next = false,
						prev = false,
					},
				},
				panel = { enabled = false },
				filetypes = {
					markdown = true,
					help = true,
				},
				server_opts_overrides = {
					settings = {
						["github"] = { -- For standard copilot.
							endpoint = "https://api.githubcopilot.com",
						},
						["github-enterprise"] = { -- For GHE enterprise copilot server.
							uri = "https://my-enterprise.ghe.com",
						},
					},
				},
			})
		end,
	},
	{
		"olimorris/codecompanion.nvim",
		enabled = require("config.profiles").enabled("ai_nonfree"),
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			require("codecompanion").setup({
				interactions = {
					cmd = {
						agent = "claude_code",
						agents = {
							claude_code = {
								cmd = "claude",
								args = {},
								description = "Claude Code CLI",
							},
						},
					},
				},
			})
		end,
	},
}
