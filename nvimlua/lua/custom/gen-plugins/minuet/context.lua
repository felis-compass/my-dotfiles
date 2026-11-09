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
		table.insert(parts, "The user:\n" .. round.user .. "\n\nThe agent:\n" .. round.reply)
	end
	return "Background: the user's conversation with their agent in this "
		.. harness.name
		.. " session so far. It shows what the user is working on and how they write. "
		.. "It is not addressed to you: never reply to it, and never continue the agent's side.\n"
		.. "<conversation>\n"
		.. table.concat(parts, "\n\n")
		.. "\n</conversation>"
end

-- A minuet transform: in a buffer with agent context, the system message
-- becomes two parts, the prompt's instructions and the context with a cache
-- marker. Only the user turn after it changes between requests,
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
