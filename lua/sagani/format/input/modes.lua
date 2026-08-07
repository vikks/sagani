local personas_registry = require("sagani.personas")

local M = {}

--- Formats active persona or mode prompt prefix based on active session persona strategy
--- @param persona_override string|nil Optional persona identifier override
--- @return string Formatted persona banner string or empty string
function M.get_mode_prefix(persona_override)
  local sagani = pcall(require, "sagani") and require("sagani") or {}
  local active_persona = persona_override or sagani._session_persona or sagani._session_mode

  if not active_persona and type(sagani.options) == "table" and type(sagani.options.modes) == "table" and type(sagani.options.modes.learn) == "table" and sagani.options.modes.learn.enabled then
    active_persona = "tutor"
  end

  if not active_persona then
    return ""
  end

  local strategy = personas_registry.get_strategy(active_persona, sagani.options)
  if strategy and strategy.prompt_prefix then
    return string.format("\n\n> %s **%s**", strategy.icon or "⚙️", strategy.prompt_prefix)
  end

  return ""
end

return M
