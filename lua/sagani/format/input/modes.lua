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

--- Formats active mode educational or operational prompt prefix based on active session mode
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

  local default_prefixes = {
    learn = "🎓 Learning Mode Active: Provide a clear educational breakdown of the core concepts, syntax, architectural decisions, and trade-offs.",
    review = "🔍 Review Mode Active: Perform a strict code review focusing on security vulnerabilities, edge cases, performance bottlenecks, and style.",
    refactor = "🛠️ Refactor Mode Active: Propose clean refactoring improvements adhering to SOLID principles and clean architecture.",
  }

  local custom_prefix = nil
  if type(sagani.options) == "table" and type(sagani.options.modes) == "table" and type(sagani.options.modes[active_mode]) == "table" then
    custom_prefix = sagani.options.modes[active_mode].prompt_prefix
  end

  local prefix = custom_prefix or default_prefixes[active_mode]
  if prefix then
    return string.format("\n\n> **%s**", prefix)
  end

  return string.format("\n\n> ⚙️ **%s Mode Active**", active_mode:sub(1, 1):upper() .. active_mode:sub(2))
end

return M
