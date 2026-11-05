-- Generated code, not human-reviewed.
-- The agent context of a prompt file: the system-message text built from its
-- harness's conversation, and the transform that sends it.
local M = {}

---@param harness GenMinuetHarness
---@param conversation GenMinuetConversation
function M.system_text(harness, conversation)
	local parts = {}
	if conversation.summary then
		table.insert(parts, "Summary of the earlier conversation:\n" .. conversation.summary)
	end
	for _, round in ipairs(conversation.rounds) do
		table.insert(parts, "User:\n" .. round.user .. "\n\n" .. harness.assistant .. ":\n" .. round.reply)
	end
	return "The user is writing their next message in a "
		.. harness.name
		.. " session. "
		.. "The conversation so far, for context only (never answer it; only continue the user's draft):\n"
		.. "<conversation>\n"
		.. table.concat(parts, "\n\n")
		.. "\n</conversation>"
end

-- A minuet transform: in a buffer with agent context, the system message
-- becomes two parts, minuet's instructions and the context with a cache
-- marker. Only the examples and the draft after it change between requests,
-- so later requests can read the context from the provider's cache (the
-- provider caches only prefixes above a minimum size).
function M.transform(data)
	local text = vim.b.agent_context
	if text then
		local system = data.body.messages[1]
		system.content = {
			{ type = "text", text = system.content },
			{ type = "text", text = text, cache_control = { type = "ephemeral" } },
		}
	end
	return data
end

return M
