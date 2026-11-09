-- Generated code, not human-reviewed.
-- Autocorrect as you type. When a space or punctuation follows a word that
-- the spell checker marks bad and the dictionary does not know, the word is
-- replaced with the best spelling suggestion. A Backspace right after that
-- puts the typed word back (and removes the separator), and the next
-- separator leaves that word alone.
--
-- It only acts in a prose buffer (see start()) whose window has 'spell' on,
-- so `:setlocal nospell` is the per-buffer off switch.
local words = require("custom.gen-plugins.pro-prose-complete.words")

local M = {}

-- Characters that end a word and trigger a check.
local SEPARATORS =
	{ [" "] = true, ["."] = true, [","] = true, [";"] = true, [":"] = true, ["!"] = true, ["?"] = true, [")"] = true }
-- How many spelling suggestions compete; the dictionary score picks among
-- them, minus a penalty for each place lower in the spell checker's order.
local SUGGESTIONS, PLACE_PENALTY = 3, 2
-- Longer tokens are not words worth correcting (and spellsuggest gets slow).
local MAX_WORD_BYTES = 30

-- Markdown syntax nodes where text is code or a link target, not prose.
local CODE_NODES = {
	fenced_code_block = true,
	indented_code_block = true,
	code_span = true,
	html_block = true,
	link_destination = true,
	uri_autolink = true,
}

local BS = vim.keycode("<BS>")
local marks = vim.api.nvim_create_namespace("custom-gen-pro-prose-words")
local group = vim.api.nvim_create_augroup("custom-gen-pro-prose-autocorrect", { clear = true })
local key_listener = vim.api.nvim_create_namespace("custom-gen-pro-prose-autocorrect")

local prose_filetypes = {} ---@type table<string, true>
local last ---@type { buf: integer, row: integer, col: integer, typed: string, fixed: string }?
local spared ---@type { buf: integer, row: integer, col: integer, word: string }?

local function in_code(buf, row, line, col)
	-- An odd number of backticks before the word: inside inline code, even if
	-- the syntax tree has not caught up with a backtick just typed.
	if select(2, line:sub(1, col):gsub("`", "")) % 2 == 1 then
		return true
	end
	-- Parse this line now: Neovim's highlighter parses in the background, so
	-- the tree can lag behind fast typing.
	pcall(function()
		vim.treesitter.get_parser(buf):parse({ row, row + 1 })
	end)
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col }, ignore_injections = false })
	while ok and node do
		if CODE_NODES[node:type()] then
			return true
		end
		node = node:parent()
	end
	return false
end

-- The word to check before the separator, with its start column (0-based),
-- or nil when the text there is not a plain word: URLs, paths, code and
-- names with digits or inner capitals are left alone.
local function word_before(line, sep_col)
	local token = line:sub(1, sep_col):match("%S+$")
	if not token or #token > MAX_WORD_BYTES or token:find("[/:@`_%d]") or token:find("www%.") then
		return nil
	end
	-- Keep only the word after opening quotes, brackets or emphasis marks.
	local word = token:match("^[%(%[\"'*]*(.-)$")
	-- No ASCII punctuation except one inner apostrophe ("don't"). Other
	-- characters (accents, curly quotes, emoji) pass here; check() then only
	-- corrects when the spell checker's bad word is the whole of it.
	if not (word:match("^[^%p%s]+$") or word:match("^[^%p%s]+'[^%p%s]+$")) then
		return nil
	end
	-- Mixed case (camelCase, iOS, NASA) is a name or code, not a typo.
	if #word < 3 or word:sub(2):find("%u") then
		return nil
	end
	return word, sep_col - #word
end

-- The spell checker's first suggestion, unless a lower one is a word the
-- dictionary rates clearly higher. When the first suggestion is not in the
-- dictionary (a French word, since wordfreq is English: "trés" -> "très"),
-- the spell checker's choice stands.
local function best_suggestion(word)
	local best, best_score
	-- Ask for the lowercase word: for "Teh" the spell checker ranks "The"
	-- below other capitalised words; the capital is put back below.
	for place, suggestion in ipairs(vim.fn.spellsuggest(word:lower(), SUGGESTIONS)) do
		local score = words.score(suggestion)
		if place == 1 then
			best, best_score = suggestion, score and score - PLACE_PENALTY
			if not score then
				break
			end
		elseif score and score - PLACE_PENALTY * place > best_score then
			best, best_score = suggestion, score - PLACE_PENALTY * place
		end
	end
	if best and word:find("^%u") then
		best = best:gsub("^%l", string.upper)
	end
	return best
end

-- Replaces `word` with its best suggestion, if the word is still where it
-- was. Runs just after the separator is typed, so suggestions are not
-- looked up while the key is being handled.
local function fix(buf, mark, word, sep)
	local pos = vim.api.nvim_buf_get_extmark_by_id(buf, marks, mark, {})
	vim.api.nvim_buf_del_extmark(buf, marks, mark)
	local row, start = pos[1], pos[2]
	local line = row and vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line or line:sub(start + 1, start + #word + #sep) ~= word .. sep then
		return
	end
	local fixed = best_suggestion(word)
	if not fixed or fixed == word then
		return
	end
	-- Neovim moves the cursor along with the text after the word, so the
	-- separator stays between the corrected word and the cursor.
	vim.api.nvim_buf_set_text(buf, row, start, row, start + #word, { fixed })
	words.use(fixed)
	last = { buf = buf, row = row, col = start, typed = word, fixed = fixed }
end

-- Called when `sep` is about to be typed at (row, col), 0-based. The fix is
-- scheduled, so it works even when keys come faster than Neovim redraws: an
-- extmark keeps track of the word if earlier fixes on the line move it.
local function check(buf, row, col, sep)
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	local word, start = word_before(line, col)
	if not word then
		return
	end
	if spared and spared.buf == buf and spared.row == row and spared.col == start and spared.word == word then
		spared = nil
		return
	end
	if words.is_trusted(word) or in_code(buf, row, line, start) then
		words.use(word)
		return
	end
	local bad = vim.spell.check(word)
	if #bad == 0 then
		words.use(word)
		return
	end
	-- Correct only a plain misspelling that is the whole word. Anything else
	-- ("“teh”", "café–teh", a rare or wrongly capitalised word) is left as typed.
	if #bad ~= 1 or bad[1][1] ~= word or bad[1][2] ~= "bad" then
		return
	end
	local mark = vim.api.nvim_buf_set_extmark(buf, marks, row, start, {})
	vim.schedule(function()
		fix(buf, mark, word, sep)
	end)
end

-- Backspace right after a correction: the separator is already deleted by
-- the time this runs, so put the typed word back and spare it once.
local function revert()
	local done = last
	last = nil
	if not done or vim.api.nvim_get_current_buf() ~= done.buf then
		return
	end
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	if row - 1 ~= done.row or col ~= done.col + #done.fixed or line:sub(done.col + 1, col) ~= done.fixed then
		return
	end
	vim.api.nvim_buf_set_text(done.buf, done.row, done.col, done.row, col, { done.typed })
	vim.api.nvim_win_set_cursor(0, { row, done.col + #done.typed })
	spared = { buf = done.buf, row = done.row, col = done.col, word = done.typed }
end

function M.attach(buf)
	-- Replace, never add: a buffer can be attached again (after :bdelete and
	-- :edit, or a filetype set twice).
	vim.api.nvim_clear_autocmds({ group = group, buffer = buf })
	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = group,
		buffer = buf,
		callback = function()
			local sep = vim.v.char
			if SEPARATORS[sep] and prose_filetypes[vim.bo[buf].filetype] and vim.wo.spell then
				local row, col = unpack(vim.api.nvim_win_get_cursor(0))
				check(buf, row - 1, col, sep)
			end
		end,
	})
end

-- Starts watching keys for the Backspace undo, for buffers of `filetypes`.
-- Backspace is watched, not mapped, so nvim-autopairs keeps its own
-- Backspace mapping. Any key other than a separator ends the chance to undo
-- a correction, and ends the spared word's one free pass.
function M.start(filetypes)
	for _, filetype in ipairs(filetypes) do
		prose_filetypes[filetype] = true
	end
	vim.on_key(function(_, typed)
		if typed == "" then
			return
		end
		if typed == BS and last and vim.api.nvim_get_mode().mode == "i" then
			vim.schedule(revert)
		elseif not SEPARATORS[typed] then
			last, spared = nil, nil
		end
	end, key_listener)
end

return M
