-- Generated code, not human-reviewed.
-- The merged dictionary: wordfreq, the chat-built list and the user's own
-- spell file, kept as separate files and merged here in memory, plus the
-- user's usage counts. Scores are in wordfreq's unit, the natural log of a
-- word's frequency ("the" is about -2.8, a rare word about -13).
local M = {}

-- Where the data lives: an editor-neutral folder, so other tools (the sync
-- script, a future VS Code extension) can share it. PRO_PROSE_DATA_DIR
-- moves it, for tests or a shared setup.
M.data_dir = vim.env.PRO_PROSE_DATA_DIR or ((vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share")) .. "/pro-prose")
M.wordfreq_file = M.data_dir .. "/wordfreq-en-25000.json"
M.chat_file = M.data_dir .. "/chat-words.txt"
M.usage_file = M.data_dir .. "/usage.json"
-- The chat words as a Neovim spell word list. Listed in 'spellfile', it stops
-- the spell checker from underlining them; Neovim reads the compiled ".spl"
-- next to it. Generated from chat-words.txt, so edits to it are overwritten.
M.chat_spellfile = M.data_dir .. "/chat-words.utf-8.add"

local WORDFREQ_URL =
	"https://raw.githubusercontent.com/aparrish/wordfreq-en-25000/9650fa612e121beb6126b9b4d7344da287013c6e/wordfreq-en-25000-log.json"

-- Ranking, one blended scale rather than strict tiers, so that typing "th"
-- still offers "the" before a rarer chat word:
-- - a wordfreq word scores its log frequency;
-- - a chat word with n uses scores CHAT_BASE + log(n) + CHAT_BONUS, so one
--   used ~50 times sits with common English words;
-- - a word the user added by hand scores USER_SCORE, like a fairly common word;
-- - each use while typing adds USAGE_WEIGHT * log(1 + uses).
local CHAT_BASE, CHAT_BONUS = -11, 1
local USER_SCORE = -6
local USAGE_WEIGHT = 0.7

local score = {} ---@type table<string, number> lowercase word -> static score
-- Words from the user's or the chat list. wordfreq words are not in here:
-- wordfreq ranks words but also lists common misspellings ("teh", "isnt"),
-- so only the spell checker decides whether a wordfreq word is spelled right.
local trusted = {} ---@type table<string, true>
-- The spelling to offer for a word the user added with capitals ("GitHub").
local display = {} ---@type table<string, string>
local sorted = {} ---@type string[] words, best static score first
local usage = {} ---@type table<string, integer> lowercase word -> uses saved on disk
local added = {} ---@type table<string, integer> lowercase word -> uses this session, not yet saved

local function read_lines(file)
	return vim.fn.filereadable(file) == 1 and vim.fn.readfile(file) or {}
end

local function read_usage()
	local ok, saved = pcall(vim.json.decode, table.concat(read_lines(M.usage_file), "\n"))
	return ok and type(saved) == "table" and saved or {}
end

local function raise(word, value)
	if not score[word] or value > score[word] then
		score[word] = value
	end
end

-- The user's own words: the files in 'spellfile' ("zg" writes the first),
-- except the generated chat spell file. Lines marked "/!" are words the user
-- marked wrong with "zw".
local function user_words()
	local words = {}
	local chat = vim.fn.fnamemodify(M.chat_spellfile, ":p")
	for _, file in ipairs(vim.split(vim.o.spellfile, ",", { trimempty = true })) do
		if vim.fn.fnamemodify(file, ":p") ~= chat then
			for _, line in ipairs(read_lines(file)) do
				if not line:find("/!") and not vim.startswith(line, "#") then
					table.insert(words, (line:gsub("/.*$", "")))
				end
			end
		end
	end
	return words
end

local downloading, download_failed = false, false

-- Downloads wordfreq in the background on first use, into a temporary file
-- renamed when complete, then loads again. Until then the dictionary has
-- only the user's and the chat words.
local function download_wordfreq()
	if downloading or download_failed then
		return
	end
	downloading = true
	local tmp = M.wordfreq_file .. "." .. vim.fn.getpid() .. ".tmp"
	vim.system({ "curl", "-sfL", "--create-dirs", "--remove-on-error", "-o", tmp, WORDFREQ_URL }, {}, function(result)
		vim.schedule(function()
			downloading = false
			if result.code == 0 and vim.uv.fs_rename(tmp, M.wordfreq_file) then
				M.load()
			else
				vim.uv.fs_unlink(tmp)
				download_failed = true
				vim.notify("pro-prose: could not download the wordfreq list", vim.log.levels.WARN)
			end
		end)
	end)
end

-- The wordfreq entries, or nil when the file is missing or damaged. A
-- damaged file is deleted, so the next load downloads it again.
local function read_wordfreq()
	if vim.fn.filereadable(M.wordfreq_file) == 0 then
		return nil
	end
	local ok, entries = pcall(vim.json.decode, vim.fn.readblob(M.wordfreq_file))
	if ok and type(entries) == "table" and #entries > 0 then
		return entries
	end
	vim.uv.fs_unlink(M.wordfreq_file)
	return nil
end

-- Rebuilds the compiled spell file when the chat list is newer than it.
function M.build_spellfile()
	local chat_time = vim.fn.getftime(M.chat_file)
	if chat_time < 0 or vim.fn.getftime(M.chat_spellfile .. ".spl") >= chat_time then
		return
	end
	local list = {}
	for _, line in ipairs(read_lines(M.chat_file)) do
		table.insert(list, line:match("^(%S+)\t"))
	end
	vim.fn.writefile(list, M.chat_spellfile)
	vim.cmd("silent mkspell! " .. vim.fn.fnameescape(M.chat_spellfile))
end

function M.load()
	vim.fn.mkdir(M.data_dir, "p")
	-- Keep this session's uses: they are saved before the counts are re-read.
	M.save_usage()

	score, trusted, display = {}, {}, {}
	local wordfreq = read_wordfreq()
	if wordfreq then
		for _, entry in ipairs(wordfreq) do
			-- wordfreq also lists numbers and single letters; keep words only.
			if type(entry[1]) == "string" and entry[1]:find("^%a%a") then
				raise(entry[1], entry[2])
			end
		end
	else
		download_wordfreq()
	end
	for _, line in ipairs(read_lines(M.chat_file)) do
		local word, count = line:match("^(%S+)\t(%d+)$")
		if word then
			raise(word:lower(), CHAT_BASE + math.log(tonumber(count)) + CHAT_BONUS)
			trusted[word:lower()] = true
		end
	end
	for _, word in ipairs(user_words()) do
		local key = word:lower()
		raise(key, USER_SCORE)
		trusted[key] = true
		if word ~= key then
			display[key] = word
		end
	end

	sorted = vim.tbl_keys(score)
	table.sort(sorted, function(a, b)
		return score[a] > score[b]
	end)
	usage = read_usage()
end

-- Whether the user's or the chat list has the word, which makes it spelled
-- right even when the spell checker does not know it.
function M.is_trusted(word)
	return trusted[word:lower()] == true
end

-- Whether the word is fit to suggest: trusted, or accepted by the spell
-- checker (with the current window's 'spelllang').
local function spelled_right(word)
	return trusted[word] or #vim.spell.check(word) == 0
end

local function uses(key)
	return (usage[key] or 0) + (added[key] or 0)
end

-- A word's full score, or nil for a word not in the dictionary.
function M.score(word)
	local key = word:lower()
	return score[key] and score[key] + USAGE_WEIGHT * math.log(1 + uses(key))
end

-- Counts one use of a word in the dictionary. Other words are never
-- recorded: the plugin does not learn new words, it only reorders known ones.
function M.use(word)
	local key = word:lower()
	if score[key] then
		added[key] = (added[key] or 0) + 1
	end
end

-- Adds this session's uses to the counts on disk (which other Neovims may
-- have updated meanwhile), through a temporary file renamed over the old
-- one, so a crash mid-write cannot leave a broken file.
function M.save_usage()
	if next(added) == nil then
		return
	end
	local merged = read_usage()
	for key, n in pairs(added) do
		merged[key] = (merged[key] or 0) + n
	end
	local tmp = M.usage_file .. "." .. vim.fn.getpid() .. ".tmp"
	if vim.fn.writefile({ vim.json.encode(merged) }, tmp) == 0 and vim.uv.fs_rename(tmp, M.usage_file) then
		usage, added = merged, {}
	else
		vim.uv.fs_unlink(tmp)
	end
end

-- Up to `limit` words starting with `prefix` (lowercase), best first, each in
-- the spelling to insert ("GitHub" rather than "github").
function M.complete(prefix, limit)
	-- Gather a wider set in static order, then sort it with usage counted.
	local matches = {}
	for _, word in ipairs(sorted) do
		if word ~= prefix and vim.startswith(word, prefix) and spelled_right(word) then
			table.insert(matches, word)
			if #matches == limit * 10 then
				break
			end
		end
	end
	table.sort(matches, function(a, b)
		return M.score(a) > M.score(b)
	end)
	return vim.tbl_map(function(word)
		return display[word] or word
	end, vim.list_slice(matches, 1, limit))
end

function M.count()
	return #sorted
end

return M
