--- ==============================================================================
--- Module: sagani.format.input.instructions
---
--- Description:
---   Task instructions and system prompt formatter for sagani.nvim. Formats task-specific
---   system instructions for ask, review, code, and chat tasks.
---
--- Responsibilities:
---   - Resolve and format task system instructions (`build_task_instructions`).
--- ==============================================================================

local M = {}

--- Formats system prompt instructions for a given task type
--- @param task_type string Task identifier ("ask", "review", "code", "chat")
--- @param opts table|nil Configuration options
--- @return string System instructions string
function M.build_task_instructions(task_type, opts)
  opts = type(opts) == "table" and opts or {}
  local task_config = opts.tasks and opts.tasks[task_type]

  if type(task_config) == "table" and task_config.instructions then
    return task_config.instructions
  end

  local defaults = {
    ask = "Answer the user's question concisely and accurately.",
    review = "Review the provided code changes and offer actionable feedback.",
    code = "Fulfill the user's coding request directly in the buffer.",
    chat = "You are an AI coding agent assistant.",
  }

  return defaults[task_type] or defaults.chat
end

return M
