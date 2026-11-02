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
				-- EXPLAIN: A message's `content` is either a string, or
				-- EXPLAIN: a list of blocks like { {type="text", text="..."}, {type="tool_use", ...} }.
				local function text_of(content)
					-- EXPLAIN: Already plain text (a typed message): return it unchanged.
					if type(content) == "string" then
						return content
					end
					local parts = {}
					for _, block in ipairs(content) do
						if block.type == "text" then
							table.insert(parts, block.text)
						end
					end
					return table.concat(parts, "\n")
				end
				vim.api.nvim_create_autocmd("BufReadPost", {
					pattern = "claude-prompt-*.md",
					group = vim.api.nvim_create_augroup("custom-ai-claude-prompt", { clear = true }),
					callback = function(event)
						local pid = vim.uv.os_getppid()
						while
							pid > 1
							and vim.fn.filereadable(vim.fn.expand("~/.claude/sessions/") .. pid .. ".json") == 0
						do
							pid = tonumber(vim.fn.system({ "ps", "-o", "ppid=", "-p", tostring(pid) }))
						end
						if pid <= 1 then
							return
						end
						local session_file = vim.fn.expand("~/.claude/sessions/") .. pid .. ".json"
						local session = vim.json.decode(table.concat(vim.fn.readfile(session_file), "\n"))
						-- name is the session's folder with every character that is not a letter or digit
						-- (`%W`) replaced by "-": /Users/felis/Programming/my-dotfiles becomes
						-- -Users-felis-Programming-my-dotfiles. 
						local transcript = vim.fn.expand("~/.claude/projects/")
							.. session.cwd:gsub("%W", "-")
							.. "/"
							.. session.sessionId
							.. ".jsonl"
						if vim.fn.filereadable(transcript) == 0 then
							return
						end
						-- Read the transcript's last 300 lines (-300), one JSON record per line. 
						local user, reply = "", ""
						for _, line in ipairs(vim.fn.readfile(transcript, "", -300)) do
							local record = vim.json.decode(line)
							local text = record.message and not record.isSidechain and text_of(record.message.content)
								or ""
							if text ~= "" and record.type == "user" then
								user, reply = text, ""
							elseif text ~= "" and record.type == "assistant" then
								reply = text
							end
						end
						vim.b[event.buf].claude_exchange = "<!-- Last exchange in this Claude Code session, for context only:\n\nUser:\n"
							.. user:sub(-1500)
							.. "\n\nClaude:\n"
							.. reply:sub(-3000)
							.. "\n-->\n"
					end,
				})
				provider_options = {
					openai_compatible = {
						few_shots = {
							{
								-- EXPLAIN: Example 1: a conversation about a slow login, and a half-typed word ("cach") that the
								-- EXPLAIN: answer below finishes ("ing you mentioned..."). The `..` lines just join one long string.
								role = "user",
								content = "<!-- language: markdown -->\n<!-- indentation: use 4 spaces for a tab -->\n<contextBeforeCursor>\n"
									.. "<!-- Last exchange in this Claude Code session, for context only:\n\nUser:\nWhy is the login slow?\n\n"
									.. "Claude:\nThe session lookup runs a query per request. Caching it would cut most of the time.\n-->\n"
									.. "Can you add the cach<cursorPosition>\n<contextAfterCursor>\n\n",
							},
							{
								role = "assistant",
								content = "ing you mentioned, and keep it to the session lookup only?\n<endCompletion>\n",
							},
							{
								-- EXPLAIN: Example 2: a short draft with no conversation, continued as a question.
								role = "user",
								content = "<!-- language: markdown -->\n<!-- indentation: use 4 spaces for a tab -->\n<contextBeforeCursor>\n"
									.. "What does <cursorPosition>\n<contextAfterCursor>\n\n",
							},
							{
								role = "assistant",
								content = "this error mean, and where in the code does it come from?\n<endCompletion>\n",
							},
							{
								-- EXPLAIN: Example 3: a conversation and an empty draft. The answer is a likely next message from
								-- EXPLAIN: you, not a reply from Claude.
								role = "user",
								content = "<!-- language: markdown -->\n<!-- indentation: use 4 spaces for a tab -->\n<contextBeforeCursor>\n"
									.. "<!-- Last exchange in this Claude Code session, for context only:\n\nUser:\nAdd a retry to the upload.\n\n"
									.. "Claude:\nDone: the upload now retries three times with a growing delay. The tests pass.\n-->\n"
									.. "<cursorPosition>\n<contextAfterCursor>\n\n",
							},
							{
								role = "assistant",
								content = "Thanks. Can you also log each retry, so I can see how often it happens?\n<endCompletion>\n",
							},
						},
						chat_input = {
							context_before_cursor = function(before, after, opts)
								local default =
									require("minuet.config").default_chat_input_prefix_first.context_before_cursor
								-- Minuet starts text on a first line with an empty line, which also
								-- made Haiku reply instead of continuing.
								-- EXPLAIN: Right to left: default(...) is minuet's normal text; :gsub("^\n", "") drops one line break
								-- EXPLAIN: at the very start (^ = at the start); `vim.b.claude_exchange or ""` is the stored exchange,
								-- EXPLAIN: or nothing in any other file; `..` puts it first. gsub also returns a replacement count,
								-- EXPLAIN: but inside a `..` expression Lua keeps only the text.
								return (vim.b.claude_exchange or "") .. default(before, after, opts):gsub("^\n", "")
							end,
						},
						api_key = "OPENROUTER_API_KEY",
						end_point = "https://openrouter.ai/api/v1/chat/completions",
						model = "anthropic/claude-haiku-5.5",
						name = "OpenRouter",
						optional = {
							max_tokens = 56,
							provider = { sort = "throughput" },
							reasoning = { effort = "none" },
							stop = { "<endCompletion>" },
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
				-- EXPLAIN: Was 500 ("never two requests less than 500 ms apart"). debounce = 150 is unchanged:
				-- EXPLAIN: wait 150 ms after your last keystroke. With throttle 0 every pause sends a request,
				-- EXPLAIN: and minuet cancels the outdated in-flight ones.
				throttle = 0,
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
