local notify = require("herdr-agy.notify")
local format = require("herdr-agy.format")

local M = {}

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

  -- Determine clean file_path
  local full_path = vim.api.nvim_buf_get_name(bufnr)
  local file_path = "[No Name]"
  if full_path ~= "" then
    local clean_path = full_path:gsub("^diffview://.-/%.git/[^:]+:", "")
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
    local main = require("herdr-agy")
    main.dispatch_prompt(payload, nil, opts)
  end)

  return true
end

return M
