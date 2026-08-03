local M = {
  _active_wins = {},
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

  M._active_wins[buf] = win
  return win, buf
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

--- Replaces loading text with actual response content
--- @param buf number Buffer handle
--- @param response_text string Final or streaming response text
function M.set_response(buf, response_text)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local new_lines = {}
  local in_response = false

  for _, line in ipairs(lines) do
    if line:find("^### 🤖 Agent Response") then
      in_response = true
      table.insert(new_lines, line)
      table.insert(new_lines, "")
      for _, rline in ipairs(vim.split(response_text, "\n", { plain = true })) do
        table.insert(new_lines, rline)
      end
      break
    else
      table.insert(new_lines, line)
    end
  end

  if in_response then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
  else
    M.append_text(buf, response_text)
  end
end

return M
