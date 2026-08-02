local format = require("sagani.format")
local notify = require("sagani.notify")

local M = {}

--- Extracts visual selection range, snippet text, and metadata from a buffer.
--- @param bufnr number|nil Buffer handle (defaults to current buffer 0).
--- @return table Selection table { snippet, start_line, end_line, start_col, end_col, mode, file_path, filetype }
function M.get_visual_selection(bufnr)
  bufnr = (type(bufnr) == "number" and bufnr >= 0) and bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- Exit visual mode cleanly to flush '< and '> position marks
  local cur_mode = vim.fn.mode()
  if cur_mode:find("[vV\22]") then
    vim.cmd("noau normal! \27")
  end

  local mode = vim.fn.visualmode()
  if mode == "" or not mode:find("[vV\22]") then
    mode = "v"
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  -- Fallback if visual marks are uninitialized
  if start_line == 0 or end_line == 0 then
    local cursor = vim.api.nvim_win_get_cursor(0)
    start_line, end_line = cursor[1], cursor[1]
    start_col, end_col = cursor[2] + 1, cursor[2] + 1
  end

  -- Normalize top-to-bottom and left-to-right boundary order
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  -- Fetch line contents from buffer (0-indexed start, exclusive end)
  local raw_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local lines = {}
  for i, l in ipairs(raw_lines) do
    lines[i] = l
  end

  local snippet = ""
  if #lines > 0 then
    if mode == "V" then
      -- Linewise selection
      snippet = table.concat(lines, "\n")
    elseif mode == "\22" or mode == "<C-v>" then
      -- Blockwise selection rectangle
      local min_col = math.min(start_col, end_col)
      local max_col = math.max(start_col, end_col)
      for i, line in ipairs(lines) do
        lines[i] = string.sub(line, min_col, max_col)
      end
      snippet = table.concat(lines, "\n")
    else
      -- Characterwise selection ('v')
      if #lines == 1 then
        lines[1] = string.sub(lines[1], start_col, end_col)
      else
        lines[1] = string.sub(lines[1], start_col)
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
      end
      snippet = table.concat(lines, "\n")
    end
  end

  -- Extract file path and filetype metadata
  local full_name = vim.api.nvim_buf_get_name(bufnr)
  local file_path = "[No Name]"
  if full_name and full_name ~= "" then
    file_path = vim.fn.fnamemodify(full_name, ":~:.")
    if file_path == "" then
      file_path = full_name
    end
  end

  local filetype = vim.bo[bufnr].filetype
  if not filetype or filetype == "" then
    filetype = "text"
  end

  return {
    snippet = snippet,
    start_line = start_line,
    end_line = end_line,
    start_col = start_col,
    end_col = end_col,
    mode = mode,
    file_path = file_path,
    filetype = filetype,
  }
end

--- Prompts the user asynchronously for an instruction, formats selection context, and dispatches to AGY.
--- @param opts table|nil Options table passed to dispatch_prompt.
function M.send_selection_prompt(opts)
  local selection = M.get_visual_selection(0)

  if not selection.snippet or selection.snippet == "" then
    notify.warn("No visual selection found in buffer", opts)
    return false
  end

  local agent_name = ((opts and opts.target_agent) or "agy"):upper()
  vim.ui.input({ prompt = string.format("%s Instruction: ", agent_name), default = "" }, function(input)
    if input == nil or input == "" then
      notify.info("Dispatch cancelled: no instruction entered", opts)
      return
    end

    local payload = format.build_context_prompt(input, selection)
    local main = require("sagani")
    main.dispatch_prompt(payload, nil, opts)
  end)
end

--- Dispatches code selection context directly to AGY with default review prompt.
--- @param opts table|nil Options table passed to dispatch_prompt.
function M.send_code_context(opts)
  local selection = M.get_visual_selection(0)

  if not selection.snippet or selection.snippet == "" then
    notify.warn("No visual selection found in buffer", opts)
    return false
  end

  local payload = format.build_context_prompt("Context snippet for review:", selection)
  local main = require("sagani")
  return main.dispatch_prompt(payload, nil, opts)
end

return M
