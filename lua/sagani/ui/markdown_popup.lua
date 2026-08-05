--- ==============================================================================
--- Module: sagani.ui.markdown_popup
---
--- Description:
---   Master facade for native Markdown floating UI popup windows in sagani.nvim.
---   Renders native floating popup windows for ACP protocol agent interactions, displaying
---   real-time streaming progress, user prompts, markdown responses, and session metadata.
---
--- Responsibilities:
---   - Delegate window creation to sagani.ui.markdown_popup.window.
---   - Delegate buffer content formatting to sagani.ui.markdown_popup.content.
---   - Delegate buffer keymaps to sagani.ui.markdown_popup.keymaps.
--- ==============================================================================

local window = require("sagani.ui.markdown_popup.window")
local content = require("sagani.ui.markdown_popup.content")
local keymaps = require("sagani.ui.markdown_popup.keymaps")

local M = setmetatable({
  _active_wins = window._active_wins,
  _active_sessions = content._active_sessions,
}, {
  __index = function(_, k)
    return window[k] or content[k] or keymaps[k]
  end,
})

--- Creates a clean native Markdown floating popup window
--- @param title string Window title
--- @param opts table|nil Options table (ui_opts width, height, border, winblend)
--- @return number win Window handle
--- @return number buf Buffer handle
function M.open(title, opts)
  opts = type(opts) == "table" and opts or {}
  local ui_opts = opts.ui_opts or {}
  local win, buf = window.open_float(title, ui_opts)
  keymaps.bind_popup_keymaps(buf, win, window)
  return win, buf
end

--- Promotes a floating popup window to a split or tab page
--- @param buf number|nil Buffer handle
--- @param placement string|nil Target placement ("left", "right", "top", "bottom", "tab")
--- @return number|nil new_win Created window handle
function M.promote(buf, placement)
  return window.promote(buf, placement)
end

--- Enters single-keypress Pin Mode for moving/promoting popup window
--- @param buf number Buffer handle
function M.enter_pin_mode(buf)
  return keymaps.enter_pin_mode(buf, window)
end

--- Stores session metadata for multi-turn follow-up queries
function M.set_session(buf, harness, session_id, agent_opts, opts)
  return content.set_session(buf, harness, session_id, agent_opts, opts)
end

--- Sends a follow-up query for an active session buffer
function M.send_followup(buf, prompt_text)
  return content.send_followup(buf, prompt_text)
end

--- Appends lines or text content to a Markdown buffer
function M.append_text(buf, text)
  return content.append_text(buf, text)
end

--- Formats prompt and initial header in Markdown popup
function M.set_prompt_header(buf, prompt_text, agent_name)
  return content.set_prompt_header(buf, prompt_text, agent_name)
end

--- Updates loading status message in Markdown popup
function M.update_status(buf, status_msg)
  return content.update_status(buf, status_msg)
end

--- Replaces loading text with actual response content and appends footer hint
function M.set_response(buf, response_text)
  return content.set_response(buf, response_text)
end

return M
