local modes_registry = require("sagani.modes")

local M = {}

--- Formats active mode educational or operational prompt prefix based on active session mode strategy
--- @param mode_override string|nil Optional mode identifier override
--- @return string Formatted mode banner string or empty string
function M.get_mode_prefix(mode_override)
  local sagani = pcall(require, "sagani") and require("sagani") or {}
  local active_mode = mode_override or sagani._session_mode

  if not active_mode and type(sagani.options) == "table" and type(sagani.options.modes) == "table" and type(sagani.options.modes.learn) == "table" and sagani.options.modes.learn.enabled then
    active_mode = "learn"
  end

  if not active_mode then
    return ""
  end

  local strategy = modes_registry.get_strategy(active_mode, sagani.options)
  if strategy and strategy.prompt_prefix then
    return string.format("\n\n> %s **%s**", strategy.icon or "⚙️", strategy.prompt_prefix)
  end

  return ""
end

return M
