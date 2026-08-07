--- ==============================================================================
--- Module: sagani.modes.review
---
--- Description:
---   Review Mode strategy for sagani.nvim. Provides security audit, edge case, and
---   code quality review prompts and instructions for interactive review workflows.
---
--- Responsibilities:
---   - Expose Review Mode metadata contract (id, name, icon, prompt_prefix, default_instructions).
---   - Decorate input prompts with code audit review guidance (`decorate_prompt`).
--- ==============================================================================

local M = {
	id = "review",
	name = "Review Mode",
	icon = "🔍",
	prompt_prefix = "Review Mode Active: Perform a strict code review focusing on security vulnerabilities, edge cases, performance bottlenecks, and style.",
	default_instructions = "Review code changes for security vulnerabilities, edge cases, performance bottlenecks, and code style compliance.",
	ui_placement = "vsplit",
}

--- Decorates user prompt string with Review Mode audit guidance
--- @param prompt string User prompt or instruction
--- @return string Formatted prompt string with review audit guidance banner
function M:decorate_prompt(prompt)
	prompt = type(prompt) == "string" and prompt or ""
	return string.format("\n\n> 🔍 **%s**\n\n%s", self.prompt_prefix, prompt)
end

return M
