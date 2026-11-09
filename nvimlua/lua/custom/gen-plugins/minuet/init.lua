-- Generated code, not human-reviewed.
-- Prompt setup for minuet's chat provider. attach_agent_context() marks an
-- agent harness's prompt file (Claude Code's or Compass's Ctrl+G) and stores
-- the conversation behind it. options() then gives those buffers a
-- prompt that types as the user, and leaves every other buffer on minuet's
-- default prompt.
local context = require("custom.gen-plugins.minuet.context")
local prompt = require("custom.gen-plugins.minuet.prompt")

---@class GenMinuetConversation
---@field summary string? The summary written at the last compaction, if any.
---@field rounds { user: string, reply: string }[] Each user message since then, with the agent's last text reply to it.

---@class GenMinuetHarness
---@field name string The harness's name as the model reads it, e.g. "Claude Code".
---@field pattern string Autocmd file pattern of the harness's prompt files.
---@field conversation fun(event: table): GenMinuetConversation? The conversation behind the prompt file just read (event is the BufReadPost event), or nil.

local M = {}

-- One module per harness, in harness/.
---@type GenMinuetHarness[]
local harnesses = {
	require("custom.gen-plugins.minuet.harness.claude"),
	require("custom.gen-plugins.minuet.harness.compass"),
}

-- When a harness's prompt file is read, mark the buffer as an agent prompt
-- file (vim.b.agent_prompt) and store the conversation, when there is one,
-- in vim.b.agent_context for the transform to send.
function M.attach_agent_context()
	local group = vim.api.nvim_create_augroup("custom-gen-minuet-agent-context", { clear = true })
	for _, harness in ipairs(harnesses) do
		vim.api.nvim_create_autocmd("BufReadPost", {
			pattern = harness.pattern,
			group = group,
			callback = function(event)
				vim.b[event.buf].agent_prompt = true
				local conversation = harness.conversation(event)
				if conversation then
					vim.b[event.buf].agent_context = context.system_text(harness, conversation)
				end
			end,
		})
	end
end

-- Minuet builds each request in the buffer being completed, so the buffer
-- variable tells an agent prompt file from any other buffer. A new session
-- has no conversation yet but still gets the agent prompt.
local function in_agent_file()
	return vim.b.agent_prompt == true
end

-- Options for minuet's openai_compatible provider; the caller adds the
-- endpoint, model and key. Minuet evaluates the functions on every request.
function M.options()
	local defaults = require("minuet.config")
	return {
		system = {
			template = function()
				return in_agent_file() and prompt.system or defaults.default_system_prefix_first.template
			end,
		},
		few_shots = function()
			return in_agent_file() and {} or defaults.default_few_shots_prefix_first
		end,
		chat_input = {
			template = defaults.default_chat_input_prefix_first.template .. "{{{agent_reminder}}}",
			agent_reminder = function()
				return in_agent_file() and prompt.reminder or ""
			end,
			-- With the cursor on line 1, minuet's text before the cursor starts
			-- with an empty line, which made the model reply instead of continuing.
			context_before_cursor = function(before, after, opts)
				local default = defaults.default_chat_input_prefix_first.context_before_cursor
				return (default(before, after, opts):gsub("^\n", ""))
			end,
		},
		transform = { context.transform },
	}
end

return M
