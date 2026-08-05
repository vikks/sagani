local M = {
  _active_wins = {},
  _active_sessions = {},
}

--- Creates a clean native Markdown floating popup window
--- @param title string Window title
--- @param opts table|nil Options table (ui_opts width, height, border, winblend)
--- @return number win Window handle
--- @return number buf Buffer handle
function M.open(title, opts)
  opts = type(opts) == "table" and opts or {}
  local ui_opts = opts.ui_opts or {}

  local w_spec = ui_opts.width or 0.8
  local h_spec = ui_opts.height or 0.8
  local width = type(w_spec) == "number" and (w_spec <= 1 and math.floor(vim.o.columns * w_spec) or math.floor(w_spec)) or math.floor(vim.o.columns * 0.8)
  local height = type(h_spec) == "number" and (h_spec <= 1 and math.floor(vim.o.lines * h_spec) or math.floor(h_spec)) or math.floor(vim.o.lines * 0.8)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local border = ui_opts.border or "rounded"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = border,
    title = string.format(" %s ", title),
    title_pos = "center",
  })

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

  if ui_opts.winblend and type(ui_opts.winblend) == "number" and ui_opts.winblend > 0 then
    pcall(function() vim.wo[win].winblend = ui_opts.winblend end)
  end

  pcall(function()
    vim.wo[win].wrap = true
    vim.wo[win].conceallevel = 2
  end)

  -- Buffer-local keymaps
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
  end, { buffer = buf, silent = true, desc = "Close Markdown popup" })

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
  end, { buffer = buf, silent = true, desc = "Close Markdown popup" })

  -- Copy full buffer response to clipboard ('yr')
  vim.keymap.set("n", "yr", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    vim.fn.setreg("+", text)
    vim.notify("Copied agent response to clipboard", vim.log.levels.INFO, { title = "sagani.nvim" })
  end, { buffer = buf, silent = true, desc = "Copy full response to clipboard" })

  -- Follow-up question keymaps (<CR>, r, i)
  local function prompt_followup()
    local ctx = M._active_sessions[buf]
    local harness = (ctx and ctx.harness) or "AGY"
    vim.ui.input({ prompt = string.format("Follow-up question (%s): ", harness:upper()) }, function(input)
      if input and input ~= "" then
        M.send_followup(buf, input)
      end
    end)
  end

  vim.keymap.set("n", "<CR>", prompt_followup, { buffer = buf, silent = true, desc = "Ask follow-up question" })
  vim.keymap.set("n", "r", prompt_followup, { buffer = buf, silent = true, desc = "Reply / Ask follow-up question" })
  vim.keymap.set("n", "i", prompt_followup, { buffer = buf, silent = true, desc = "Ask follow-up question" })

  -- Promote floating popup to split/tab keymaps (<C-w>h/j/k/l/t)
  vim.keymap.set("n", "<C-w>h", function() M.promote(buf, "left") end, { buffer = buf, silent = true, desc = "Promote popup to left split" })
  vim.keymap.set("n", "<C-w>H", function() M.promote(buf, "left") end, { buffer = buf, silent = true, desc = "Promote popup to left split" })
  vim.keymap.set("n", "<C-w>l", function() M.promote(buf, "right") end, { buffer = buf, silent = true, desc = "Promote popup to right split" })
  vim.keymap.set("n", "<C-w>L", function() M.promote(buf, "right") end, { buffer = buf, silent = true, desc = "Promote popup to right split" })
  vim.keymap.set("n", "<C-w>k", function() M.promote(buf, "top") end, { buffer = buf, silent = true, desc = "Promote popup to top split" })
  vim.keymap.set("n", "<C-w>K", function() M.promote(buf, "top") end, { buffer = buf, silent = true, desc = "Promote popup to top split" })
  vim.keymap.set("n", "<C-w>j", function() M.promote(buf, "bottom") end, { buffer = buf, silent = true, desc = "Promote popup to bottom split" })
  vim.keymap.set("n", "<C-w>J", function() M.promote(buf, "bottom") end, { buffer = buf, silent = true, desc = "Promote popup to bottom split" })
  vim.keymap.set("n", "<C-w>t", function() M.promote(buf, "tab") end, { buffer = buf, silent = true, desc = "Promote popup to new tab" })
  vim.keymap.set("n", "<C-w>T", function() M.promote(buf, "tab") end, { buffer = buf, silent = true, desc = "Promote popup to new tab" })

  -- Interactive window promotion menu (a / <leader>a / <localleader>a)
  local function prompt_promote_menu()
    local choices = {
      "h: Left Split",
      "l: Right Split",
      "k: Top Split",
      "j: Bottom Split",
      "t: New Tab Page",
      "q: Cancel",
    }
    vim.ui.select(choices, { prompt = "Promote / Move Window To:" }, function(choice)
      if not choice then return end
      local key = choice:sub(1, 1):lower()
      if key == "h" then M.promote(buf, "left")
      elseif key == "l" then M.promote(buf, "right")
      elseif key == "k" then M.promote(buf, "top")
      elseif key == "j" then M.promote(buf, "bottom")
      elseif key == "t" then M.promote(buf, "tab")
      end
    end)
  end

  vim.keymap.set("n", "a", prompt_promote_menu, { buffer = buf, silent = true, desc = "Promote window menu (h/l/k/j/t)" })
  vim.keymap.set("n", "<leader>a", prompt_promote_menu, { buffer = buf, silent = true, desc = "Promote window menu (h/l/k/j/t)" })
  vim.keymap.set("n", "<localleader>a", prompt_promote_menu, { buffer = buf, silent = true, desc = "Promote window menu (h/l/k/j/t)" })

  M._active_wins[buf] = win
  return win, buf
end

--- Promotes a floating popup window to a split or tab page
--- @param buf number|nil Buffer handle
--- @param placement string|nil Target placement ("left", "right", "top", "bottom", "tab")
--- @return number|nil new_win Created window handle
function M.promote(buf, placement)
  buf = buf or vim.api.nvim_get_current_buf()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return nil
  end

  placement = (type(placement) == "string" and placement ~= "") and placement:lower() or "right"

  -- Ensure bufhidden is set to hide so buffer isn't wiped when floating window closes
  vim.bo[buf].bufhidden = "hide"

  local win = M._active_wins[buf] or vim.api.nvim_get_current_win()
  if win and vim.api.nvim_win_is_valid(win) then
    local config = vim.api.nvim_win_get_config(win)
    if config and config.relative and config.relative ~= "" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  local cmd = "rightbelow vsplit"
  if placement == "left" or placement == "left-split" or placement == "left-pane" then
    cmd = "leftabove vsplit"
  elseif placement == "right" or placement == "right-split" or placement == "right-pane" then
    cmd = "rightbelow vsplit"
  elseif placement == "top" or placement == "top-split" or placement == "top-pane" then
    cmd = "leftabove split"
  elseif placement == "bottom" or placement == "bottom-split" or placement == "bottom-pane" then
    cmd = "rightbelow split"
  elseif placement == "tab" or placement == "new-tab" then
    cmd = "tabnew"
  end

  vim.cmd(cmd)
  local new_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(new_win, buf)
  M._active_wins[buf] = new_win
  return new_win
end

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
    if not l:find("Press <CR> or 'r' to ask a follow%-up question") then
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
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    vim.api.nvim_buf_set_lines(buf, count, count, false, lines)
  end
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
  local new_lines = {}
  local replaced = false

  for i = #lines, 1, -1 do
    if lines[i]:find("^⏳") then
      lines[i] = response_text
      table.insert(lines, "")
      table.insert(lines, "> 💡 *Press <CR> or 'r' to reply | 'a' to promote window (h/j/k/l/t) | 'yr' to copy | 'q' to close*")
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

return M
