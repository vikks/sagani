--- ==============================================================================
--- Module: sagani.diff.actions
---
--- Description:
---   Edit hunk acceptance and reversion actions for sagani.nvim diff review system.
---
--- Responsibilities:
---   - Apply edit hunk acceptance to baseline snapshots (accept_change).
---   - Revert edit hunks back to baseline lines or revert full buffer (reject_change).
--- ==============================================================================

local notify = require("sagani.notify")
local baseline = require("sagani.diff.baseline")
local hunks = require("sagani.diff.hunks")
local view = require("sagani.diff.view")

local M = {}

--- Accepts agent edit changes (hunk under cursor or all changes in buffer).
--- @param target string|nil "hunk", "all", or nil.
--- @param bufnr number|nil Buffer handle.
--- @param opts table|nil Options.
--- @return boolean Success flag.
function M.accept_change(target, bufnr, opts)
  opts = type(opts) == "table" and opts or {}
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()
  target = type(target) == "string" and target:lower() or "hunk"

  local hunk_list = hunks.get_hunks(bufnr)
  if #hunk_list == 0 then
    notify.info("No pending changes to accept", opts)
    view.close_review(bufnr, opts)
    return true
  end

  if target == "all" then
    local cur_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    baseline._snapshots[bufnr] = cur_lines
    view.close_review(bufnr, opts)
    notify.info("Accepted all changes in buffer", opts)
    return true
  end

  local cur_win = vim.api.nvim_get_current_win()
  local cur_line = vim.api.nvim_win_get_cursor(cur_win)[1]
  local target_hunk = nil
  for _, h in ipairs(hunk_list) do
    if h.cb > 0 then
      if cur_line >= h.start_line and cur_line <= h.end_line then
        target_hunk = h
        break
      end
    else
      if cur_line == h.start_line then
        target_hunk = h
        break
      end
    end
  end

  if not target_hunk then
    if target == "hunk" then
      notify.warn("No change hunk under cursor position", opts)
      return false
    end
    return M.accept_change("all", bufnr, opts)
  end

  -- Apply hunk acceptance to baseline snapshot
  local base_lines = baseline.get_baseline_lines(bufnr)
  local new_base = {}
  for l = 1, target_hunk.sa - 1 do
    table.insert(new_base, base_lines[l])
  end
  for _, nl in ipairs(target_hunk.new_lines) do
    table.insert(new_base, nl)
  end
  for l = target_hunk.sa + target_hunk.ca, #base_lines do
    table.insert(new_base, base_lines[l])
  end

  baseline._snapshots[bufnr] = new_base
  local remaining_hunks = hunks.get_hunks(bufnr)
  if #remaining_hunks == 0 then
    view.close_review(bufnr, opts)
  else
    if view._inline_active[bufnr] then
      view.render_inline_review(bufnr, opts)
    else
      local review_info = view._review_wins[bufnr]
      if review_info and review_info.peer_buf and vim.api.nvim_buf_is_valid(review_info.peer_buf) then
        vim.api.nvim_buf_set_lines(review_info.peer_buf, 0, -1, false, new_base)
        pcall(vim.cmd, "diffupdate")
      end
    end
  end

  notify.info(string.format("Accepted change hunk #%d", target_hunk.index), opts)
  return true
end

--- Rejects agent edit changes (reverts hunk under cursor or all changes to baseline).
--- @param target string|nil "hunk", "all", or nil.
--- @param bufnr number|nil Buffer handle.
--- @param opts table|nil Options.
--- @return boolean Success flag.
function M.reject_change(target, bufnr, opts)
  opts = type(opts) == "table" and opts or {}
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()
  target = type(target) == "string" and target:lower() or "hunk"

  local hunk_list = hunks.get_hunks(bufnr)
  if #hunk_list == 0 then
    notify.info("No pending changes to reject", opts)
    view.close_review(bufnr, opts)
    return true
  end

  if target == "all" then
    local base_lines = baseline.get_baseline_lines(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, base_lines)
    view.close_review(bufnr, opts)
    notify.info("Rejected all changes: buffer reverted to baseline", opts)
    return true
  end

  local cur_win = vim.api.nvim_get_current_win()
  local cur_line = vim.api.nvim_win_get_cursor(cur_win)[1]
  local target_hunk = nil
  for _, h in ipairs(hunk_list) do
    if h.cb > 0 then
      if cur_line >= h.start_line and cur_line <= h.end_line then
        target_hunk = h
        break
      end
    else
      if cur_line == h.start_line then
        target_hunk = h
        break
      end
    end
  end

  if not target_hunk then
    if target == "hunk" then
      notify.warn("No change hunk under cursor position", opts)
      return false
    end
    return M.reject_change("all", bufnr, opts)
  end

  local start_idx = target_hunk.sb - 1
  local end_idx = (target_hunk.cb > 0) and (target_hunk.sb + target_hunk.cb - 1) or (target_hunk.sb - 1)
  vim.api.nvim_buf_set_lines(bufnr, start_idx, end_idx, false, target_hunk.orig_lines)

  local remaining_hunks = hunks.get_hunks(bufnr)
  if #remaining_hunks == 0 then
    view.close_review(bufnr, opts)
  end

  notify.info(string.format("Rejected change hunk #%d (reverted to baseline)", target_hunk.index), opts)
  return true
end

return M
