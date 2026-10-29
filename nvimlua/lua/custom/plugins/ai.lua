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
				cc.cli("#{diagnostics} Can you fix these?", { submit = true })
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
	{
		"milanglacier/minuet-ai.nvim",
		enabled = profiles.enabled("ai_libre") or profiles.enabled("ai_nonfree"),
		config = function()
			local provider, provider_options
			if profiles.enabled("ai_nonfree") then
				provider = "openai_compatible"
				provider_options = {
					openai_compatible = {
						api_key = "OPENROUTER_API_KEY",
						end_point = "https://openrouter.ai/api/v1/chat/completions",
						model = "anthropic/claude-haiku-5.5",
						name = "OpenRouter",
						optional = {
							max_tokens = 56,
							provider = { sort = "throughput" },
							reasoning = { effort = "none" },
						},
					},
				}
			else
				provider = "openai_fim_compatible"
				provider_options = {
					-- Ollama needs no key, but minuet wants the name of a variable
					-- that is set.
					openai_fim_compatible = {
						api_key = "TERM",
						end_point = "http://localhost:11434/v1/completions",
						model = "qwen2.5-coder:7b",
						name = "Ollama",
						optional = { max_tokens = 56 },
					},
				}
			end
			require("minuet").setup({
				provider = provider,
				provider_options = provider_options,
				-- Ask soon after a pause, for one suggestion over the last ~4000
				-- characters, so it arrives in about a second.
				debounce = 150,
				throttle = 500,
				n_completions = 1,
				context_window = 4000,
				virtualtext = {
					auto_trigger_ft = { "markdown", "gitcommit", "text" },
					-- Alt is the left Option key: Ghostty sets `macos-option-as-alt = left`.
					keymap = {
						accept = "<A-A>",
						accept_line = "<A-a>",
						accept_n_lines = "<A-z>",
						prev = "<A-[>",
						next = "<A-]>",
						dismiss = "<A-e>",
					},
				},
			})

			-- Minuet has no accept-word action, but it keeps a suggestion while
			-- what you type matches its start, so type the suggestion's next word.
			vim.keymap.set("i", "<A-w>", function()
				local row, col = unpack(vim.api.nvim_win_get_cursor(0))
				local ns = require("minuet.virtualtext").ns_id
				local mark =
					vim.api.nvim_buf_get_extmarks(0, ns, { row - 1, col }, { row - 1, col }, { details = true })[1]
				local word = mark and mark[4].virt_text and mark[4].virt_text[1][1]:match("^%s*%S+")
				if word then
					vim.api.nvim_feedkeys(word, "n", false)
				else
					-- The suggestion starts on the next line.
					require("minuet.virtualtext").action.accept_line()
				end
			end, { desc = "Minuet: accept next word" })
		end,
	},
}
