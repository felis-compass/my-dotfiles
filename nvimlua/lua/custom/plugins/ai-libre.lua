return {
	"olimorris/codecompanion.nvim",
	enabled = require("config.profiles").enabled("ai_libre"),
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		require("codecompanion").setup({
			interactions = {
				chat = {
					adapter = {
						name = "ollama",
						model = "qwen2.5-coder:7b"
					}
				},
				inline = {
					adapter = {
						name = "ollama",
						model = "qwen2.5-coder:7b"
					}
				}
			},


		})
	end,
}
