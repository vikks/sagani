local notify = require("sagani.notify")

local M = {
  _active_win = nil,
  _active_buf = nil,
  _popup_buffers = {},
}

--- Detects native Neovim backend environment
--- @return table { active, id, metadata }
function M.detect_env(_)
  return { active = true, id = "native", metadata = { name = "Neovim Native" } }
end

--- Discovers active or fallback target window handle for native backend
--- @param opts table Options table
--- @return string target_id, string|nil err, table metadata
function M.discover_target(opts)
  opts = type(opts) == "table" and opts or {}
  if opts.pane_override then
    return opts.pane_override, nil, { override = true }
  end
  if M._active_win and vim.api.nvim_win_is_valid(M._active_win) then
    return tostring(M._active_win), nil, { active = true }
  end
  return "native:split", nil, { default = true }
end

--- Spawns a native split or tab pane
--- @param opts table Options table
--- @return string win_id_str, string|nil err, table metadata
function M.spawn_pane(opts)
  opts = type(opts) == "table" and opts or {}
  local backend_lib = require("sagani.backend")
  local agent = (opts.target_agent or "agy"):lower()
  local agent_cmd = (opts.agent_opts and backend_lib.resolve_agent_cmd(opts.agent_opts)) or agent
  local placement = (type(opts.placement) == "string" and opts.placement ~= "") and opts.placement:lower() or "rightbelow vsplit"

  local cmd_split = "rightbelow vsplit"
  if placement == "left" or placement == "leftsplit" or placement == "left-pane" then
    cmd_split = "leftabove vsplit"
  elseif placement == "right" or placement == "rightsplit" or placement == "right-pane" then
    cmd_split = "rightbelow vsplit"
  elseif placement == "top" or placement == "topsplit" or placement == "top-pane" or placement == "up" then
    cmd_split = "leftabove split"
  elseif placement == "bottom" or placement == "bottomsplit" or placement == "bottom-pane" or placement == "down" then
    cmd_split = "rightbelow split"
  elseif placement == "vsplit" then
    cmd_split = "vsplit"
  elseif placement == "hsplit" or placement == "split" then
    cmd_split = "split"
  elseif placement == "tab" or placement == "new-tab" then
    cmd_split = "tabnew"
  end

  vim.cmd(cmd_split)
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)

  M._active_win = win
  M._active_buf = buf

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_name(buf, string.format("[%s-agent]", agent))

  local win_id_str = tostring(win)

  if not _G.RUNNING_TEST_SUITE and vim.fn.executable(agent_cmd:match("^%S+")) == 1 then
    vim.fn.termopen(agent_cmd)
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

--- Spawns or reuses a floating window for the native backend
--- @param opts table Options table
--- @return string win_id_str, string|nil err, table metadata
function M.spawn_popup(opts)
  opts = type(opts) == "table" and opts or {}
  local agent = (opts.target_agent or "agy"):lower()
  local ui_opts = opts.ui_opts or {}

  local w_spec = ui_opts.width or 0.8
  local h_spec = ui_opts.height or 0.8
  local width = type(w_spec) == "number" and (w_spec <= 1 and math.floor(vim.o.columns * w_spec) or math.floor(w_spec)) or math.floor(vim.o.columns * 0.8)
  local height = type(h_spec) == "number" and (h_spec <= 1 and math.floor(vim.o.lines * h_spec) or math.floor(h_spec)) or math.floor(vim.o.lines * 0.8)

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = M._popup_buffers[agent]
  local is_new = false

  if opts.reset and buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    buf = nil
  end

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    M._popup_buffers[agent] = buf
    is_new = true
  end

  local border = ui_opts.border or (opts.backends and opts.backends.native and opts.backends.native.border) or "rounded"

  local win = nil
  if M._active_win and vim.api.nvim_win_is_valid(M._active_win) and vim.api.nvim_win_get_buf(M._active_win) == buf then
    win = M._active_win
    vim.api.nvim_set_current_win(win)
  else
    win = vim.api.nvim_open_win(buf, true, {
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
  end

  M._active_win = win
  M._active_buf = buf

  if ui_opts.winblend and type(ui_opts.winblend) == "number" and ui_opts.winblend > 0 then
    pcall(function() vim.wo[win].winblend = ui_opts.winblend end)
  end

  local win_id_str = tostring(win)

  if is_new then
    pcall(function()
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].bufhidden = "hide"
      vim.bo[buf].swapfile = false
    end)

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
  end

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, false) end
  end, { buffer = buf, silent = true, desc = "Close Sagani popup window (preserves session)" })

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, false) end
  end, { buffer = buf, silent = true, desc = "Close Sagani popup window (preserves session)" })

  vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>:hide<CR>", { buffer = buf, silent = true, desc = "Hide Sagani popup window (preserves session)" })

  return win_id_str, nil, { spawned = true, is_popup = true }
end

--- Prompts target window/buffer
--- @param target_id string Target window handle string
--- @param prompt_text string Text to send
--- @param opts table Options table
--- @return boolean ok, string|nil err
function M.prompt_target(target_id, prompt_text, opts)
  opts = type(opts) == "table" and opts or {}

  if _G.RUNNING_TEST_SUITE then
    return true, nil
  end

  local win = tonumber(target_id)
  local buf = win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) or M._active_buf

  if buf and vim.api.nvim_buf_is_valid(buf) then
    local channel = vim.bo[buf].channel
    if channel and channel > 0 then
      vim.api.nvim_chan_send(channel, prompt_text .. "\n")
    else
      local lines = vim.split(prompt_text, "\n")
      local count = vim.api.nvim_buf_line_count(buf)
      vim.api.nvim_buf_set_lines(buf, count, count, false, lines)
    end
    return true, nil
  end

  return false, "Invalid target window/buffer for native backend"
end

--- Waits for terminal buffer readiness in native window
--- @param target_id string Target window handle string
--- @param opts table Options table
--- @return boolean ready
function M.wait_for_ready(target_id, opts)
  opts = type(opts) == "table" and opts or {}
  if _G.RUNNING_TEST_SUITE then
    return true
  end

  local win = tonumber(target_id)
  local buf = win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) or M._active_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return true
  end

  local timeout = opts.timeout_ms or 15000
  local start_time = (vim.loop and vim.loop.now and vim.loop.now()) or 0

  while true do
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    if text:match("(Tip:|esc to cancel|ctrl%+g|>|Gemini|Opencode|Codex|Hermes)") then
      return true
    end

    local now = (vim.loop and vim.loop.now and vim.loop.now()) or (start_time + timeout + 1)
    if (now - start_time) >= timeout then
      return true
    end

    if vim.wait then
      vim.wait(200)
    else
      break
    end
  end

  return true
end

--- Resets session popup buffer for an agent harness
--- @param agent string|nil Agent harness name
function M.reset_popup(agent)
  agent = (agent or "agy"):lower()
  local buf = M._popup_buffers[agent]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  M._popup_buffers[agent] = nil
end

return M
