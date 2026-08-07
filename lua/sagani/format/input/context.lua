--- ==============================================================================
--- Module: sagani.format.input.context
---
--- Description:
---   Input context prompt formatter for sagani.nvim. Transforms visual code selection
---   snippets, file paths, line ranges, filetypes, and user instructions into Markdown
---   context payloads sent TO agents.
---
--- Responsibilities:
---   - Format visual code selection Markdown blocks (`build_context_prompt`).
---   - Inject file path references (`@[abs_path#L10-L20]`).
---   - Inject educational mode prompt prefixes.
--- ==============================================================================

local modes_formatter = require("sagani.format.input.modes")

local M = {}

--- Formats a context prompt string containing user instruction and visual code selection.
--- @param user_instruction string|nil Optional user instruction or prompt.
--- @param selection table|nil Table containing selection metadata (file_path, start_line, end_line, filetype, snippet).
--- @return string Formatted markdown string.
function M.build_context_prompt(user_instruction, selection)
  selection = type(selection) == "table" and selection or {}

  local file_path = (type(selection.file_path) == "string" and selection.file_path ~= "") and selection.file_path or "[No Name]"
  local abs_path = (type(selection.abs_path) == "string" and selection.abs_path ~= "") and selection.abs_path or (file_path ~= "[No Name]" and file_path or "")
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

  local file_mention = ""
  if abs_path ~= "" and abs_path ~= "[No Name]" then
    file_mention = string.format(" @[%s#%s]", abs_path, line_range)
  end

  local instruction = (type(user_instruction) == "string" and user_instruction ~= "") and user_instruction or "Context snippet for review:"
  local learn_prefix = modes_formatter.get_mode_prefix()

  return string.format(
    "%s%s%s\n\nContext from `%s` (%s):\n```%s\n%s\n```",
    instruction,
    learn_prefix,
    file_mention,
    file_path,
    line_range,
    filetype,
    snippet
  )
end

return M
