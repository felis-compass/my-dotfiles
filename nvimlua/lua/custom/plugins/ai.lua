local profiles = require("config.profiles")

return {
	{
		"olimorris/codecompanion.nvim",
		enabled = profiles.enabled("ai_libre") or profiles.enabled("ai_nonfree"),
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			local height = 0.4
			local agent, agents, ollama_model

			if profiles.enabled("ai_nonfree") then
				agent = "claude"
				agents = {
					claude = { cmd = "claude", args = {}, description = "Claude Code" },
					compass = { cmd = "compass", args = {}, description = "Compass Harness" },
				}
				ollama_model = "qwen3.5:9b"
			else
				agent = "pi"
				agents = { pi = { cmd = "pi", args = {}, description = "Pi" } }
				ollama_model = "qwen2.5-coder:7b"
			end

			require("codecompanion").setup({
				adapters = {
					http = {
						ollama = function()
							return require("codecompanion.adapters").extend("ollama", {
								schema = { model = { default = ollama_model } },
							})
						end,
					},
				},
				interactions = {
					chat = { adapter = "ollama" },
					inline = { adapter = "ollama" },
					cmd = { adapter = "ollama" },
					background = { adapter = "ollama" },
					-- Type as soon as the agent window is entered.
					cli = { agent = agent, agents = agents, opts = { auto_insert = true } },
				},
				display = {
					cli = { window = { layout = "horizontal", position = "bottom", height = height } },
				},
			})

			-- The horizontal layout splits whichever window is current, such as
			-- neo-tree, so move the agent to a full-width pane at the bottom. <C-z>
			-- would suspend the agent with no shell around it to `fg` it back.
			vim.api.nvim_create_autocmd("User", {
				pattern = "CodeCompanionCLIOpened",
				group = vim.api.nvim_create_augroup("custom-ai-agent-window", { clear = true }),
				callback = function(event)
					vim.keymap.set("t", "<C-z>", "<Nop>", { buffer = event.data.bufnr })
					local win = vim.fn.bufwinid(event.data.bufnr)
					vim.api.nvim_win_call(win, function()
						vim.cmd("wincmd J")
					end)
					vim.api.nvim_win_set_height(win, math.floor(vim.o.lines * height))
				end,
			})

			local cc = require("codecompanion")
			local map = vim.keymap.set
			map("n", "<leader>aa", cc.toggle_cli, { desc = "[A]I: toggle [a]gent window" })

			map({ "n", "v" }, "<leader>ap", function()
				cc.cli({ prompt = true })
			end, { desc = "[A]I: toggle [p]rompt input (attaches selection)" })

			map({ "n", "v" }, "<leader>ac", function()
				cc.cli("#{this}", { focus = false })
			end, { desc = "[A]I: add file/selection as [c]ontext" })

			map("n", "<leader>ad", function()
				cc.cli("#{diagnostics} Can you fix these?", { submit = false })
			end, { desc = "[A]I: fix [d]iagnostics" })

			map("n", "<leader>ar", "<Cmd>CodeCompanionCodeReview<CR>", { desc = "[A]I: open code [r]eview" })
			-- `<Cmd>` in normal mode, so a count is not read as a range.

			map("n", "<leader>aC", "<Cmd>CodeCompanionCodeReview Comment<CR>", { desc = "[A]I: review [C]omment" })

			map("v", "<leader>aC", ":CodeCompanionCodeReview Comment<CR>", { desc = "[A]I: review [C]omment" })

			map("n", "<leader>as", function()
				cc.cli("Please action #{code_review}", { submit = true })
			end, { desc = "[A]I: [s]end review comments to agent" })

			require("which-key").add({ { "<leader>a", group = "[A]I agent", mode = { "n", "v" } } })
		end,
	},
}
