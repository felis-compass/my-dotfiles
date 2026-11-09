-- Generated code, not human-reviewed.
-- pro-prose-complete: word completion and autocorrect for prose (markdown,
-- commit messages, plain text, and agent prompt files from Ctrl+G).
--
-- enable(cmp) takes over nvim-cmp's prose filetypes from the basic word
-- list in custom/plugins/completion.lua, turns on autocorrect there, and
-- adds :ProseWordsSync. See README.md in this folder for the design.
local words = require("custom.gen-plugins.pro-prose-complete.words")
local autocorrect = require("custom.gen-plugins.pro-prose-complete.autocorrect")

local M = {}

M.filetypes = { "markdown", "gitcommit", "text" }

-- The chat words' spell file. The caller adds it to 'spellfile' (after the
-- user's own, which "zg" writes to) so the spell checker accepts chat words.
M.spellfile = words.chat_spellfile

local SOURCE = "pro_prose"
local MAX_ITEMS = 20

local function register_source(cmp)
	cmp.register_source(SOURCE, {
		get_keyword_pattern = function()
			return [[\a\+]]
		end,
		complete = function(_, request, callback)
			local typed = request.context.cursor_before_line:sub(request.offset)
			local items = {}
			for _, word in ipairs(words.complete(typed:lower(), MAX_ITEMS)) do
				-- Keep a capital first letter, as at the start of a sentence.
				local label = typed:find("^%u") and (word:gsub("^%l", string.upper)) or word
				-- The trailing space is inserted on confirm, like a phone keyboard.
				table.insert(items, { label = label, insertText = label .. " " })
			end
			-- Ask again on each key press, since only the best matches are returned.
			callback({ items = items, isIncomplete = true })
		end,
	})
	cmp.setup.filetype(M.filetypes, {
		sources = {
			{ name = SOURCE, keyword_length = 2 },
			{ name = "path" },
		},
		-- Keep the source's ranking.
		sorting = { comparators = { cmp.config.compare.order } },
	})
	-- An accepted suggestion counts as a use of that word.
	cmp.event:on("confirm_done", function(event)
		if event.entry.source.name == SOURCE then
			words.use(event.entry.completion_item.label)
		end
	end)
end

local syncing = false

local function run_sync()
	if syncing then
		vim.notify("Prose words: a sync is already running.")
		return
	end
	syncing = true
	local script = debug.getinfo(1, "S").source:sub(2):gsub("init%.lua$", "sync.py")
	vim.notify("Prose words: syncing from chats, this can take a minute…")
	vim.system({
		"python3",
		"-I",
		script,
		"--data-dir",
		words.data_dir,
		"--wordfreq",
		words.wordfreq_file,
		"--user-words",
		vim.o.spellfile,
	}, { text = true }, function(result)
		vim.schedule(function()
			syncing = false
			local output = vim.trim((result.stdout or "") .. "\n" .. (result.stderr or ""))
			-- Reload either way: a failed sync keeps the batches it finished.
			words.load()
			words.build_spellfile()
			if result.code ~= 0 then
				vim.notify("Prose words sync failed:\n" .. output, vim.log.levels.ERROR)
			else
				vim.notify(output .. "\nDictionary reloaded: " .. words.count() .. " words.")
			end
		end)
	end)
end

local enabled = false

function M.enable(cmp)
	if enabled then
		return
	end
	enabled = true
	words.load()
	words.build_spellfile()
	register_source(cmp or require("cmp"))
	autocorrect.start(M.filetypes)

	local group = vim.api.nvim_create_augroup("custom-gen-pro-prose", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = M.filetypes,
		callback = function(event)
			autocorrect.attach(event.buf)
		end,
	})
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.tbl_contains(M.filetypes, vim.bo[buf].filetype) then
			autocorrect.attach(buf)
		end
	end
	-- Usage counts are saved when Neovim quits and every few minutes.
	vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = words.save_usage })
	vim.fn.timer_start(5 * 60 * 1000, words.save_usage, { ["repeat"] = -1 })

	vim.api.nvim_create_user_command("ProseWordsSync", run_sync, {
		desc = "Add words from your Claude Code and Compass chats to the prose word list",
	})
end

return M
