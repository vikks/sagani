local M = {}

--- Formats a context prompt string containing user instruction and visual code selection.
--- @param user_instruction string|nil Optional user instruction or prompt.
--- @param selection table|nil Table containing selection metadata (file_path, start_line, end_line, filetype, snippet).
--- @return string Formatted markdown string.
function M.build_context_prompt(user_instruction, selection)
  selection = type(selection) == "table" and selection or {}

  local file_path = (type(selection.file_path) == "string" and selection.file_path ~= "") and selection.file_path or "[No Name]"
  local filetype = (type(selection.filetype) == "string" and selection.filetype ~= "") and selection.filetype or "text"
  local snippet = type(selection.snippet) == "string" and selection.snippet or ""

  local start_line = type(selection.start_line) == "number" and selection.start_line or 1
  local end_line = type(selection.end_line) == "number" and selection.end_line or start_line

  local line_range
  if start_line == end_line then
    line_range = "L" .. tostring(start_line)
  else
    line_range = string.format("L%d-L%d", start_line, end_line)
  end

  local instruction = (type(user_instruction) == "string" and user_instruction ~= "") and user_instruction or "Context snippet for review:"

  return string.format(
    "%s\n\nContext from `%s` (%s):\n```%s\n%s\n```",
    instruction,
    file_path,
    line_range,
    filetype,
    snippet
  )
end

--- Formats a diff review prompt string containing user comment and diff hunk information.
--- @param user_comment string|nil Optional user review comment.
--- @param diff_info table|nil Table containing diff metadata (file_path, start_line, end_line, diff_text).
--- @return string Formatted markdown diff prompt string.
function M.build_diff_prompt(user_comment, diff_info)
  diff_info = type(diff_info) == "table" and diff_info or {}

  local file_path = (type(diff_info.file_path) == "string" and diff_info.file_path ~= "") and diff_info.file_path or "[No Name]"
  local start_line = type(diff_info.start_line) == "number" and diff_info.start_line or 1
  local end_line = type(diff_info.end_line) == "number" and diff_info.end_line or start_line
  local diff_text = type(diff_info.diff_text) == "string" and diff_info.diff_text or ""

  local line_range
  if start_line == end_line then
    line_range = "L" .. tostring(start_line)
  else
    line_range = string.format("L%d-L%d", start_line, end_line)
  end

  local comment = (type(user_comment) == "string" and user_comment ~= "") and user_comment or "Diff review comment:"

  return string.format(
    "%s\n\nDiff Context from `%s` (%s):\n```diff\n%s\n```",
    comment,
    file_path,
    line_range,
    diff_text
  )
end

return M
