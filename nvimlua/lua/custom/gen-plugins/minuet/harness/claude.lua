-- Generated code, not human-reviewed.
-- Claude Code harness. Ctrl+G writes the draft to claude-prompt-<uuid>.md and
-- opens $EDITOR as a descendant of the claude process. That process's session
-- file (<config>/sessions/<pid>.json) names the transcript to read.

---@type GenMinuetHarness
local M = {
	name = "Claude Code",
	pattern = "claude-prompt-*.md",
}

local config_dir = vim.fn.expand(vim.env.CLAUDE_CONFIG_DIR or "~/.claude")

-- User records whose text Claude Code wrote itself, not the user.
local generated_prefixes = { "<command-", "<local-command-", "<task-notification>", "[Request interrupted" }

-- A message's content is a string, or a list of blocks of which only the
-- text blocks are kept.
local function text_of(content)
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

local function is_generated(text)
	for _, prefix in ipairs(generated_prefixes) do
		if vim.startswith(text, prefix) then
			return true
		end
	end
	return false
end

-- Neovim runs as a UI and an engine process, so walk up the parents until one
-- has a session file.
local function session_file()
	local proc = vim.api.nvim_get_proc(vim.uv.os_getppid())
	while proc and proc.pid > 1 do
		local file = config_dir .. "/sessions/" .. proc.pid .. ".json"
		if vim.fn.filereadable(file) == 1 then
			return file
		end
		proc = vim.api.nvim_get_proc(proc.ppid)
	end
end

-- Adds one transcript record to the conversation.
local function read_record(conversation, record)
	-- After a compaction Claude itself sees only the summary and what follows,
	-- so start over. The summary is the next record.
	if record.type == "system" and record.subtype == "compact_boundary" then
		conversation.summary, conversation.rounds = nil, {}
		return
	end
	if not record.message or record.isSidechain or record.isMeta then
		return
	end
	local text = vim.trim(text_of(record.message.content))
	if text == "" then
		return
	end
	if record.isCompactSummary then
		conversation.summary = text
	elseif record.type == "user" and not is_generated(text) then
		table.insert(conversation.rounds, { user = text, reply = "" })
	elseif record.type == "assistant" and conversation.rounds[1] then
		-- Keep the last text of the reply, which usually sums the turn up.
		conversation.rounds[#conversation.rounds].reply = text
	end
end

function M.conversation()
	local file = session_file()
	if not file then
		return nil
	end
	local session = vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
	-- The project folder is the session's cwd with every non-alphanumeric
	-- character replaced by "-".
	local transcript = config_dir .. "/projects/" .. session.cwd:gsub("%W", "-") .. "/" .. session.sessionId .. ".jsonl"
	if vim.fn.filereadable(transcript) == 0 then
		return nil
	end

	local conversation = { rounds = {} }
	for _, line in ipairs(vim.fn.readfile(transcript)) do
		-- The last line can be cut short while Claude Code is still writing it.
		local ok, record = pcall(vim.json.decode, line)
		if ok then
			read_record(conversation, record)
		end
	end
	if not conversation.summary and not conversation.rounds[1] then
		return nil
	end
	return conversation
end

return M
