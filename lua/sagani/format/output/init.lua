--- ==============================================================================
--- Module: sagani.format.output
---
--- Description:
---   Output formatters package facade for sagani.nvim. Aggregates all output UI and
---   response formatters (popup, markdown, error).
---
--- Responsibilities:
---   - Re-export build_popup_header, build_turn_banner, build_action_footer, clean_markdown_response, and format_error.
--- ==============================================================================

local popup = require("sagani.format.output.popup")
local markdown = require("sagani.format.output.markdown")
local err_mod = require("sagani.format.output.error")

local M = {
  build_popup_header = popup.build_popup_header,
  build_turn_banner = popup.build_turn_banner,
  build_action_footer = popup.build_action_footer,
  clean_markdown_response = markdown.clean_markdown_response,
  extract_code_blocks = markdown.extract_code_blocks,
  format_error = err_mod.format_error,
}

return M
