return {
	{
		"dlyongemallo/diffview-plus.nvim",
		version = "*",
		lazy = false,
		keys = {
			{ "<leader>td", "<cmd>DiffviewToggle<CR>", desc = "[T]oggle [D]iffview" },
			{ "<leader>tr", "<cmd>DiffviewRefresh<CR>", desc = "Diffview: [r]efresh files" },
		},
		config = function()
			require("diffview").setup({
				keymaps = {
					file_panel = {
						{ "n", "cc", "<Cmd>botright Git commit<CR>", { desc = "Commit staged changes" } },
					},
				},
			})

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
		"tpope/vim-fugitive",
		cmd = { "Git", "G" },
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
