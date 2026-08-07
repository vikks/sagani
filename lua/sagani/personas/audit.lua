--- ==============================================================================
--- Module: sagani.personas.audit
---
--- Description:
---   Auditor Prompt Persona strategy for sagani.nvim. Provides security audit,
---   edge case, and code quality review prompts sent TO agents.
---
--- Responsibilities:
---   - Expose Auditor Persona metadata contract (id, name, icon, prompt_prefix, default_instructions).
---   - Decorate input prompts with code audit review guidance (`decorate_prompt`).
--- ==============================================================================

local M = {
  id = "audit",
  name = "Auditor Persona",
  icon = "🔍",
  prompt_prefix = "Auditor Persona Active: Perform a strict code review focusing on security vulnerabilities, edge cases, performance bottlenecks, and style.",
  default_instructions = "Review code changes for security vulnerabilities, edge cases, performance bottlenecks, and code style compliance.",
}

--- Decorates user prompt string with Auditor Persona guidance
--- @param prompt string User prompt or instruction
--- @return string Formatted prompt string with auditor guidance banner
function M:decorate_prompt(prompt)
  prompt = type(prompt) == "string" and prompt or ""
  return string.format("\n\n> 🔍 **%s**\n\n%s", self.prompt_prefix, prompt)
end

return M
