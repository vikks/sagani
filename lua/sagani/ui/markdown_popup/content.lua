--- ==============================================================================
--- Module: sagani.ui.markdown_popup.content
---
--- Description:
---   Buffer content renderer for sagani Markdown floating UI popups. Manages header
---   formatting, status updates, markdown body rendering, session history, and footer hints.
---
--- Responsibilities:
---   - Set prompt headers and status message indicators in popup buffers.
---   - Append streaming responses and markdown payloads.
---   - Manage session history state (_active_sessions) for follow-up questions.
--- ==============================================================================

local M = {
  _active_sessions = {},
}

M.STD_FOOTER_HINT = "> 💡 *Press <CR> or 'r' to reply | 'p' to pin window | 'yr' to copy | 'q' to close*"
M.PIN_FOOTER_HINT = "> 📌 *Pin window to: [h] Left | [l] Right | [k] Top | [j] Bottom | [t] Tab | [Esc/q] Cancel*"

--- Stores session metadata for multi-turn follow-up queries
--- @param buf number Buffer handle
--- @param harness string Agent harness
--- @param session_id string|nil Session ID
--- @param agent_opts table|nil Agent execution options
--- @param opts table|nil Window options
function M.set_session(buf, harness, session_id, agent_opts, opts)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  M._active_sessions[buf] = {
    harness = harness,
    session_id = session_id,
    agent_opts = agent_opts or {},
    opts = opts or {},
  }
end

--- Appends lines or text content to a Markdown buffer
--- @param buf number Buffer handle
--- @param text string Text to append
function M.append_text(buf, text)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.split(text, "\n", { plain = true })
  local count = vim.api.nvim_buf_line_count(buf)
  if count == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "" then
  end
end

--- Formats initial session header for a brand new Markdown popup buffer
--- @param buf number Buffer handle
--- @param agent_name string Agent harness name
function M.set_initial_session_header(buf, agent_name)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines > 1 or (lines[1] ~= "" and not lines[1]:find("^### 💬 Sagani Agent Session")) then
    return
  end

  local header = {
    string.format("### 💬 Sagani Agent Session (%s)", (agent_name or "AGY"):upper()),
    "",
    "> *Type your prompt in the box below and press <CR> to send.*",
    "",
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, header)
end

--- Formats prompt and initial header in Markdown popup
--- @param buf number Buffer handle
--- @param prompt_text string User prompt
--- @param agent_name string Agent harness name
function M.set_prompt_header(buf, prompt_text, agent_name)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local header = {
    string.format("### 👤 User Prompt (%s)", (agent_name or "AGY"):upper()),
    "",
    "> " .. prompt_text:gsub("\n", "\n> "),
    "",
    "---",
    "",
    string.format("### 🤖 Agent Response (%s)", (agent_name or "AGY"):upper()),
    "",
    "⏳ *Generating response...*",
  }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, header)
end

--- Updates loading status message in Markdown popup
--- @param buf number Buffer handle
--- @param status_msg string Status text
function M.update_status(buf, status_msg)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i = #lines, 1, -1 do
    if lines[i]:find("^⏳") then
      lines[i] = "⏳ *" .. status_msg .. "*"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      return
    end
  end
end

--- Replaces loading text with actual response content and appends footer hint
--- @param buf number Buffer handle
--- @param response_text string Final or streaming response text
function M.set_response(buf, response_text)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local replaced = false

  for i = #lines, 1, -1 do
    if lines[i]:find("^⏳") then
      lines[i] = response_text
      table.insert(lines, "")
      table.insert(lines, M.STD_FOOTER_HINT)
      replaced = true
      break
    end
  end

  if replaced then
    local final_lines = {}
    for _, l in ipairs(lines) do
      for _, sub_l in ipairs(vim.split(l, "\n", { plain = true })) do
        table.insert(final_lines, sub_l)
      end
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, final_lines)
  else
    M.append_text(buf, response_text)
  end
end

--- Sends a follow-up query for an active session buffer
--- @param buf number Buffer handle
--- @param prompt_text string Follow-up prompt
function M.send_followup(buf, prompt_text)
  local ctx = M._active_sessions[buf]
  if not ctx then
    vim.notify("No active session found for follow-up query", vim.log.levels.WARN, { title = "sagani.nvim" })
    return
  end

  local acp = require("sagani.protocol.acp")
  local notify = require("sagani.notify")

  -- Clean up old footer hint line before appending follow-up
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local clean_lines = {}
  for _, l in ipairs(lines) do
    if not l:find("Press <CR> or 'r'") and not l:find("^> [💡📌]") then
      table.insert(clean_lines, l)
    end
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, clean_lines)

  -- Append follow-up turn header
  local turn_header = {
    "",
    "---",
    "",
    string.format("### 👤 Follow-up Prompt (%s)", (ctx.harness or "AGY"):upper()),
    "",
    "> " .. prompt_text:gsub("\n", "\n> "),
    "",
    "---",
    "",
    string.format("### 🤖 Agent Response (%s)", (ctx.harness or "AGY"):upper()),
    "",
    "⏳ *Generating follow-up response...*",
  }

  local count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, count, count, false, turn_header)
  pcall(vim.cmd, "redraw")

  local progress_cb = function(status_msg)
    vim.schedule(function()
      M.update_status(buf, status_msg)
      pcall(vim.cmd, "redraw")
    end)
  end

  acp.execute_prompt(ctx.harness, prompt_text, ctx.agent_opts, function(resp, acp_err, session_id)
    if session_id then
      ctx.session_id = session_id
    end
    if resp then
      M.set_response(buf, resp)
      notify.info("Received follow-up response", ctx.opts)
    else
      M.set_response(buf, "❌ Error: " .. (acp_err or "Unknown error"))
      notify.error("Follow-up request failed: " .. (acp_err or "Unknown error"), ctx.opts)
    end
  end, ctx.opts, progress_cb, ctx.session_id)
end

return M
