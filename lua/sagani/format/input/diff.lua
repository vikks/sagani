--- ==============================================================================
--- Module: sagani.format.input.diff
---
--- Description:
---   Input diff prompt formatter for sagani.nvim. Transforms git diff hunks, range
---   line metadata, and user commentary into unified Markdown diff blocks sent TO agents.
---
--- Responsibilities:
---   - Format Markdown diff review prompt strings (`build_diff_prompt`).
---   - Inject file references and line range commentary.
--- ==============================================================================

local M = {}

--- Formats a diff review prompt string containing user comment and diff hunk information.
--- @param user_comment string|nil Optional user review comment.
--- @param diff_info table|nil Table containing diff metadata (file_path, abs_path, start_line, end_line, diff_text).
--- @return string Formatted markdown diff prompt string.
function M.build_diff_prompt(user_comment, diff_info)
  diff_info = type(diff_info) == "table" and diff_info or {}

  local file_path = (type(diff_info.file_path) == "string" and diff_info.file_path ~= "") and diff_info.file_path or "[No Name]"
  local abs_path = (type(diff_info.abs_path) == "string" and diff_info.abs_path ~= "") and diff_info.abs_path or (file_path ~= "[No Name]" and file_path or "")
  local start_line = type(diff_info.start_line) == "number" and diff_info.start_line or 1
  local end_line = type(diff_info.end_line) == "number" and diff_info.end_line or start_line
  local diff_text = type(diff_info.diff_text) == "string" and diff_info.diff_text or ""

  local line_range
  if start_line == end_line then
    line_range = "L" .. tostring(start_line)
  else
    line_range = string.format("L%d-L%d", start_line, end_line)
  end

  local file_mention = ""
  if abs_path ~= "" and abs_path ~= "[No Name]" then
    file_mention = string.format(" @[%s#%s]", abs_path, line_range)
  end

  local comment = (type(user_comment) == "string" and user_comment ~= "") and user_comment or "Diff review comment:"

  return string.format(
    "%s%s\n\nDiff Context from `%s` (%s):\n```diff\n%s\n```",
    comment,
    file_mention,
    file_path,
    line_range,
    diff_text
  )
end

return M
