local notify = require("sagani.notify")

local M = {
  name = "native",
  capabilities = {
    ask = true,
    review = true,
    code = true,
    chat = true,
  },
}

-- Native session state tracking
M._active_win = nil
M._active_buf = nil

function M.detect_env(_)
  return {
    active = true,
    id = "nvim_native",
    metadata = { is_native = true },
  }
end

function M.discover_target(opts)
  opts = type(opts) == "table" and opts or {}
  if opts.pane_override then
    return tostring(opts.pane_override), nil, {}
  end
  if M._active_win and vim.api.nvim_win_is_valid(M._active_win) then
    return tostring(M._active_win), nil, { is_popup = false }
  end
  return nil, "No active native agent target window found", {}
end

function M.spawn_pane(opts)
  opts = type(opts) == "table" and opts or {}
  local agent = (opts.target_agent or "agy"):lower()
  local placement = opts.placement or "vsplit"

  if placement == "popup" or placement == "floating" then
    return M.spawn_popup(opts)
  end

  local split_cmd = "vnew"
  if placement == "tab" or placement == "new-tab" then
    split_cmd = "tabnew"
  elseif placement == "hsplit" or placement == "bottom-pane" or placement == "down" then
    split_cmd = "new"
  elseif opts.backends and opts.backends.native and opts.backends.native.split_direction == "horizontal" then
    split_cmd = "new"
  end

  vim.cmd(split_cmd)

  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_get_current_buf()

  M._active_win = win
  M._active_buf = buf

  -- Set buffer options
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_name(buf, string.format("[%s-agent]", agent))

  local win_id_str = tostring(win)

  -- If executable agent binary exists and not in test suite, spawn terminal job inside buffer
  if not _G.RUNNING_TEST_SUITE and vim.fn.executable(agent) == 1 then
    vim.fn.termopen(agent)
  else
    local welcome = {
      string.format("--- Native Sagani Agent Pane (%s) ---", agent:upper()),
      "Ready to receive context, prompts, and diff feedback.",
      "",
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, welcome)
  end

  return win_id_str, nil, { spawned = true, is_popup = false }
end

function M.spawn_popup(opts)
  opts = type(opts) == "table" and opts or {}
  local agent = (opts.target_agent or "agy"):lower()

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local border = (opts.backends and opts.backends.native and opts.backends.native.popup_border) or "rounded"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = border,
    title = string.format(" Sagani Agent Popup (%s) ", agent:upper()),
    title_pos = "center",
  })

  M._active_win = win
  M._active_buf = buf

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"

  local win_id_str = tostring(win)

  if not _G.RUNNING_TEST_SUITE and vim.fn.executable(agent) == 1 then
    vim.fn.termopen(agent)
  else
    local welcome = {
      string.format("--- Sagani Popup Window (%s) ---", agent:upper()),
      "Type prompt or selection context below:",
      "",
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, welcome)
  end

  return win_id_str, nil, { spawned = true, is_popup = true }
end

function M.prompt_target(target_id, prompt_text, opts)
  opts = type(opts) == "table" and opts or {}

  if _G.RUNNING_TEST_SUITE then
    return true, nil
  end

  local win = tonumber(target_id)
  local buf = win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) or M._active_buf

  if buf and vim.api.nvim_buf_is_valid(buf) then
    -- Check if it's a terminal buffer
    local channel = vim.bo[buf].channel
    if channel and channel > 0 then
      vim.api.nvim_chan_send(channel, prompt_text .. "\n")
    else
      -- Plain text display buffer
      local lines = vim.split(prompt_text, "\n")
      table.insert(lines, 1, string.format(">>> [%s] PROMPT:", os.date("%H:%M:%S")))
      table.insert(lines, "")
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
    end
    return true, nil
  end

  -- Auto spawn if target not found
  local spawned_id, err, _ = M.spawn_popup(opts)
  if spawned_id then
    return M.prompt_target(spawned_id, prompt_text, opts)
  end

  return false, err or "Failed to access native target buffer"
end

return M
