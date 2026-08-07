return {
	"mfussenegger/nvim-jdtls",
	enable = not require("nixCatsUtils").enableForCategory("require-mason"),
	ft = "java",
	keys = {
		{
			"<leader>rm",
			function()
				require("jdtls").extract_method({ visual = true })
			end,
			mode = "v",
			desc = "Jdtls: [R]efactor [m]thod",
		},
	},
}
