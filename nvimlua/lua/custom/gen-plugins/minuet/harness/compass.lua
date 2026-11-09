-- Generated code, not human-reviewed.
-- Compass harness. Ctrl+G writes the draft to $TMPDIR/pi-editor-<random>/prompt.md
-- and opens $EDITOR as a child of the compass process. Each running Compass
-- writes <agent dir>/peers/<instance>.json with its pid and session file.

---@type GenMinuetHarness
local M = {
	name = "Compass",
	pattern = "*/pi-editor-*/prompt.md",
}

local agent_dir = vim.fn.expand(vim.env.COMPASS_CODING_AGENT_DIR or "~/.compass/agent")

-- User messages whose text Compass wrote itself: an expanded /skill command.
local generated_prefixes = { "<skill " }

-- A message's content is a string, or a list of blocks of which only the
-- text blocks are kept.
local function text_of(content)
	if type(content) == "string" then
		return content
	end
	local parts = {}
	for _, block in ipairs(content or {}) do
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

local function read_json(file)
	local ok, value = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
	return ok and value or nil
end

-- The session file of the Compass process this Neovim runs under: walk up the
-- parent processes (Neovim runs as a UI and an engine process) until one is
-- a running Compass instance.
local function session_file()
	local sessions = {}
	for _, file in ipairs(vim.fn.glob(agent_dir .. "/peers/*.json", false, true)) do
		local peer = read_json(file)
		if peer and peer.pid and peer.sessionFile then
			sessions[peer.pid] = peer.sessionFile
		end
	end
	local proc = vim.api.nvim_get_proc(vim.uv.os_getppid())
	while proc and proc.pid > 1 do
		if sessions[proc.pid] then
			return sessions[proc.pid]
		end
		proc = vim.api.nvim_get_proc(proc.ppid)
	end
end

local function read_entries(file)
	local entries = {}
	for _, line in ipairs(vim.fn.readfile(file)) do
		-- The last line can be cut short while Compass is still writing it.
		local ok, entry = pcall(vim.json.decode, line)
		if ok and type(entry) == "table" then
			table.insert(entries, entry)
		end
	end
	return entries
end

-- The entries the model sees, as Compass's buildContextEntries picks them:
-- the session is a tree, so follow the newest entry back to the root; after
-- a compaction, keep the compaction, the entries it kept and the ones after it.
local function context_entries(entries)
	local by_id = {}
	for _, entry in ipairs(entries) do
		by_id[entry.id] = entry
	end
	local path = {}
	local entry = entries[#entries]
	while entry do
		table.insert(path, 1, entry)
		entry = entry.parentId and by_id[entry.parentId]
	end

	local compaction_index
	for i, e in ipairs(path) do
		if e.type == "compaction" then
			compaction_index = i
		end
	end
	if not compaction_index then
		return path
	end
	local compaction = path[compaction_index]
	local kept = { compaction }
	local keeping = false
	for i = 1, compaction_index - 1 do
		keeping = keeping or path[i].id == compaction.firstKeptEntryId
		if keeping then
			table.insert(kept, path[i])
		end
	end
	return vim.list_extend(kept, path, compaction_index + 1)
end

-- Adds one context entry to the conversation.
local function read_entry(conversation, entry)
	if (entry.type == "compaction" or entry.type == "branch_summary") and entry.summary then
		local summary = vim.trim(entry.summary)
		conversation.summary = conversation.summary and conversation.summary .. "\n\n" .. summary or summary
		return
	end
	if entry.type ~= "message" then
		return
	end
	local message = entry.message
	local text = vim.trim(text_of(message.content))
	if text == "" then
		return
	end
	if message.role == "user" and not is_generated(text) then
		table.insert(conversation.rounds, { user = text, reply = "" })
	elseif message.role == "assistant" and conversation.rounds[1] then
		-- Keep the last text of the reply, which usually sums the turn up.
		conversation.rounds[#conversation.rounds].reply = text
	end
end

function M.conversation()
	local file = session_file()
	if not file or vim.fn.filereadable(file) == 0 then
		return nil
	end
	local conversation = { rounds = {} }
	for _, entry in ipairs(context_entries(read_entries(file))) do
		read_entry(conversation, entry)
	end
	if not conversation.summary and not conversation.rounds[1] then
		return nil
	end
	return conversation
end

return M
