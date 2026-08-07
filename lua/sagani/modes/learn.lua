--- ==============================================================================
--- Module: sagani.modes.learn
---
--- Description:
---   Learning Mode strategy for sagani.nvim. Provides pedagogical explanation prompts,
---   breakdown instructions, and UI layout preferences for learning code concepts.
---
--- Responsibilities:
---   - Expose Learning Mode metadata contract (id, name, icon, prompt_prefix, default_instructions).
---   - Decorate input prompts with educational breakdown guidance (`decorate_prompt`).
--- ==============================================================================

local M = {
  id = "learn",
  name = "Learning Mode",
  icon = "🎓",
  prompt_prefix = "Learning Mode Active: Provide a clear educational breakdown of the core concepts, syntax, architectural decisions, and trade-offs.",
  default_instructions = "Break down core concepts, syntax, architectural decisions, and trade-offs in an educational format.",
  ui_placement = "split",
}

--- Decorates user prompt string with Learning Mode educational guidance
--- @param prompt string User prompt or instruction
--- @return string Formatted prompt string with educational guidance banner
function M:decorate_prompt(prompt)
  prompt = type(prompt) == "string" and prompt or ""
  return string.format("\n\n> 🎓 **%s**\n\n%s", self.prompt_prefix, prompt)
end

return M
