--- ==============================================================================
--- Module: sagani.modes.refactor
---
--- Description:
---   Refactor Mode strategy for sagani.nvim. Provides clean code refactoring,
---   SOLID design principles, and code restructuring guidance for refactoring tasks.
---
--- Responsibilities:
---   - Expose Refactor Mode metadata contract (id, name, icon, prompt_prefix, default_instructions).
---   - Decorate input prompts with refactoring guidance (`decorate_prompt`).
--- ==============================================================================

local M = {
  id = "refactor",
  name = "Refactor Mode",
  icon = "🛠️",
  prompt_prefix = "Refactor Mode Active: Propose clean refactoring improvements adhering to SOLID principles and clean architecture.",
  default_instructions = "Refactor code to improve readability, maintainability, and adherence to SOLID principles.",
  ui_placement = "vsplit",
}

--- Decorates user prompt string with Refactor Mode guidance
--- @param prompt string User prompt or instruction
--- @return string Formatted prompt string with refactoring guidance banner
function M:decorate_prompt(prompt)
  prompt = type(prompt) == "string" and prompt or ""
  return string.format("\n\n> 🛠️ **%s**\n\n%s", self.prompt_prefix, prompt)
end

return M
