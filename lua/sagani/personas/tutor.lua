--- ==============================================================================
--- Module: sagani.personas.tutor
---
--- Description:
---   Tutor Prompt Persona strategy for sagani.nvim. Provides pedagogical explanation
---   prompts and breakdown instructions sent TO agents.
---
--- Responsibilities:
---   - Expose Tutor Persona metadata contract (id, name, icon, prompt_prefix, default_instructions).
---   - Decorate input prompts with educational breakdown guidance (`decorate_prompt`).
--- ==============================================================================

local M = {
  id = "tutor",
  name = "Tutor Persona",
  icon = "🎓",
  prompt_prefix = "Learning Mode Active: Provide a clear educational breakdown of the core concepts, syntax, architectural decisions, and trade-offs.",
  default_instructions = "Break down core concepts, syntax, architectural decisions, and trade-offs in an educational tutor format.",
}

--- Decorates user prompt string with Tutor Persona guidance
--- @param prompt string User prompt or instruction
--- @return string Formatted prompt string with tutor guidance banner
function M:decorate_prompt(prompt)
  prompt = type(prompt) == "string" and prompt or ""
  return string.format("\n\n> 🎓 **%s**\n\n%s", self.prompt_prefix, prompt)
end

return M
