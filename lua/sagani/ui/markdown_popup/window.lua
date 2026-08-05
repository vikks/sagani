--- ==============================================================================
--- Module: sagani.ui.markdown_popup.window
---
--- Description:
---   Floating window geometry math and creation engine for sagani Markdown popups.
---   Calculates centered floating window bounds based on screen dimensions and config options,
---   creates floating windows via nvim_open_win, and sets window options (wrap, winblend).
---
--- Responsibilities:
---   - Calculate floating window width, height, row, col placement.
---   - Create floating windows via vim.api.nvim_open_win.
---   - Manage active window handle tracking.
--- ==============================================================================

local M = {
  _active_wins = {},
  _session_buffers = {},
  _attached_layouts = {},
}

--- Calculates geometry and creates a floating window
--- @param title string Window title
--- @param ui_opts table UI options (width, height, border, winblend)
--- @return number win Window handle
--- @return number buf Buffer handle
function M.open_float(title, ui_opts)
  ui_opts = ui_opts or {}

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

  M._active_wins[buf] = win
  return win, buf
end

--- Promotes a floating window to a split or tab page
--- @param buf number Buffer handle
--- @param placement string Target placement ("left", "right", "top", "bottom", "tab")
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

--- Creates or focuses an attached Markdown floating popup layout
--- (Main response window + attached prompt input sub-window anchored to the bottom)
--- @param title string Window title
--- @param agent_name string Agent harness name (e.g. "opencode")
--- @param ui_opts table UI configuration options
--- @return number main_win Main Markdown response window handle
--- @return number main_buf Main Markdown response buffer handle
--- @return number input_win Attached input sub-window handle
--- @return number input_buf Attached input buffer handle
function M.open_attached_layout(title, agent_name, ui_opts)
  ui_opts = ui_opts or {}
  agent_name = (agent_name or "agy"):lower()

  local w_spec = ui_opts.width or 0.8
  local h_spec = ui_opts.height or 0.8
  local total_width = type(w_spec) == "number" and (w_spec <= 1 and math.floor(vim.o.columns * w_spec) or math.floor(w_spec)) or math.floor(vim.o.columns * 0.8)
  local total_height = type(h_spec) == "number" and (h_spec <= 1 and math.floor(vim.o.lines * h_spec) or math.floor(h_spec)) or math.floor(vim.o.lines * 0.8)

  local input_height = 1
  local main_height = math.max(5, total_height - input_height - 3)

  local row = math.floor((vim.o.lines - total_height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)
  local border = ui_opts.border or "rounded"

  -- 1. Main Markdown Buffer (persistent per agent harness)
  local main_buf = M._session_buffers[agent_name]
  if not main_buf or not vim.api.nvim_buf_is_valid(main_buf) then
    main_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[main_buf].buftype = "nofile"
    vim.bo[main_buf].bufhidden = "hide"
    vim.bo[main_buf].filetype = "markdown"
    vim.bo[main_buf].swapfile = false
    M._session_buffers[agent_name] = main_buf
    require("sagani.ui.markdown_popup.content").set_initial_session_header(main_buf, agent_name)
  end

  -- 2. Main Markdown Window
  local main_win = M._active_wins[main_buf]
  if main_win and vim.api.nvim_win_is_valid(main_win) then
    vim.api.nvim_set_current_win(main_win)
  else
    main_win = vim.api.nvim_open_win(main_buf, false, {
      relative = "editor",
      width = total_width,
      height = main_height,
      row = row,
      col = col,
      style = "minimal",
      border = border,
      title = string.format(" %s ", title),
      title_pos = "center",
    })
    M._active_wins[main_buf] = main_win
  end

  pcall(function()
    vim.wo[main_win].wrap = true
    vim.wo[main_win].conceallevel = 2
    if ui_opts.winblend and type(ui_opts.winblend) == "number" and ui_opts.winblend > 0 then
      vim.wo[main_win].winblend = ui_opts.winblend
    end
  end)

  -- 3. Check if existing attached input sub-window is already valid
  local existing_layout = M._attached_layouts[main_buf]
  local input_win = existing_layout and existing_layout.input_win
  local input_buf = existing_layout and existing_layout.input_buf

  if not input_buf or not vim.api.nvim_buf_is_valid(input_buf) then
    input_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[input_buf].buftype = "nofile"
    vim.bo[input_buf].bufhidden = "wipe"
    vim.bo[input_buf].swapfile = false
  end

  local input_row = row + main_height + 2
  if not input_win or not vim.api.nvim_win_is_valid(input_win) then
    input_win = vim.api.nvim_open_win(input_buf, true, {
      relative = "editor",
      width = total_width,
      height = input_height,
      row = input_row,
      col = col,
      style = "minimal",
      border = border,
      title = string.format(" 💬 Ask Agent (%s) [Press <CR> to submit | <Esc> for Normal mode] ", agent_name:upper()),
      title_pos = "center",
    })
  else
    vim.api.nvim_set_current_win(input_win)
  end

  if ui_opts.winblend and type(ui_opts.winblend) == "number" and ui_opts.winblend > 0 then
    pcall(function() vim.wo[input_win].winblend = ui_opts.winblend end)
  end

  M._attached_layouts[main_buf] = {
    main_win = main_win,
    main_buf = main_buf,
    input_win = input_win,
    input_buf = input_buf,
    agent_name = agent_name,
  }

  pcall(function()
    local group = vim.api.nvim_create_augroup("sagani_attached_layout_" .. tostring(main_buf), { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
      group = group,
      pattern = { tostring(main_win), tostring(input_win) },
      callback = function(ev)
        vim.schedule(function()
          M.close_layout(main_buf)
        end)
      end,
    })
  end)

  require("sagani.ui.markdown_popup.keymaps").bind_attached_keymaps(main_buf, main_win, input_buf, input_win, M)

  if not _G.RUNNING_TEST_SUITE then
    pcall(vim.cmd, "startinsert")
  end

  return main_win, main_buf, input_win, input_buf
end

--- Closes attached floating popup layout windows for a buffer
--- @param main_buf number|nil Main Markdown buffer handle
function M.close_layout(main_buf)
  main_buf = main_buf or vim.api.nvim_get_current_buf()
  local layout = M._attached_layouts[main_buf]

  if not layout then
    local cur_win = vim.api.nvim_get_current_win()
    local cur_buf = vim.api.nvim_get_current_buf()
    for b_handle, l_spec in pairs(M._attached_layouts) do
      if l_spec.main_win == cur_win or l_spec.input_win == cur_win or l_spec.input_buf == cur_buf or l_spec.main_buf == cur_buf then
        layout = l_spec
        main_buf = b_handle
        break
      end
    end
  end

  if layout then
    M._attached_layouts[main_buf] = nil
    M._active_wins[main_buf] = nil

    if layout.input_win and vim.api.nvim_win_is_valid(layout.input_win) then
      pcall(vim.api.nvim_win_close, layout.input_win, true)
    end
    if layout.main_win and vim.api.nvim_win_is_valid(layout.main_win) then
      pcall(vim.api.nvim_win_close, layout.main_win, true)
    end
  else
    local win = M._active_wins[main_buf] or vim.api.nvim_get_current_win()
    if win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
    M._active_wins[main_buf] = nil
  end
end

--- Resets persistent session buffer for an agent harness
--- @param agent_name string Agent harness identifier
function M.reset_session(agent_name)
  agent_name = (agent_name or "agy"):lower()
  local main_buf = M._session_buffers[agent_name]
  if main_buf and vim.api.nvim_buf_is_valid(main_buf) then
    M.close_layout(main_buf)
    pcall(vim.api.nvim_buf_delete, main_buf, { force = true })
  end
  M._session_buffers[agent_name] = nil
end

return M
