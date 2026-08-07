--- ==============================================================================
--- Module: sagani.format.input
---
--- Description:
---   Input formatters package facade for sagani.nvim. Aggregates all input prompt
---   formatters (context, diff, instructions, modes).
---
--- Responsibilities:
---   - Re-export build_context_prompt, build_diff_prompt, build_task_instructions, and get_mode_prefix.
--- ==============================================================================

local context = require("sagani.format.input.context")
local diff = require("sagani.format.input.diff")
local instructions = require("sagani.format.input.instructions")
local modes = require("sagani.format.input.modes")

local M = {
  build_context_prompt = context.build_context_prompt,
  build_diff_prompt = diff.build_diff_prompt,
  build_task_instructions = instructions.build_task_instructions,
  get_mode_prefix = modes.get_mode_prefix,
}

return M
