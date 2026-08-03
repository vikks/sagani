local notify = require("sagani.notify")
local format = require("sagani.format")

local M = {}

M._snapshots = {}
M._review_wins = {}
M._inline_active = {}

local ns_inline = vim.api.nvim_create_namespace("sagani_inline_review")

--- Helper to split unified diff text into individual hunk blocks.
local function split_diff_hunks(diff_str)
  local hunks = {}
  local current_hunk = nil
  for line in (diff_str .. "\n"):gmatch("(.-)\r?\n") do
    if line:sub(1, 2) == "@@" then
      if current_hunk then
        table.insert(hunks, table.concat(current_hunk, "\n"))
      end
      current_hunk = { line }
    elseif current_hunk then
      table.insert(current_hunk, line)
    end
  end
  if current_hunk then
    table.insert(hunks, table.concat(current_hunk, "\n"))
  end
  return hunks
end

--- Takes baseline snapshot of current buffer content for review comparison.
--- @param bufnr number|nil Buffer handle (defaults to current buffer 0).
--- @return table Baseline lines array.
function M.take_snapshot(bufnr)
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  M._snapshots[bufnr] = lines
  return lines
end

--- Retrieves baseline lines array for buffer (from snapshot, git HEAD, or file on disk).
--- @param bufnr number|nil Buffer handle (defaults to current buffer 0).
--- @return table Baseline lines array.
function M.get_baseline_lines(bufnr)
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()
  if M._snapshots[bufnr] then
    return M._snapshots[bufnr]
  end

  local full_path = vim.api.nvim_buf_get_name(bufnr)
  if full_path ~= "" and vim.fn.executable("git") == 1 then
    local rel_path = vim.fn.fnamemodify(full_path, ":~:.")
    if rel_path ~= "" then
      local res = vim.system({ "git", "show", "HEAD:" .. rel_path }, { text = true }):wait()
      if res.code == 0 and res.stdout then
        local lines = {}
        for line in (res.stdout .. "\n"):gmatch("(.-)\r?\n") do
          table.insert(lines, line)
        end
        if #lines > 0 and lines[#lines] == "" then
          table.remove(lines)
        end
        M._snapshots[bufnr] = lines
        return lines
      end
    end
  end

  local cur_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  M._snapshots[bufnr] = cur_lines
  return cur_lines
end

--- Calculates hunks between baseline lines and current buffer lines.
--- @param bufnr number|nil Buffer handle.
--- @return table List of hunk objects { index, sa, ca, sb, cb, start_line, end_line, orig_lines, new_lines }.
function M.get_hunks(bufnr)
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()
  local cur_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local base_lines = M.get_baseline_lines(bufnr)

  local cur_text = table.concat(cur_lines, "\n")
  local base_text = table.concat(base_lines, "\n")

  if cur_text == base_text then
    return {}
  end

  local indices = vim.diff(base_text, cur_text, { result_type = "indices" })
  local hunks = {}
  if indices then
    for i, idx in ipairs(indices) do
      local sa, ca, sb, cb = idx[1], idx[2], idx[3], idx[4]
      local start_line, end_line
      if cb > 0 then
        start_line = sb
        end_line = sb + cb - 1
      else
        start_line = math.max(1, sb)
        end_line = math.max(1, sb)
      end

      local orig_slice = {}
      if ca > 0 then
        for l = sa, sa + ca - 1 do
          table.insert(orig_slice, base_lines[l] or "")
        end
      end

      local new_slice = {}
      if cb > 0 then
        for l = sb, sb + cb - 1 do
          table.insert(new_slice, cur_lines[l] or "")
        end
      end

      table.insert(hunks, {
        index = i,
        sa = sa,
        ca = ca,
        sb = sb,
        cb = cb,
        start_line = start_line,
        end_line = end_line,
        orig_lines = orig_slice,
        new_lines = new_slice,
      })
    end
  end
  return hunks
end

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

  local hunks = M.get_hunks(bufnr)
  if #hunks == 0 then
    M._inline_active[bufnr] = nil
    notify.info("No pending changes to review", opts)
    return false
  end

  for _, h in ipairs(hunks) do
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
  notify.info(string.format("Agent edit inline review active: %d hunk(s) pending review (<leader>ay Accept, <leader>ax Reject)", #hunks), opts)
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
    local base_lines = M.get_baseline_lines(bufnr)

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

    local hunks = M.get_hunks(bufnr)
    notify.info(string.format("Agent edit split review active: %d hunk(s) pending review (<leader>ay Accept, <leader>ax Reject)", #hunks), opts)
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

--- Accepts agent edit changes (hunk under cursor or all changes in buffer).
--- @param target string|nil "hunk", "all", or nil.
--- @param bufnr number|nil Buffer handle.
--- @param opts table|nil Options.
--- @return boolean Success flag.
function M.accept_change(target, bufnr, opts)
  opts = type(opts) == "table" and opts or {}
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()
  target = type(target) == "string" and target:lower() or "hunk"

  local hunks = M.get_hunks(bufnr)
  if #hunks == 0 then
    notify.info("No pending changes to accept", opts)
    M.close_review(bufnr, opts)
    return true
  end

  if target == "all" then
    local cur_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    M._snapshots[bufnr] = cur_lines
    M.close_review(bufnr, opts)
    notify.info("Accepted all changes in buffer", opts)
    return true
  end

  local cur_win = vim.api.nvim_get_current_win()
  local cur_line = vim.api.nvim_win_get_cursor(cur_win)[1]
  local target_hunk = nil
  for _, h in ipairs(hunks) do
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
  local base_lines = M.get_baseline_lines(bufnr)
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

  M._snapshots[bufnr] = new_base
  local remaining_hunks = M.get_hunks(bufnr)
  if #remaining_hunks == 0 then
    M.close_review(bufnr, opts)
  else
    if M._inline_active[bufnr] then
      M.render_inline_review(bufnr, opts)
    else
      local review_info = M._review_wins[bufnr]
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

  local hunks = M.get_hunks(bufnr)
  if #hunks == 0 then
    notify.info("No pending changes to reject", opts)
    M.close_review(bufnr, opts)
    return true
  end

  if target == "all" then
    local base_lines = M.get_baseline_lines(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, base_lines)
    M.close_review(bufnr, opts)
    notify.info("Rejected all changes: buffer reverted to baseline", opts)
    return true
  end

  local cur_win = vim.api.nvim_get_current_win()
  local cur_line = vim.api.nvim_win_get_cursor(cur_win)[1]
  local target_hunk = nil
  for _, h in ipairs(hunks) do
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

  local remaining_hunks = M.get_hunks(bufnr)
  if #remaining_hunks == 0 then
    M.close_review(bufnr, opts)
  end

  notify.info(string.format("Rejected change hunk #%d (reverted to baseline)", target_hunk.index), opts)
  return true
end

--- Navigates cursor to next change hunk.
--- @param win_id number|nil Window ID.
--- @param opts table|nil Options.
--- @return boolean True if jumped to next hunk.
function M.next_hunk(win_id, opts)
  win_id = (type(win_id) == "number" and win_id > 0) and win_id or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local cur_line = vim.api.nvim_win_get_cursor(win_id)[1]
  local hunks = M.get_hunks(bufnr)

  if #hunks == 0 then
    notify.info("No change hunks found in buffer", opts)
    return false
  end

  for _, h in ipairs(hunks) do
    if h.start_line > cur_line then
      vim.api.nvim_win_set_cursor(win_id, { h.start_line, 0 })
      return true
    end
  end

  -- Wrap around to first hunk
  vim.api.nvim_win_set_cursor(win_id, { hunks[1].start_line, 0 })
  return true
end

--- Navigates cursor to previous change hunk.
--- @param win_id number|nil Window ID.
--- @param opts table|nil Options.
--- @return boolean True if jumped to previous hunk.
function M.prev_hunk(win_id, opts)
  win_id = (type(win_id) == "number" and win_id > 0) and win_id or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local cur_line = vim.api.nvim_win_get_cursor(win_id)[1]
  local hunks = M.get_hunks(bufnr)

  if #hunks == 0 then
    notify.info("No change hunks found in buffer", opts)
    return false
  end

  for i = #hunks, 1, -1 do
    local h = hunks[i]
    if h.start_line < cur_line then
      vim.api.nvim_win_set_cursor(win_id, { h.start_line, 0 })
      return true
    end
  end

  -- Wrap around to last hunk
  vim.api.nvim_win_set_cursor(win_id, { hunks[#hunks].start_line, 0 })
  return true
end

--- Extract diff hunk at cursor position.
--- @param win_id number|nil Optional window ID (defaults to current window).
--- @return table|nil Table with file_path, start_line, end_line, diff_text, or nil if no diff hunk.
function M.get_diff_hunk_at_cursor(win_id)
  win_id = (type(win_id) == "number" and win_id > 0) and win_id or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win_id) then
    return nil
  end

  local bufnr = vim.api.nvim_win_get_buf(win_id)
  local cursor_pos = vim.api.nvim_win_get_cursor(win_id)
  local cur_line = cursor_pos[1]

  -- Determine clean file_path & abs_path
  local full_path = vim.api.nvim_buf_get_name(bufnr)
  local file_path = "[No Name]"
  local abs_path = ""
  if full_path ~= "" then
    local clean_path = full_path:gsub("^diffview://.-/%.git/[^:]+:", "")
    abs_path = vim.fn.fnamemodify(clean_path, ":p")
    file_path = vim.fn.fnamemodify(clean_path, ":~:.")
    if file_path == "" then file_path = full_path end
  end

  -- Case 1: Split Diff Mode (vim.wo[win_id].diff == true)
  if vim.wo[win_id].diff then
    local tab_wins = vim.api.nvim_tabpage_list_wins(0)
    local peer_win = nil
    for _, w in ipairs(tab_wins) do
      if w ~= win_id and vim.api.nvim_win_is_valid(w) and vim.wo[w].diff then
        peer_win = w
        break
      end
    end

    if peer_win then
      local peer_buf = vim.api.nvim_win_get_buf(peer_win)
      local cur_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local peer_lines = vim.api.nvim_buf_get_lines(peer_buf, 0, -1, false)

      local cur_text = table.concat(cur_lines, "\n")
      local peer_text = table.concat(peer_lines, "\n")

      if cur_text == peer_text then
        return nil
      end

      local indices = vim.diff(peer_text, cur_text, { result_type = "indices" })
      local unified_diff = vim.diff(peer_text, cur_text)
      local hunk_texts = split_diff_hunks(unified_diff)

      if #indices > 0 then
        for i, idx in ipairs(indices) do
          local sa, ca, sb, cb = idx[1], idx[2], idx[3], idx[4]
          local start_line, end_line
          if cb > 0 then
            start_line = sb
            end_line = sb + cb - 1
          else
            start_line = math.max(1, sb)
            end_line = math.max(1, sb)
          end

          local is_match = false
          if cb > 0 then
            is_match = (cur_line >= start_line and cur_line <= end_line)
          else
            is_match = (cur_line == start_line)
          end

          if is_match then
            local diff_snippet = hunk_texts[i] or string.format("@@ -%d,%d +%d,%d @@", sa, ca, sb, cb)
            return {
              file_path = file_path,
              abs_path = abs_path,
              start_line = start_line,
              end_line = end_line,
              diff_text = vim.trim(diff_snippet),
            }
          end
        end
      end

      return nil
    end
  end

  -- Case 2: Buffer Filetype 'diff'
  local ft = vim.bo[bufnr].filetype
  if ft == "diff" then
    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local header_idx = nil
    for l = cur_line, 1, -1 do
      if buf_lines[l] and buf_lines[l]:sub(1, 2) == "@@" then
        header_idx = l
        break
      end
    end

    if header_idx then
      local header_line = buf_lines[header_idx]
      local sb, cb
      local plus_part = header_line:match("%+(%d+,?%d*)")
      if plus_part then
        if plus_part:find(",") then
          local s, c = plus_part:match("(%d+),(%d+)")
          sb, cb = tonumber(s), tonumber(c)
        else
          sb = tonumber(plus_part)
          cb = 1
        end
      end

      sb = sb or 1
      cb = cb or 1
      local start_line = sb
      local end_line = (cb > 0) and (sb + cb - 1) or sb

      local patch_file = file_path
      for l = header_idx - 1, 1, -1 do
        local line = buf_lines[l]
        if line:sub(1, 4) == "+++ " then
          local p = line:sub(5):gsub("^[ab]/", "")
          if p ~= "" then
            patch_file = p
            break
          end
        end
      end

      local hunk_lines = { header_line }
      for l = header_idx + 1, #buf_lines do
        local line = buf_lines[l]
        if line:sub(1, 2) == "@@" or line:sub(1, 4) == "--- " or line:sub(1, 4) == "+++ " then
          break
        end
        table.insert(hunk_lines, line)
      end

      return {
        file_path = patch_file,
        start_line = start_line,
        end_line = end_line,
        diff_text = vim.trim(table.concat(hunk_lines, "\n")),
      }
    end

    return nil
  end

  -- Case 3: Git HEAD Comparison Fallback
  if full_path ~= "" and vim.fn.executable("git") == 1 then
    local rel_path = vim.fn.fnamemodify(full_path, ":~:.")
    if rel_path ~= "" then
      local res = vim.system({ "git", "show", "HEAD:" .. rel_path }, { text = true }):wait()
      if res.code == 0 and res.stdout then
        local peer_text = res.stdout
        local cur_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local cur_text = table.concat(cur_lines, "\n")

        if peer_text ~= cur_text then
          local indices = vim.diff(peer_text, cur_text, { result_type = "indices" })
          local unified_diff = vim.diff(peer_text, cur_text)
          local hunk_texts = split_diff_hunks(unified_diff)

          for i, idx in ipairs(indices) do
            local sa, ca, sb, cb = idx[1], idx[2], idx[3], idx[4]
            local start_line, end_line
            if cb > 0 then
              start_line = sb
              end_line = sb + cb - 1
            else
              start_line = math.max(1, sb)
              end_line = math.max(1, sb)
            end

            local is_match = false
            if cb > 0 then
              is_match = (cur_line >= start_line and cur_line <= end_line)
            else
              is_match = (cur_line == start_line)
            end

            if is_match then
              local diff_snippet = hunk_texts[i] or string.format("@@ -%d,%d +%d,%d @@", sa, ca, sb, cb)
              return {
                file_path = rel_path,
                start_line = start_line,
                end_line = end_line,
                diff_text = vim.trim(diff_snippet),
              }
            end
          end
        end
      end
    end
  end

  return nil
end

--- Send diff review comment to AGY.
--- @param opts table|nil Configuration options.
--- @return boolean True if comment process started/sent, false if cancelled or error.
function M.send_diff_comment(opts)
  opts = type(opts) == "table" and opts or {}

  local diff_info = M.get_diff_hunk_at_cursor()
  if not diff_info or not diff_info.diff_text or diff_info.diff_text == "" then
    notify.warn("No diff hunk found at cursor position", opts)
    return false
  end

  local agent_name = ((opts and opts.target_agent) or "agy"):upper()
  vim.ui.input({ prompt = string.format("%s Diff Comment: ", agent_name), default = "" }, function(input)
    if input == nil then
      notify.info("Diff comment cancelled", opts)
      return
    end

    local payload = format.build_diff_prompt(input, diff_info)
    local main = require("sagani")
    local dispatch_opts = vim.tbl_deep_extend("force", opts or {}, { task_type = "review" })
    main.dispatch_prompt(payload, nil, dispatch_opts)
  end)

  return true
end

return M

