-- Adversarial Stress Test Harness for M3 (selection.lua & format.lua)
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local selection = require("herdr-agy.selection")
local format = require("herdr-agy.format")
local notify = require("herdr-agy.notify")
local init = require("herdr-agy")

local passed_count = 0
local failed_count = 0
local test_failures = {}

local function assert_eq(actual, expected, test_name)
  if actual == expected then
    passed_count = passed_count + 1
    print(string.format("  ✓ PASS: %s", test_name))
  else
    failed_count = failed_count + 1
    local msg = string.format("  ✗ FAIL: %s\n    Expected: %s\n    Got:      %s", test_name, vim.inspect(expected), vim.inspect(actual))
    print(msg)
    table.insert(test_failures, msg)
  end
end

local function assert_true(cond, test_name)
  assert_eq(cond, true, test_name)
end

local function run_test(name, fn)
  print("\nRunning Stress Test: " .. name)
  local ok, err = pcall(fn)
  if not ok then
    failed_count = failed_count + 1
    local msg = string.format("  ✗ EXCEPTION in %s: %s", name, tostring(err))
    print(msg)
    table.insert(test_failures, msg)
  end
end

local function create_fixture_buf(lines, ft, file_path)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if ft then
    vim.bo[buf].filetype = ft
  end
  if file_path then
    vim.api.nvim_buf_set_name(buf, file_path)
  end
  vim.api.nvim_set_current_buf(buf)
  return buf
end

local function set_visual_marks(buf, mode, start_line, start_col, end_line, end_col)
  vim.fn.setpos("'<", { buf, start_line, start_col, 0 })
  vim.fn.setpos("'>", { buf, end_line, end_col, 0 })
  rawset(vim.fn, "visualmode", function() return mode end)
end

-- Helper to check if string is valid UTF-8
local function is_valid_utf8_string(str)
  local i = 1
  local len = #str
  while i <= len do
    local b = string.byte(str, i)
    local seq_len = 1
    if b >= 0x00 and b <= 0x7F then
      seq_len = 1
    elseif b >= 0xC2 and b <= 0xDF then
      seq_len = 2
    elseif b >= 0xE0 and b <= 0xEF then
      seq_len = 3
    elseif b >= 0xF0 and b <= 0xF4 then
      seq_len = 4
    else
      return false, string.format("Invalid UTF-8 lead byte 0x%02X at position %d of %d", b, i, len)
    end

    if i + seq_len - 1 > len then
      return false, string.format("Truncated UTF-8 sequence starting with 0x%02X at position %d (expected %d bytes, got %d remaining)", b, i, seq_len, len - i + 1)
    end

    for j = 1, seq_len - 1 do
      local cb = string.byte(str, i + j)
      if not cb or cb < 0x80 or cb > 0xBF then
        return false, string.format("Invalid UTF-8 continuation byte 0x%02X at position %d", cb or 0, i + j)
      end
    end
    i = i + seq_len
  end
  return true, "OK"
end

print("==========================================================")
print("STARTING ADVERSARIAL M3 STRESS TESTS")
print("==========================================================")

-- -----------------------------------------------------------------------------
-- 1. REVERSE SELECTION BOUNDS (Right-to-Left, Bottom-to-Top)
-- -----------------------------------------------------------------------------

run_test("1.1 Reverse Right-to-Left single line characterwise ('v')", function()
  local buf = create_fixture_buf({ "0123456789" }, "lua")
  set_visual_marks(buf, "v", 1, 8, 1, 3)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.start_line, 1, "start_line is 1")
  assert_eq(sel.end_line, 1, "end_line is 1")
  assert_eq(sel.start_col, 3, "normalized start_col is 3")
  assert_eq(sel.end_col, 8, "normalized end_col is 8")
  assert_eq(sel.snippet, "234567", "snippet extracted range cols 3-8 ('234567')")
end)

run_test("1.2 Reverse Bottom-to-Top and Right-to-Left multi-line characterwise ('v')", function()
  local buf = create_fixture_buf({ "alpha beta gamma", "delta epsilon zeta", "eta theta iota" }, "lua")
  set_visual_marks(buf, "v", 3, 10, 1, 7)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.start_line, 1, "start_line normalized to 1")
  assert_eq(sel.end_line, 3, "end_line normalized to 3")
  assert_eq(sel.start_col, 7, "start_col normalized to 7")
  assert_eq(sel.end_col, 10, "end_col normalized to 10")
  assert_eq(sel.snippet, "beta gamma\ndelta epsilon zeta\neta theta ", "multiline reverse selection extracts correctly")
end)

run_test("1.3 Reverse Bottom-to-Top where start_col > end_col on multi-line", function()
  local buf = create_fixture_buf({ "abcdefghij", "klmnopqrst", "uvwxyz1234" }, "text")
  set_visual_marks(buf, "v", 3, 8, 1, 2)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.start_line, 1, "start_line normalized to 1")
  assert_eq(sel.end_line, 3, "end_line normalized to 3")
  assert_eq(sel.snippet, "bcdefghij\nklmnopqrst\nuvwxyz12", "multi-line reverse selection swaps start_col and end_col appropriately")
end)

run_test("1.4 Reverse Bottom-to-Top blockwise selection ('\\22')", function()
  local buf = create_fixture_buf({ "123456", "789012", "345678" }, "text")
  set_visual_marks(buf, "\22", 3, 5, 1, 2)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.start_line, 1, "start_line normalized to 1")
  assert_eq(sel.end_line, 3, "end_line normalized to 3")
  assert_eq(sel.snippet, "2345\n8901\n4567", "blockwise snippet correctly handles reversed marks")
end)

run_test("1.5 Unhandled non-string mode from vim.fn.visualmode()", function()
  local buf = create_fixture_buf({ "test line" }, "lua")
  vim.fn.setpos("'<", { buf, 1, 1, 0 })
  vim.fn.setpos("'>", { buf, 1, 5, 0 })
  rawset(vim.fn, "visualmode", function() return 123 end) -- returns number 123 instead of string

  local ok, sel_or_err = pcall(selection.get_visual_selection, buf)
  assert_true(ok, "get_visual_selection must not crash when visualmode() returns non-string")
end)

-- -----------------------------------------------------------------------------
-- 2. MULTIBYTE UTF-8 STRINGS
-- -----------------------------------------------------------------------------

run_test("2.1 Multibyte UTF-8 characterwise selection ('v')", function()
  local buf = create_fixture_buf({ "Hello 👋 World 🚀", "日本語 tests" }, "text")
  set_visual_marks(buf, "v", 1, 7, 1, 21)

  local sel = selection.get_visual_selection(buf)
  local is_valid, err_msg = is_valid_utf8_string(sel.snippet)
  assert_true(is_valid, "UTF-8 validity check: " .. err_msg)
  assert_eq(sel.snippet, "👋 World 🚀", "extracts full multibyte UTF-8 snippet when end_col is byte 21")
end)

run_test("2.2 Multibyte UTF-8 with end_col pointing to start byte of multibyte char (Vim '> mark)", function()
  local buf = create_fixture_buf({ "code with emoji 🚀 end" }, "lua")
  -- 'code with emoji ' is 16 bytes. 🚀 is bytes 17..20.
  -- In Vim visual mode, when cursor is on 🚀, setpos("'>") sets col to 17 (the start byte).
  set_visual_marks(buf, "v", 1, 1, 1, 17)

  local sel = selection.get_visual_selection(buf)
  print("    Resulting snippet: " .. vim.inspect(sel.snippet))
  local is_valid, err_msg = is_valid_utf8_string(sel.snippet)
  assert_true(is_valid, "Snippet must be valid UTF-8 (Found bug: " .. err_msg .. ")")
end)

run_test("2.3 Multibyte UTF-8 blockwise selection ('\\22') byte offset mismatch", function()
  local buf = create_fixture_buf({ "A👋B", "C🚀D" }, "text")
  set_visual_marks(buf, "\22", 1, 2, 2, 3)

  local sel = selection.get_visual_selection(buf)
  print("    Blockwise Multibyte snippet:\n" .. vim.inspect(sel.snippet))
  local is_valid, err_msg = is_valid_utf8_string(sel.snippet)
  assert_true(is_valid, "Blockwise multibyte snippet must be valid UTF-8 (Found bug: " .. err_msg .. ")")
end)

-- -----------------------------------------------------------------------------
-- 3. EMPTY BUFFERS & RAGGED LINES
-- -----------------------------------------------------------------------------

run_test("3.1 Completely empty buffer ({ '' })", function()
  local buf = create_fixture_buf({ "" }, "text")
  set_visual_marks(buf, "v", 1, 1, 1, 1)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "", "empty buffer returns empty snippet")
  assert_eq(sel.start_line, 1, "start_line is 1")
  assert_eq(sel.end_line, 1, "end_line is 1")
end)

run_test("3.2 Blockwise selection on short/ragged lines (line length < max_col)", function()
  local buf = create_fixture_buf({ "abcdefghij", "123", "xyz" }, "text")
  set_visual_marks(buf, "\22", 1, 4, 3, 8)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "defgh\n\n", "ragged lines beyond string length return empty strings for those lines")
end)

-- -----------------------------------------------------------------------------
-- 4. UNNAMED BUFFERS & FILETYPE FALLBACKS
-- -----------------------------------------------------------------------------

run_test("4.1 Unnamed buffer with no filetype", function()
  local buf = create_fixture_buf({ "some random line" }, nil, "")
  set_visual_marks(buf, "V", 1, 1, 1, 16)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.file_path, "[No Name]", "unnamed buffer file_path is [No Name]")
  assert_eq(sel.filetype, "text", "nil filetype falls back to text")
end)

-- -----------------------------------------------------------------------------
-- 5. CANCELLED PROMPT & INTERACTIVE DISPATCH
-- -----------------------------------------------------------------------------

run_test("5.1 send_selection_prompt with empty buffer (warns and returns false)", function()
  local buf = create_fixture_buf({ "" }, "text")
  set_visual_marks(buf, "v", 1, 1, 1, 1)

  local warned = false
  local orig_warn = notify.warn
  notify.warn = function(msg, opts)
    warned = true
  end

  local res = selection.send_selection_prompt({ notify = { enabled = false } })
  notify.warn = orig_warn

  assert_eq(warned, true, "warns when selection snippet is empty")
  assert_eq(res, false, "returns false on empty snippet")
end)

run_test("5.2 send_selection_prompt when user inputs empty string ''", function()
  local buf = create_fixture_buf({ "content line" }, "lua")
  set_visual_marks(buf, "V", 1, 1, 1, 12)

  local orig_input = vim.ui.input
  vim.ui.input = function(opts, cb)
    cb("") -- User submits empty string
  end

  local dispatched = false
  local orig_dispatch = init.dispatch_prompt
  init.dispatch_prompt = function()
    dispatched = true
    return true, nil
  end

  selection.send_selection_prompt({ notify = { enabled = false } })

  vim.ui.input = orig_input
  init.dispatch_prompt = orig_dispatch

  assert_eq(dispatched, false, "empty string input cancels dispatch")
end)

run_test("5.3 send_selection_prompt when user presses Esc (nil input)", function()
  local buf = create_fixture_buf({ "content line" }, "lua")
  set_visual_marks(buf, "V", 1, 1, 1, 12)

  local orig_input = vim.ui.input
  vim.ui.input = function(opts, cb)
    cb(nil) -- User pressed Esc
  end

  local dispatched = false
  local orig_dispatch = init.dispatch_prompt
  init.dispatch_prompt = function()
    dispatched = true
    return true, nil
  end

  selection.send_selection_prompt({ notify = { enabled = false } })

  vim.ui.input = orig_input
  init.dispatch_prompt = orig_dispatch

  assert_eq(dispatched, false, "nil input cancels dispatch")
end)

-- -----------------------------------------------------------------------------
-- 6. FORMAT MODULE ADVERSARIAL TESTS
-- -----------------------------------------------------------------------------

run_test("6.1 format.build_context_prompt with edge-case numbers and strings", function()
  local res1 = format.build_context_prompt("Do X", {
    file_path = nil,
    filetype = nil,
    snippet = nil,
    start_line = nil,
    end_line = nil,
  })
  assert_true(res1:find("Context from `[No Name]` (L1):", 1, true) ~= nil, "handles all nil table fields")

  local res2 = format.build_context_prompt("", {
    file_path = "   ",
    filetype = "   ",
    snippet = "code",
    start_line = 5,
    end_line = 5,
  })
  assert_true(res2:find("Context snippet for review:", 1, true) ~= nil, "empty instruction falls back")
end)

print("\n==========================================================")
print(string.format("ADVERSARIAL STRESS TEST SUMMARY: %d Passed, %d Failed", passed_count, failed_count))
print("==========================================================")
if failed_count > 0 then
  for _, f in ipairs(test_failures) do
    print(f)
  end
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
