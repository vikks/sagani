--- ==============================================================================
--- Module: sagani.format.output.error
---
--- Description:
---   Output error message formatter for sagani.nvim. Formats diagnostic error
---   and warning messages for notifications and popup windows.
---
--- Responsibilities:
---   - Format diagnostic error strings (`format_error`).
--- ==============================================================================

local M = {}

--- Formats a diagnostic error message
--- @param err string Error description
--- @param context string|nil Context string
--- @return string Formatted error message string
function M.format_error(err, context)
  context = (type(context) == "string" and context ~= "") and (" (" .. context .. ")") or ""
  return string.format("sagani.nvim: %s%s", tostring(err or "Unknown error"), context)
end

return M
