return {
	"rgroli/other.nvim",
	enabled = require("nixCatsUtils").enableForCategory("general"),
	keys = {
		{
			"<leader>so",
			"<cmd>:Other<CR>",
			mode = "n",
			desc = "[S]earch [o]ther",
		},
	},
	config = function()
		require("other-nvim").setup({
			mappings = {
				"livewire",
				"angular",
				"laravel",
				"rails",
				"golang",
				"python",
				"react",
				"rust",
			},

			style = { border = "rounded" },
		})
	end,
}
