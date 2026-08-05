--- ==============================================================================
--- Module: sagani.diff.comment
---
--- Description:
---   Diff review comment formatting and prompt dispatch for sagani.nvim.
---
--- Responsibilities:
---   - Capture diff hunk at cursor position.
---   - Prompt user for comment instruction.
---   - Format structured markdown diff payload and dispatch to target agent.
--- ==============================================================================

local notify = require("sagani.notify")
local format = require("sagani.format")
local hunks = require("sagani.diff.hunks")

local M = {}

--- Send diff review comment to AGY.
--- @param opts table|nil Configuration options.
--- @return boolean True if comment process started/sent, false if cancelled or error.
function M.send_diff_comment(opts)
  opts = type(opts) == "table" and opts or {}

  local diff_info = hunks.get_diff_hunk_at_cursor()
  if not diff_info or not diff_info.diff_text or diff_info.diff_text == "" then
    notify.warn("No diff hunk found at cursor position", opts)
    return false
  end

  local agent_name = ((opts and opts.target_agent) or "agy"):upper()
  vim.ui.input({ prompt = string.format("%s Diff Comment: ", agent_name), default = "" }, function(input)
    if input == nil then
      notify.info("Diff comment cancelled", opts)
      return
    end

    local payload = format.build_diff_prompt(input, diff_info)
    local main = require("sagani")
    local dispatch_opts = vim.tbl_deep_extend("force", opts or {}, { task_type = "review" })
    main.dispatch_prompt(payload, nil, dispatch_opts)
  end)

  return true
end

return M
