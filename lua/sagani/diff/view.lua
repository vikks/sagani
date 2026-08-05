--- ==============================================================================
--- Module: sagani.diff.view
---
--- Description:
---   Side-by-side split review window manager and inline virtual text highlight renderer
---   for sagani.nvim diff review system.
---
--- Responsibilities:
---   - Render inline virtual lines for deleted code & highlights for added code.
---   - Manage side-by-side split review window lifecycles and diff synchronization.
---   - Provide toggle_review, open_review, and close_review window lifecycle methods.
--- ==============================================================================

local notify = require("sagani.notify")
local baseline = require("sagani.diff.baseline")
local hunks = require("sagani.diff.hunks")

local M = {
  _review_wins = {},
  _inline_active = {},
}

local ns_inline = vim.api.nvim_create_namespace("sagani_inline_review")

--- Renders inline horizontal review (virtual lines for deleted code & highlights for added code).
--- @param bufnr number|nil Buffer handle.
--- @param opts table|nil Configuration options.
--- @return boolean True if inline review rendered.
function M.render_inline_review(bufnr, opts)
  opts = type(opts) == "table" and opts or {}
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()

  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_inline, 0, -1)
  end

  local hunk_list = hunks.get_hunks(bufnr)
  if #hunk_list == 0 then
    M._inline_active[bufnr] = nil
    notify.info("No pending changes to review", opts)
    return false
  end

  for _, h in ipairs(hunk_list) do
    if h.ca > 0 and #h.orig_lines > 0 then
      local virt_lines = {}
      for _, orig_line in ipairs(h.orig_lines) do
        table.insert(virt_lines, { { "- " .. orig_line, "DiffDelete" } })
      end
      local target_line = math.max(0, h.start_line - 1)
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_inline, target_line, 0, {
        virt_lines = virt_lines,
        virt_lines_above = true,
      })
    end

    if h.cb > 0 then
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      local start_idx = math.max(0, h.start_line - 1)
      local end_idx = math.min(line_count, h.end_line)
      for l = start_idx, end_idx - 1 do
        pcall(vim.api.nvim_buf_add_highlight, bufnr, ns_inline, "DiffAdd", l, 0, -1)
      end
    end
  end

  M._inline_active[bufnr] = true
  notify.info(string.format("Agent edit inline review active: %d hunk(s) pending review (<leader>ay Accept, <leader>ax Reject)", #hunk_list), opts)
  return true
end

--- Closes review mode (inline highlights & split windows) for buffer if active.
--- @param bufnr number|nil Buffer handle.
--- @param opts table|nil Options.
--- @return boolean True if closed.
function M.close_review(bufnr, opts)
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()
  local closed = false

  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns_inline, 0, -1)
    if M._inline_active[bufnr] then
      M._inline_active[bufnr] = nil
      closed = true
    end
  end

  local review_info = M._review_wins[bufnr]
  if review_info then
    pcall(function()
      if review_info.orig_win and vim.api.nvim_win_is_valid(review_info.orig_win) then
        vim.wo[review_info.orig_win].diff = false
        vim.wo[review_info.orig_win].scrollbind = false
        vim.wo[review_info.orig_win].cursorbind = false
      end
      if review_info.peer_win and vim.api.nvim_win_is_valid(review_info.peer_win) then
        vim.wo[review_info.peer_win].diff = false
        vim.api.nvim_win_close(review_info.peer_win, true)
      end
      if review_info.peer_buf and vim.api.nvim_buf_is_valid(review_info.peer_buf) then
        vim.api.nvim_buf_delete(review_info.peer_buf, { force = true })
      end
    end)
    M._review_wins[bufnr] = nil
    closed = true
  end

  if closed then
    notify.info("Review mode closed", opts)
  end
  return closed
end

--- Opens review mode ("inline" or "split") for buffer diff inspection.
--- @param bufnr number|nil Buffer handle.
--- @param opts table|nil Configuration options.
--- @param mode string|nil "inline", "split", or nil (uses opts.review.mode or "inline").
--- @return boolean True if review opened.
function M.open_review(bufnr, opts, mode)
  opts = type(opts) == "table" and opts or {}
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()

  local review_opts = type(opts.review) == "table" and opts.review or {}
  mode = (type(mode) == "string" and mode ~= "") and mode:lower() or (review_opts.mode or "inline")

  if mode == "split" then
    local review_info = M._review_wins[bufnr]
    if review_info and review_info.peer_win and vim.api.nvim_win_is_valid(review_info.peer_win) then
      return true
    end

    local orig_win = vim.api.nvim_get_current_win()
    local base_lines = baseline.get_baseline_lines(bufnr)

    local peer_buf = vim.api.nvim_create_buf(false, true)
    local file_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
    if file_name == "" then file_name = "[No Name]" end
    vim.api.nvim_buf_set_name(peer_buf, "[Baseline Original] " .. file_name)
    vim.api.nvim_buf_set_lines(peer_buf, 0, -1, false, base_lines)
    vim.bo[peer_buf].filetype = vim.bo[bufnr].filetype
    vim.bo[peer_buf].buftype = "nofile"

    vim.cmd("leftabove vsplit")
    local peer_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(peer_win, peer_buf)

    -- Execute diffthis on both windows to enable diff, scrollbind, and cursorbind synchronization
    vim.cmd("diffthis")
    vim.api.nvim_set_current_win(orig_win)
    vim.cmd("diffthis")
    vim.cmd("diffupdate")

    M._review_wins[bufnr] = {
      peer_win = peer_win,
      peer_buf = peer_buf,
      orig_win = orig_win,
    }

    local hunk_list = hunks.get_hunks(bufnr)
    notify.info(string.format("Agent edit split review active: %d hunk(s) pending review (<leader>ay Accept, <leader>ax Reject)", #hunk_list), opts)
    return true
  else
    return M.render_inline_review(bufnr, opts)
  end
end

--- Toggles review mode ("inline" or "split") for buffer diff inspection.
--- @param bufnr number|nil Buffer handle.
--- @param opts table|nil Configuration options.
--- @param mode string|nil Mode override ("inline", "split", or nil).
--- @return boolean True if review opened, false if closed.
function M.toggle_review(bufnr, opts, mode)
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()
  if M._review_wins[bufnr] or M._inline_active[bufnr] then
    M.close_review(bufnr, opts)
    return false
  else
    return M.open_review(bufnr, opts, mode)
  end
end

return M
