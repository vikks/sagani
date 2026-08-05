--- ==============================================================================
--- Module: sagani.ui.markdown_popup.keymaps
---
--- Description:
---   Buffer-local keymap manager for sagani Markdown floating UI popups. Binds
---   interactive controls for replying ('r' / '<CR>'), pinning windows ('p'),
---   copying responses ('yr'), and closing popups ('q' / '<Esc>').
---
--- Responsibilities:
---   - Register buffer-local keymaps on popup creation.
---   - Handle interactive reply prompts and continuation ACP sessions.
---   - Handle response copying to register and window pinning.
--- ==============================================================================

local content = require("sagani.ui.markdown_popup.content")

local M = {}

--- Registers buffer-local keymaps for a Markdown popup window
--- @param buf number Buffer handle
--- @param win number Window handle
--- @param window_module table Window module handle for window closing/promotion
function M.bind_popup_keymaps(buf, win, window_module)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local close_win = function()
    local target_win = (window_module and window_module._active_wins and window_module._active_wins[buf]) or win
    if target_win and vim.api.nvim_win_is_valid(target_win) then
      pcall(vim.api.nvim_win_close, target_win, true)
    end
  end

  -- Close keymaps (q, <Esc>)
  vim.keymap.set("n", "q", close_win, { buffer = buf, silent = true, desc = "Close Markdown popup" })
  vim.keymap.set("n", "<Esc>", close_win, { buffer = buf, silent = true, desc = "Close Markdown popup" })

  -- Copy response keymap (yr)
  vim.keymap.set("n", "yr", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    vim.fn.setreg("+", text)
    vim.notify("Copied agent response to clipboard", vim.log.levels.INFO, { title = "sagani.nvim" })
  end, { buffer = buf, silent = true, desc = "Copy full response to clipboard" })

  -- Follow-up keymaps (<CR>, r, i)
  local function prompt_followup()
    local ctx = content._active_sessions[buf]
    local harness = (ctx and ctx.harness) or "AGY"
    vim.ui.input({ prompt = string.format("Follow-up question (%s): ", harness:upper()) }, function(input)
      if input and input ~= "" then
        content.send_followup(buf, input)
      end
    end)
  end

  vim.keymap.set("n", "<CR>", prompt_followup, { buffer = buf, silent = true, desc = "Ask follow-up question" })
  vim.keymap.set("n", "r", prompt_followup, { buffer = buf, silent = true, desc = "Reply / Ask follow-up question" })
  vim.keymap.set("n", "i", prompt_followup, { buffer = buf, silent = true, desc = "Ask follow-up question" })

  -- Promote keymaps (<C-w>h/j/k/l/t)
  local promote_fn = function(target)
    if window_module and window_module.promote then
      window_module.promote(buf, target)
    end
  end

  vim.keymap.set("n", "<C-w>h", function() promote_fn("left") end, { buffer = buf, silent = true, desc = "Promote popup to left split" })
  vim.keymap.set("n", "<C-w>H", function() promote_fn("left") end, { buffer = buf, silent = true, desc = "Promote popup to left split" })
  vim.keymap.set("n", "<C-w>l", function() promote_fn("right") end, { buffer = buf, silent = true, desc = "Promote popup to right split" })
  vim.keymap.set("n", "<C-w>L", function() promote_fn("right") end, { buffer = buf, silent = true, desc = "Promote popup to right split" })
  vim.keymap.set("n", "<C-w>k", function() promote_fn("top") end, { buffer = buf, silent = true, desc = "Promote popup to top split" })
  vim.keymap.set("n", "<C-w>K", function() promote_fn("top") end, { buffer = buf, silent = true, desc = "Promote popup to top split" })
  vim.keymap.set("n", "<C-w>j", function() promote_fn("bottom") end, { buffer = buf, silent = true, desc = "Promote popup to bottom split" })
  vim.keymap.set("n", "<C-w>J", function() promote_fn("bottom") end, { buffer = buf, silent = true, desc = "Promote popup to bottom split" })
  vim.keymap.set("n", "<C-w>t", function() promote_fn("tab") end, { buffer = buf, silent = true, desc = "Promote popup to new tab" })
  vim.keymap.set("n", "<C-w>T", function() promote_fn("tab") end, { buffer = buf, silent = true, desc = "Promote popup to new tab" })

  -- 'p' Pin mode keymap
  vim.keymap.set("n", "p", function()
    M.enter_pin_mode(buf, window_module)
  end, { buffer = buf, silent = true, desc = "Pin window to split/tab" })
end

--- Enters single-keypress Pin Mode for moving/promoting popup window
--- @param buf number Buffer handle
--- @param window_module table Window module handle
function M.enter_pin_mode(buf, window_module)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local notify = require("sagani.notify")
  notify.info("Pin Mode Active: Press h, l, k, j, or t to pin window (Esc/q to cancel)")

  -- Update footer line
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local found = false
  for i = #lines, 1, -1 do
    if lines[i]:find("^> [💡📌]") then
      lines[i] = content.PIN_FOOTER_HINT
      found = true
      break
    end
  end
  if not found then
    table.insert(lines, "")
    table.insert(lines, content.PIN_FOOTER_HINT)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local function clear_pin_keymaps(restore_hint)
    pcall(vim.keymap.del, "n", "h", { buffer = buf })
    pcall(vim.keymap.del, "n", "l", { buffer = buf })
    pcall(vim.keymap.del, "n", "k", { buffer = buf })
    pcall(vim.keymap.del, "n", "j", { buffer = buf })
    pcall(vim.keymap.del, "n", "t", { buffer = buf })
    pcall(vim.keymap.del, "n", "q", { buffer = buf })
    pcall(vim.keymap.del, "n", "<Esc>", { buffer = buf })

    -- Restore standard close keymaps
    local close_win = function()
      local target_win = (window_module and window_module._active_wins and window_module._active_wins[buf]) or vim.api.nvim_get_current_win()
      if target_win and vim.api.nvim_win_is_valid(target_win) then
        pcall(vim.api.nvim_win_close, target_win, true)
      end
    end

    vim.keymap.set("n", "q", close_win, { buffer = buf, silent = true, desc = "Close Markdown popup" })
    vim.keymap.set("n", "<Esc>", close_win, { buffer = buf, silent = true, desc = "Close Markdown popup" })

    if restore_hint then
      local cur_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      for i = #cur_lines, 1, -1 do
        if cur_lines[i]:find("^> 📌") then
          cur_lines[i] = content.STD_FOOTER_HINT
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, cur_lines)
          break
        end
      end
    end
  end

  local function do_pin(target)
    clear_pin_keymaps(true)
    if window_module and window_module.promote then
      window_module.promote(buf, target)
    end
    notify.info(string.format("Pinned window to %s", target))
    pcall(vim.cmd, "stopinsert")
  end

  local function cancel_pin()
    clear_pin_keymaps(true)
    notify.info("Pin mode cancelled")
    pcall(vim.cmd, "stopinsert")
  end

  vim.keymap.set("n", "h", function() do_pin("left") end, { buffer = buf, silent = true, desc = "Pin window to left split" })
  vim.keymap.set("n", "l", function() do_pin("right") end, { buffer = buf, silent = true, desc = "Pin window to right split" })
  vim.keymap.set("n", "k", function() do_pin("top") end, { buffer = buf, silent = true, desc = "Pin window to top split" })
  vim.keymap.set("n", "j", function() do_pin("bottom") end, { buffer = buf, silent = true, desc = "Pin window to bottom split" })
  vim.keymap.set("n", "t", function() do_pin("tab") end, { buffer = buf, silent = true, desc = "Pin window to new tab" })
  vim.keymap.set("n", "q", cancel_pin, { buffer = buf, silent = true, desc = "Cancel pin mode" })
  vim.keymap.set("n", "<Esc>", cancel_pin, { buffer = buf, silent = true, desc = "Cancel pin mode" })
end

return M
