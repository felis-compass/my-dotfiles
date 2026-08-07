local M = {}

-- Neovim "flavors": which optional feature set is active for this run.
--
-- The profile is picked automatically from $NVIM_APPNAME, so each flavor can
-- get its own isolated config/data/state/cache dir (see `:h nvim-appname`),
-- which is what lets you symlink the same config to e.g. ~/.config/nvim,
-- ~/.config/nvim-ai-libre and ~/.config/nvim-ai-nonfree and run them side by
-- side with independent plugin installs and lazy-lock.json files.
--
-- $NVIM_PROFILE overrides $NVIM_APPNAME if you just want to try a different
-- profile's plugin set without a separate data dir.
--
-- To add a new flavor:
--   1. add an entry to `profiles` below
--   2. gate a plugin spec's `enabled` field on `require("config.profiles").enabled("your_feature")`
--   3. symlink a new $NVIM_APPNAME config dir to this same source and (optionally) add a shell alias
-- See README.md for the symlink/alias/home-manager side of this.

---@class NvimProfile
---@field ai_libre boolean    -- olimorris/codecompanion.nvim (self-hosted models via Ollama)
---@field ai_nonfree boolean  -- Exafunction/windsurf.nvim (proprietary Codeium/Windsurf completion)

---@type table<string, NvimProfile>
local profiles = {
	nvim = { ai_libre = false, ai_nonfree = false },
	["nvim-ai-libre"] = { ai_libre = true, ai_nonfree = false },
	["nvim-ai-nonfree"] = { ai_libre = false, ai_nonfree = true },
}

local default_profile = "nvim"

---@type string
M.name = os.getenv("NVIM_PROFILE") or os.getenv("NVIM_APPNAME") or default_profile

---@type NvimProfile
M.features = profiles[M.name] or profiles[default_profile]

---@param feature string
---@return boolean
function M.enabled(feature)
	return M.features[feature] == true
end

return M
