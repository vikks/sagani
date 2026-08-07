--- ==============================================================================
--- Module: sagani.personas.refactor
---
--- Description:
---   Refactor Prompt Persona strategy for sagani.nvim. Provides clean code,
---   SOLID design principles, and restructuring guidance sent TO agents.
---
--- Responsibilities:
---   - Expose Refactor Persona metadata contract (id, name, icon, prompt_prefix, default_instructions).
---   - Decorate input prompts with refactoring guidance (`decorate_prompt`).
--- ==============================================================================

local M = {
  id = "refactor",
  name = "Refactor Persona",
  icon = "🛠️",
  prompt_prefix = "Refactor Persona Active: Propose clean refactoring improvements adhering to SOLID principles and clean architecture.",
  default_instructions = "Refactor code to improve readability, maintainability, and adherence to SOLID principles.",
}

--- Decorates user prompt string with Refactor Persona guidance
--- @param prompt string User prompt or instruction
--- @return string Formatted prompt string with refactoring guidance banner
function M:decorate_prompt(prompt)
  prompt = type(prompt) == "string" and prompt or ""
  return string.format("\n\n> 🛠️ **%s**\n\n%s", self.prompt_prefix, prompt)
end

return M
