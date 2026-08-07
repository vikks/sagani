--- ==============================================================================
--- Module: sagani.modes.edit_review
---
--- Description:
---   Edit Review Operational Mode strategy for sagani.nvim. Controls interactive buffer
---   edit diff review views, inline virtual text highlights, side-by-side diff splits,
---   hunk navigation (<leader>a]/[), and change acceptance/rejection (<leader>ay/x).
---
--- Responsibilities:
---   - Expose Edit Review Operational Mode metadata contract (id, name, icon, description).
---   - Delegate diff review operations to sagani.diff module.
--- ==============================================================================

local diff = require("sagani.diff")

local M = {
  id = "edit_review",
  name = "Edit Review Mode",
  icon = "🔍",
  description = "Interactive buffer edit diff review mode (inline virtual text or side-by-side split review with accept/reject workflow)",
}

--- Toggles or opens Edit Review Mode for current buffer
--- @param bufnr number|nil Buffer handle
--- @param opts table|nil Options
--- @param mode_arg string|nil Display mode ("inline" or "split")
function M.toggle(bufnr, opts, mode_arg)
  return diff.toggle_review(bufnr, opts, mode_arg)
end

--- Accepts current hunk or all pending changes
--- @param target string|nil "hunk" or "all"
--- @param bufnr number|nil Buffer handle
--- @param opts table|nil Options
function M.accept(target, bufnr, opts)
  return diff.accept_change(target, bufnr, opts)
end

--- Reverts current hunk or all pending changes
--- @param target string|nil "hunk" or "all"
--- @param bufnr number|nil Buffer handle
--- @param opts table|nil Options
function M.reject(target, bufnr, opts)
  return diff.reject_change(target, bufnr, opts)
end

return M
