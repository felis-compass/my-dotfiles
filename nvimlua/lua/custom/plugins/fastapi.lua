return {
  "lucasdetoledo4/fastapi-nvim",
  ft           = "python",
  dependencies = { "nvim-telescope/telescope.nvim" },
  keys = {
    { "<leader>fa", function() require("fastapi-nvim").routes() end,  desc = "FastAPI: browse routes" },
    { "<leader>fA", function() require("fastapi-nvim").refresh() end, desc = "FastAPI: refresh routes" },
  },
  config = function()
    require("fastapi-nvim").setup()
  end,
}
