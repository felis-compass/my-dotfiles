return {
	-- require("custom.lsp.nvim-java"),

	{
		"rcasia/neotest-java",
		ft = "java",
		dependencies = {
			"mfussenegger/nvim-jdtls",
			"mfussenegger/nvim-dap", -- for debugging (optional)
			"rcarriga/nvim-dap-ui", -- recommended
			"theHamsta/nvim-dap-virtual-text", -- recommended
		},
	},
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/neotest-python",
		},
		config = function()
			require("neotest").setup({
				diagnostic = {
					enabled = true,
					severity = vim.diagnostic.severity.ERROR,
				},
				status = {
					virtual_text = true,
					signs = true,
				},
				adapters = {
					-- require("neotest-python")({
					-- 	dap = { justMyCode = false },
					-- }),
					require("neotest-java")({
						-- Optional configuration here
					}),
				},
			})
		end,
	},
	{ -- LSP Configuration & Plugins
		"neovim/nvim-lspconfig",
		dependencies = {
			-- Automatically install LSPs and related tools to stdpath for Neovim
			{ "mason-org/mason.nvim", config = true }, -- NOTE: Must be loaded before dependants
			{ "mason-org/mason-lspconfig.nvim" },
			{ "WhoIsSethDaniel/mason-tool-installer.nvim" },

			-- Useful status updates for LSP.
			-- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
			{ "j-hui/fidget.nvim", opts = {} },

			-- `neodev` configures Lua LSP for your Neovim config, runtime and plugins
			-- used for completion, annotations and signatures of Neovim apis
			{ "folke/lazydev.nvim", ft = "lua", opts = {} },
			{
				"nvim-java/nvim-java",
			},

			-- kickstart.nvim was still on neodev. lazydev is the new version of neodev
		},
		config = function()
			--  This function gets run when an LSP attaches to a particular buffer.
			--    That is to say, every time a new file is opened that is associated with
			--    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
			--    function will be executed to configure the current buffer
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
				callback = function(event)
					-- for LSP related items. It sets the mode, buffer and description for us each time.
					local map = function(keys, func, desc)
						vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
					end

					-- Jump to the definition of the word under your cursor.
					--  This is where a variable was first declared, or where a function is defined, etc.
					--  To jump back, press <C-t>.
					map("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")

					-- Find references for the word under your cursor.
					map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")

					-- Jump to the implementation of the word under your cursor.
					--  Useful when your language has ways of declaring types without an actual implementation.
					map("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")

					-- Jump to the type of the word under your cursor.
					--  Useful when you're not sure what type a variable is and you want to see
					--  the definition of its *type*, not where it was *defined*.
					map("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")

					-- Fuzzy find all the symbols in your current document.
					--  Symbols are things like variables, functions, types, etc.
					map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")

					-- Fuzzy find all the symbols in your current workspace.
					--  Similar to document symbols, except searches over your entire project.
					map(
						"<leader>ws",
						require("telescope.builtin").lsp_dynamic_workspace_symbols,
						"[W]orkspace [S]ymbols"
					)

					-- Rename the variable under your cursor.
					--  Most Language Servers support renaming across files, etc.
					map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")

					-- Execute a code action, usually your cursor needs to be on top of an error
					-- or a suggestion from your LSP for this to activate.
					map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")

					-- Opens a popup that displays documentation about the word under your cursor
					--  See `:help K` for why this keymap.
					map("K", vim.lsp.buf.hover, "Hover Documentation")

					-- WARN: This is not Goto Definition, this is Goto Declaration.
					--  For example, in C this would take you to the header.
					map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

					vim.keymap.set(
						"v",
						"<leader>ca",
						vim.lsp.buf.code_action,
						{ buffer = event.buf, desc = "LSP: [C]ode [A]ction" }
					)
					vim.keymap.set(
						"i",
						"<c-k>",
						vim.lsp.buf.signature_help,
						{ buffer = event.buf, desc = "LSP: Signature Help" }
					)

					-- The following two autocommands are used to highlight references of the
					-- word under your cursor when your cursor rests there for a little while.
					--    See `:help CursorHold` for information about when this is executed
					--
					-- When you move your cursor, the highlights will be cleared (the second autocommand).
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if client and client.server_capabilities.documentHighlightProvider then
						local highlight_augroup =
							vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})

						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = event.buf,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})

						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
							callback = function(event2)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
							end,
						})
					end

					-- The following autocommand is used to enable inlay hints in your
					-- code, if the language server you are using supports them
					--
					-- This may be unwanted, since they displace some of your code
					if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
						map("<leader>th", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
						end, "[T]oggle Inlay [H]ints")
					end
				end,
			})

			-- LSP servers and clients are able to communicate to each other what features they support.
			--  By default, Neovim doesn't support everything that is in the LSP specification.
			--  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
			--  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())
			-- `"*"` is a special config name: vim.lsp.config merges it into every other
			-- named config, so this applies to all servers below without looping by hand.
			vim.lsp.config("*", { capabilities = capabilities })

			-- Enable the following language servers
			--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
			--
			--  Add any additional override configuration in the following tables. Available keys are:
			--  - cmd (table): Override the default command used to start the server
			--  - filetypes (table): Override the default list of associated filetypes for the server
			--  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
			--  - settings (table): Override the default settings passed when initializing the server.
			--        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
			local servers = {}
			-- servers.rust_analyzer = {},
			-- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
			--
			-- Some languages (like typescript) have entire language plugins that can be useful:
			--    https://github.com/pmizio/typescript-tools.nvim
			--
			-- But for many setups, the LSP (`tsserver`) will work just fine
			-- servers.tsserver = {},
			--

			-- nixd isn't installable via mason. If it's already on $PATH (e.g. provided
			-- by home-manager/NixOS), prefer it; otherwise fall back to nil_ls via mason.
			if vim.fn.executable("nixd") == 1 then
				-- servers.nixd = {}
				vim.lsp.enable("nixd")
			else
				servers.nil_ls = {}
			end
			servers.lua_ls = {
				-- cmd = {...},
				-- filetypes = { ...},
				-- capabilities = {},
				settings = {
					Lua = {
						completion = {
							callSnippet = "Replace",
						},
						-- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
						diagnostics = {
							disable = { "missing-fields" },
						},
					},
				},
			}

			-- servers.pyright = {
			-- 	python = {
			-- 		analysis = {
			-- 			diagnosticMode = "workspace",
			-- 		},
			-- 	},
			-- }

			servers.pyrefly = {}

			servers.jdtls = {
				settings = {
					-- ["org.eclipse.jdt.core.compiler.problem.nullUncheckedConversion"] = "ignore",
					java = {
						compile = {
							nullAnalysis = {
								mode = "automatic", -- turn on analysis once jspecify is detected on the project classpath
								nonnull = {
									"org.jspecify.annotations.NonNull",
									"javax.annotation.Nonnull",
									"org.springframework.lang.NonNull",
									"org.eclipse.jdt.annotation.NonNull",
								},
								nullable = {
									"org.jspecify.annotations.Nullable",
									"javax.annotation.Nullable",
									"org.springframework.lang.Nullable",
									"org.eclipse.jdt.annotation.Nullable",
								},
								nonnullbydefault = {
									"org.jspecify.annotations.NullMarked",
									"javax.annotation.ParametersAreNonnullByDefault",
									"org.springframework.lang.NonNullApi",
									"org.eclipse.jdt.annotation.NonNullByDefault",
								},
							},
						},
					},
				},
			}

			servers.lemminx = {}

			servers.clangd = {}

			servers.html = {}

			servers.cssls = {}

			-- servers.astro = {}

			-- servers.angularls = {}

			servers.ts_ls = {
				filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact" },
			}

			servers.phpactor = {
				filetypes = { "php" },
				init_options = {
					["language_server_phpstan.enabled"] = false,
					["language_server_psalm.enabled"] = false,
				},
			}

			-- servers.gopls = {}
			--
			-- servers.hls = {
			-- 	-- cmd = { "haskell-language-server", "--lsp" },
			-- 	filetypes = { "haskell", "lhaskell", "cabal" },
			-- }

			servers.terraformls = {}

			-- Ensure the servers and tools above are installed
			--  To check the current status of installed tools and/or manually install
			--  other tools, you can run
			--    :Mason
			--
			--  You can press `g?` for help in this menu.
			require("mason").setup()

			-- You can add other tools here that you want Mason to install
			-- for you, so that they are available from within Neovim.
			local ensure_installed = vim.tbl_keys(servers or {})
			vim.list_extend(ensure_installed, {
				"stylua", -- Used to format Lua code
			})
			require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

			-- Register our overrides (settings/filetypes/init_options/etc.) for each server.
			-- Do this before mason-lspconfig.setup() below so its `automatic_enable` (on by
			-- default) picks up the merged config when it calls vim.lsp.enable() for us.
			for name, config in pairs(servers) do
				vim.lsp.config(name, config)
			end

			-- mason-lspconfig no longer takes a `handlers` table (that was the old
			-- require('lspconfig')-based API); it just keeps Mason-installed servers on the
			-- runtimepath and auto-enables them via vim.lsp.enable().
			require("mason-lspconfig").setup()
		end,
	},
}
