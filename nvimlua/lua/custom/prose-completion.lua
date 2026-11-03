local cmp = require("cmp")

local wordfreq = vim.fn.stdpath("data") .. "/dict/wordfreq-en-25000.json"
if vim.fn.filereadable(wordfreq) == 0 then
	vim.fn.system({
		"curl",
		"-sfL",
		"--create-dirs",
		"--remove-on-error",
		"-o",
		wordfreq,
		"https://raw.githubusercontent.com/aparrish/wordfreq-en-25000/9650fa612e121beb6126b9b4d7344da287013c6e/wordfreq-en-25000-log.json",
	})
end
-- Each entry is { word, log frequency }, most common first.
local words = vim.tbl_map(function(entry)
	return entry[1]
end, vim.json.decode(vim.fn.readblob(wordfreq)))

cmp.register_source("common_words", {
	get_keyword_pattern = function()
		return [[\a\+]]
	end,
	complete = function(_, request, callback)
		local typed = request.context.cursor_before_line:sub(request.offset)
		local prefix = typed:lower()
		local items = {}
		for _, word in ipairs(words) do
			if word ~= prefix and vim.startswith(word, prefix) then
				-- Keep a capital first letter, as at the start of a sentence.
				local label = typed:find("^%u") and (word:gsub("^%l", string.upper)) or word
				table.insert(items, { label = label, insertText = label .. " " })
				if #items == 20 then
					break
				end
			end
		end
		-- Ask again on each key press, since only 20 matches are returned.
		callback({ items = items, isIncomplete = true })
	end,
})

cmp.setup.filetype({ "markdown", "gitcommit", "text" }, {
	sources = {
		{ name = "common_words", keyword_length = 2 },
		{ name = "path" },
	},
	-- Keep the source's frequency order.
	sorting = { comparators = { cmp.config.compare.order } },
})
