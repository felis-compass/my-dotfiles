return {
	"olimorris/codecompanion.nvim",
	enabled = require("config.profiles").enabled("ai_libre"),
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		require("codecompanion").setup({

			adapters = {
				qwen = function()
					return require("codecompanion.adapters").extend("ollama", {
						name = "qwen", -- Give this adapter a different name to differentiate it from the default ollama adapter
						schema = {
							model = {
								default = "qwen2.5-coder:14b",
							},
							-- num_ctx = {
							-- 	default = 16384,
							-- },
							-- num_predict = {
							-- 	default = -1,
							-- },
						},
					})
				end,
			},
			strategies = {
				chat = {
					adapter = "qwen",
				},
				inline = {
					adapter = "qwen",
				},
			},
		})
	end,
}
