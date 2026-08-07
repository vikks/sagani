--- ==============================================================================
--- Module: sagani.format.output.markdown
---
--- Description:
---   Output Markdown text cleaner & code block extractor for sagani.nvim. Filters out
---   internal reasoning/thought parts, cleans raw markdown, and extracts fenced code blocks.
---
--- Responsibilities:
---   - Clean raw Markdown text responses (`clean_markdown_response`).
---   - Extract fenced code blocks (`extract_code_blocks`).
--- ==============================================================================

local M = {}

--- Cleans raw agent Markdown text responses, removing raw HTML tags or invalid artifacts
--- @param text string Raw text
--- @return string Cleaned markdown text
function M.clean_markdown_response(text)
  if type(text) ~= "string" or text == "" then
    return ""
  end

  local trimmed = vim.trim(text)
  -- If text starts with HTML web page tags, return clean error block
  if trimmed:lower():sub(1, 15):find("<!doctype") or trimmed:lower():sub(1, 6):find("<html") then
    return "⚠️ *Server returned an HTML web page instead of Markdown text response.*"
  end

  return trimmed
end

--- Extracts fenced code blocks from markdown response text
--- @param markdown_text string Markdown text
--- @return table Array of code block tables { filetype, code }
function M.extract_code_blocks(markdown_text)
  if type(markdown_text) ~= "string" or markdown_text == "" then
    return {}
  end

  local blocks = {}
  for ft, code in markdown_text:gmatch("```([%w_]*)\n(.-)\n```") do
    table.insert(blocks, {
      filetype = (ft ~= "") and ft or "text",
      code = code,
    })
  end

  return blocks
end

return M
