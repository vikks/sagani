--- ==============================================================================
--- Module: sagani.diff.hunks
---
--- Description:
---   Diff hunk calculation engine and navigation manager for sagani.nvim. Calculates
---   line-level hunks via vim.diff(), splits unified diff text, navigates cursor
---   between hunks, and extracts diff hunk context at cursor position.
---
--- Responsibilities:
---   - Split unified diff text into discrete hunk blocks.
---   - Calculate diff hunks between baseline lines and buffer lines via vim.diff().
---   - Navigate cursor to next/previous hunk in buffer.
---   - Extract diff hunk metadata at cursor position (file_path, start_line, end_line, diff_text).
--- ==============================================================================

local notify = require("sagani.notify")
local baseline = require("sagani.diff.baseline")

local M = {}

--- Helper to split unified diff text into individual hunk blocks.
--- @param diff_str string Unified diff string
--- @return table Array of hunk string blocks
function M.split_diff_hunks(diff_str)
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

--- Calculates hunks between baseline lines and current buffer lines.
--- @param bufnr number|nil Buffer handle.
--- @return table List of hunk objects { index, sa, ca, sb, cb, start_line, end_line, orig_lines, new_lines }.
function M.get_hunks(bufnr)
  bufnr = (type(bufnr) == "number" and bufnr > 0) and bufnr or vim.api.nvim_get_current_buf()
  local cur_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local base_lines = baseline.get_baseline_lines(bufnr)

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
      local hunk_texts = M.split_diff_hunks(unified_diff)

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
          local hunk_texts = M.split_diff_hunks(unified_diff)

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

return M
