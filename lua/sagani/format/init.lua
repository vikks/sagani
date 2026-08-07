--- ==============================================================================
--- Module: sagani.format
---
--- Description:
---   Master formatters package facade for sagani.nvim. Aggregates input prompt
---   formatters (lua/sagani/format/input/) and output response formatters
---   (lua/sagani/format/output/) to provide 100% backwards compatibility for require("sagani.format").
---
--- Submodules:
---   - input:  Input prompt formatters (context, diff, instructions, modes).
---   - output: Output response formatters (popup headers, markdown cleanups, errors).
--- ==============================================================================

local input = require("sagani.format.input")
local output = require("sagani.format.output")

local M = {
  input = input,
  output = output,

  -- Re-exports for 100% backwards compatibility with require("sagani.format")
  build_context_prompt = input.build_context_prompt,
  build_diff_prompt = input.build_diff_prompt,
  build_task_instructions = input.build_task_instructions,
  get_mode_prefix = input.get_mode_prefix,

  build_popup_header = output.build_popup_header,
  build_turn_banner = output.build_turn_banner,
  build_action_footer = output.build_action_footer,
  clean_markdown_response = output.clean_markdown_response,
  extract_code_blocks = output.extract_code_blocks,
  format_error = output.format_error,
}

return M
