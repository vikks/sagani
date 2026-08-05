local M = {
  _active_wins = {},
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

return M
