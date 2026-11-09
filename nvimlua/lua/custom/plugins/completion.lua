local function setup_prose_words(cmp)
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
end

----------

return {
	{ -- Autocompletion
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			-- Snippet Engine & its associated nvim-cmp source
			{
				"L3MON4D3/LuaSnip",
				name = "luasnip",
				build = (function()
					-- Build Step is needed for regex support in snippets.
					-- This step is not supported in many windows environments.
					-- Remove the below condition to re-enable on windows.
					if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then
						return
					end
					return "make install_jsregexp"
				end)(),
				dependencies = {
					-- `friendly-snippets` contains a variety of premade snippets.
					--    See the README about individual language/framework/plugin snippets:
					--    https://github.com/rafamadriz/friendly-snippets
					{
						"rafamadriz/friendly-snippets",
						config = function()
							require("luasnip.loaders.from_vscode").lazy_load()
						end,
					},
				},
			},
			"saadparwaiz1/cmp_luasnip",

			-- Adds other completion capabilities.
			--  nvim-cmp does not ship with all sources by default. They are split
			--  into multiple repos for maintenance purposes.
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-nvim-lsp-signature-help",
		},
		config = function()
			-- See `:help cmp`
			local cmp = require("cmp")
			local luasnip = require("luasnip")
			luasnip.config.setup({})

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				completion = { completeopt = "menu,menuone,noinsert" },

				-- For an understanding of why these mappings were
				-- chosen, you will need to read `:help ins-completion`
				--
				-- No, but seriously. Please read `:help ins-completion`, it is really good!
				mapping = cmp.mapping.preset.insert({
					-- -- Select the [n]ext item
					-- ['<C-n>'] = cmp.mapping.select_next_item(),
					-- -- Select the [p]revious item
					-- ['<C-p>'] = cmp.mapping.select_prev_item(),
					--
					-- -- Scroll the documentation window [b]ack / [f]orward
					-- ['<C-b>'] = cmp.mapping.scroll_docs(-4),
					-- ['<C-f>'] = cmp.mapping.scroll_docs(4),
					--
					-- -- Accept ([y]es) the completion.
					-- --  This will auto-import if your LSP supports it.
					-- --  This will expand snippets if the LSP sent a snippet.
					-- ['<C-y>'] = cmp.mapping.confirm { select = true },

					-- If you prefer more traditional completion keymaps,
					-- you can uncomment the following lines
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<Tab>"] = cmp.mapping.select_next_item(),
					["<S-Tab>"] = cmp.mapping.select_prev_item(),

					-- Manually trigger a completion from nvim-cmp.
					--  Generally you don't need this, because nvim-cmp will display
					--  completions whenever it has completion options available.
					["<C-Space>"] = cmp.mapping.complete({}),

					-- Think of <c-l> as moving to the right of your snippet expansion.
					--  So if you have a snippet that's like:
					--  function $name($args)
					--    $body
					--  end
					--
					-- <c-l> will move you to the right of each of the expansion locations.
					-- <c-h> is similar, except moving you backwards.
					["<C-l>"] = cmp.mapping(function()
						if luasnip.expand_or_locally_jumpable() then
							luasnip.expand_or_jump()
						end
					end, { "i", "s" }),
					["<C-h>"] = cmp.mapping(function()
						if luasnip.locally_jumpable(-1) then
							luasnip.jump(-1)
						end
					end, { "i", "s" }),

					-- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
					--    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
				}),
				sources = {
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "path" },
					{ name = "nvim_lsp_signature_help" },
				},
			})

			-- English word completion in prose files. The advanced version (generated
			-- code) adds autocorrect and learned ranking; false gives the basic list.
			local pro_prose = true
			if pro_prose then
				local pro = require("custom.gen-plugins.pro-prose-complete")
				-- After your own spell file, which "zg" keeps writing to.
				vim.opt.spellfile:append(pro.spellfile)
				pro.enable(cmp)
			else
				setup_prose_words(cmp)
			end
		end,
	},
}
