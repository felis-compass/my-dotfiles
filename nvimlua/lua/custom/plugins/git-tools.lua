return {
	{
		"dlyongemallo/diffview-plus.nvim",
		version = "*",
		lazy = false,
		keys = {
			{ "<leader>td", "<cmd>DiffviewToggle<CR>", desc = "[T]oggle [D]iffview" },
		},
		config = function()
			require("diffview").setup({})

			require("telescope").setup({
				defaults = {
					get_selection_window = function()
						if require("diffview.lib").get_current_view() then
							vim.cmd("DiffviewClose")
						end
						return vim.api.nvim_get_current_win()
					end,
				},
			})
		end,
	},
	{
		"rbong/vim-flog",
		lazy = true,
		cmd = { "Flog", "Flogsplit", "Floggit" },
		dependencies = {
			"tpope/vim-fugitive",
		},
	},
}
