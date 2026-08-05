--- ==============================================================================
--- Module: sagani.diff.baseline
---
--- Description:
---   Manages buffer baseline snapshots, disk reading, and Git HEAD baseline line
---   extraction for sagani.nvim diff calculations.
---
--- Responsibilities:
---   - Capture baseline snapshot lines prior to agent execution.
---   - Retrieve baseline lines from in-memory snapshot, Git HEAD, or disk file.
--- ==============================================================================

local M = {
  _snapshots = {},
}

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

return M
