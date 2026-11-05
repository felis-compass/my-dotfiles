-- Generated code, not human-reviewed.
-- Prompt setup for minuet's chat provider. options() applies to every buffer
-- minuet completes; attach_agent_context() adds the conversation behind an
-- agent harness's prompt file (Claude Code's Ctrl+G and the like).
local context = require("custom.gen-plugins.minuet.context")

---@class GenMinuetConversation
---@field summary string? The summary written at the last compaction, if any.
---@field rounds { user: string, reply: string }[] Each user message since then, with the assistant's last text reply to it.

---@class GenMinuetHarness
---@field name string The harness's name as the model reads it, e.g. "Claude Code".
---@field assistant string The assistant's label in the conversation, e.g. "Claude".
---@field pattern string Autocmd file pattern of the harness's prompt files.
---@field conversation fun(event: table): GenMinuetConversation? The conversation behind the prompt file just read (event is the BufReadPost event), or nil.

local M = {}

-- One module per harness, in harness/.
---@type GenMinuetHarness[]
local harnesses = {
	require("custom.gen-plugins.minuet.harness.claude"),
}

-- When a harness's prompt file is read, store its agent context in
-- vim.b.agent_context for the transform to send.
function M.attach_agent_context()
	local group = vim.api.nvim_create_augroup("custom-gen-minuet-agent-context", { clear = true })
	for _, harness in ipairs(harnesses) do
		vim.api.nvim_create_autocmd("BufReadPost", {
			pattern = harness.pattern,
			group = group,
			callback = function(event)
				local conversation = harness.conversation(event)
				if conversation then
					vim.b[event.buf].agent_context = context.system_text(harness, conversation)
				end
			end,
		})
	end
end

local function example(draft, completion, conversation)
	local before = conversation
			and "<!-- Recent conversation in this Claude Code session, for context only:\n\n" .. conversation .. "\n-->\n"
		or ""
	return {
		{
			role = "user",
			content = "<!-- language: markdown -->\n<!-- indentation: use 4 spaces for a tab -->\n<contextBeforeCursor>\n"
				.. before
				.. draft
				.. "<cursorPosition>\n<contextAfterCursor>\n\n",
		},
		{ role = "assistant", content = completion .. "\n<endCompletion>\n" },
	}
end

-- Draft-continuation examples: a half-typed word, a short draft, and an empty
-- draft after a conversation, each continued as the user's own message.
local few_shots = vim.iter({
	example(
		"Can you add the cach",
		"ing you mentioned, and keep it to the session lookup only?",
		"User:\nWhy is the login slow?\n\n"
			.. "Claude:\nThe session lookup runs a query per request. Caching it would cut most of the time."
	),
	example("What does ", "this error mean, and where in the code does it come from?"),
	example(
		"",
		"Thanks. Can you also log each retry, so I can see how often it happens?",
		"User:\nAdd a retry to the upload.\n\n"
			.. "Claude:\nDone: the upload now retries three times with a growing delay. The tests pass."
	),
})
	:flatten()
	:totable()

-- Options for minuet's openai_compatible provider; the caller adds the
-- endpoint, model and key.
function M.options()
	return {
		few_shots = few_shots,
		chat_input = {
			-- With the cursor on line 1, minuet's text before the cursor starts
			-- with an empty line, which made the model reply instead of continuing.
			context_before_cursor = function(before, after, opts)
				local default = require("minuet.config").default_chat_input_prefix_first.context_before_cursor
				return (default(before, after, opts):gsub("^\n", ""))
			end,
		},
		transform = { context.transform },
	}
end

return M
