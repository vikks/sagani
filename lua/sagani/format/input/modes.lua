--- ==============================================================================
--- Module: sagani.format.input.modes
---
--- Description:
---   Operating mode educational banner decorator for sagani.nvim. Decorates input
---   prompts with educational guidance when active session modes (Learn, Refactor, Review)
---   are enabled.
---
--- Responsibilities:
---   - Resolve and format active mode banner prefixes (`get_mode_prefix`).
--- ==============================================================================

local M = {}

--- Formats active mode educational prompt prefix if learn mode is active
--- @return string Formatted mode banner string or empty string
function M.get_mode_prefix()
  local sagani = pcall(require, "sagani") and require("sagani") or {}
  local is_learn_mode = (sagani._session_mode == "learn")
    or (type(sagani.options) == "table" and type(sagani.options.modes) == "table" and type(sagani.options.modes.learn) == "table" and sagani.options.modes.learn.enabled)

  if is_learn_mode then
    local prefix = (type(sagani.options) == "table" and type(sagani.options.modes) == "table" and type(sagani.options.modes.learn) == "table" and sagani.options.modes.learn.prompt_prefix)
      or "Learning Mode Active: Provide a clear educational breakdown of the core concepts, syntax, architectural decisions, and trade-offs."
    return string.format("\n\n> 🎓 **%s**", prefix)
  end

  return ""
end

return M
