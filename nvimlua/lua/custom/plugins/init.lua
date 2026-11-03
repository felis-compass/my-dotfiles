-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
	require("custom.plugins.markdown"),
	require("custom.plugins.conform"),
	require("custom.plugins.other"),
	require("custom.plugins.fastapi"),
	require("custom.plugins.git-tools"),
	require("custom.plugins.completion"),

	require("custom.plugins.ai"),
	require("custom.plugins.ai-proprietary-only"),
}
