-- Headless Stress Test Harness for herdr-agy.nvim (Challenger M3 Iteration 2)
local project_root = "/Users/vikks/teamwork_projects/nvim_herdr_agy"
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local selection = require("herdr-agy.selection")
local format = require("herdr-agy.format")
local init = require("herdr-agy")
local notify = require("herdr-agy.notify")

local passed_count = 0
local failed_count = 0
local test_failures = {}
local test_warnings = {}

local function assert_eq(actual, expected, test_name)
  if actual == expected then
    passed_count = passed_count + 1
    print(string.format("  ✓ PASS: %s", test_name))
  else
    failed_count = failed_count + 1
    local msg = string.format("  ✗ FAIL: %s (Expected: %q, Got: %q)", test_name, tostring(expected), tostring(actual))
    print(msg)
    table.insert(test_failures, msg)
  end
end

local function assert_true(cond, test_name, detail)
  if cond then
    passed_count = passed_count + 1
    print(string.format("  ✓ PASS: %s", test_name))
  else
    failed_count = failed_count + 1
    local msg = string.format("  ✗ FAIL: %s (%s)", test_name, detail or "condition evaluated to false")
    print(msg)
    table.insert(test_failures, msg)
  end
end

local function record_warning(test_name, msg)
  print(string.format("  ⚠️  WARNING: %s — %s", test_name, msg))
  table.insert(test_warnings, string.format("%s: %s", test_name, msg))
end

local function run_test(name, fn)
  print("\n---------------------------------------------------------")
  print("Running Stress Test: " .. name)
  print("---------------------------------------------------------")
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

-- ==========================================================
-- STRESS TEST 1: Empty Selections & Edge Case Buffers
-- ==========================================================

run_test("ST1.1: Completely empty buffer (0 lines)", function()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  -- uninitialized marks
  vim.fn.setpos("'<", { buf, 0, 0, 0 })
  vim.fn.setpos("'>", { buf, 0, 0, 0 })
  rawset(vim.fn, "visualmode", function() return "v" end)

  local sel = selection.get_visual_selection(buf)
  assert_true(type(sel) == "table", "returns selection table")
  assert_eq(sel.snippet, "", "snippet is empty string for empty buffer")
  assert_eq(sel.filetype, "text", "fallback filetype is text")
end)

run_test("ST1.2: Single empty line in buffer", function()
  local buf = create_fixture_buf({ "" }, "lua")
  set_visual_marks(buf, "V", 1, 1, 1, 1)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "", "snippet for empty line linewise selection is empty string")
end)

run_test("ST1.3: Uninitialized visual marks fallback to cursor pos", function()
  local buf = create_fixture_buf({ "line one", "line two" }, "python")
  vim.api.nvim_win_set_cursor(0, { 2, 3 }) -- line 2, col 3 (0-indexed => 4th char)
  vim.fn.setpos("'<", { buf, 0, 0, 0 })
  vim.fn.setpos("'>", { buf, 0, 0, 0 })
  rawset(vim.fn, "visualmode", function() return "" end)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.start_line, 2, "fallback start_line is 2")
  assert_eq(sel.end_line, 2, "fallback end_line is 2")
  assert_eq(sel.start_col, 4, "fallback start_col is 4 (1-indexed)")
  assert_eq(sel.end_col, 4, "fallback end_col is 4 (1-indexed)")
end)

run_test("ST1.4: send_selection_prompt on empty selection snippet", function()
  local buf = create_fixture_buf({ "" }, "lua")
  set_visual_marks(buf, "V", 1, 1, 1, 1)

  local notified_warn = false
  local orig_warn = notify.warn
  notify.warn = function(msg)
    notified_warn = true
    assert_true(msg:find("No visual selection found", 1, true) ~= nil, "warning message")
  end

  local dispatched = false
  local orig_dispatch = init.dispatch_prompt
  init.dispatch_prompt = function()
    dispatched = true
    return true
  end

  selection.send_selection_prompt({ notify = { enabled = true } })

  notify.warn = orig_warn
  init.dispatch_prompt = orig_dispatch

  assert_true(notified_warn, "warned on empty visual selection")
  assert_eq(dispatched, false, "did not dispatch prompt on empty snippet")
end)

run_test("ST1.5: send_code_context on empty selection snippet", function()
  local buf = create_fixture_buf({ "" }, "lua")
  set_visual_marks(buf, "V", 1, 1, 1, 1)

  local notified_warn = false
  local orig_warn = notify.warn
  notify.warn = function(msg)
    notified_warn = true
  end

  local res = selection.send_code_context({ notify = { enabled = true } })

  notify.warn = orig_warn

  assert_true(notified_warn, "warned on empty visual selection")
  assert_eq(res, false, "returns false on empty snippet")
end)

-- ==========================================================
-- STRESS TEST 2: Single Character Selections
-- ==========================================================

run_test("ST2.1: Single character characterwise selection ('v')", function()
  local buf = create_fixture_buf({ "abcdef" }, "c")
  set_visual_marks(buf, "v", 1, 3, 1, 3)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "c", "single char characterwise selection extracts 'c'")
  assert_eq(sel.start_col, 3, "start_col is 3")
  assert_eq(sel.end_col, 3, "end_col is 3")
end)

run_test("ST2.2: Single character linewise selection ('V')", function()
  local buf = create_fixture_buf({ "x" }, "c")
  set_visual_marks(buf, "V", 1, 1, 1, 1)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "x", "single char linewise selection extracts 'x'")
end)

run_test("ST2.3: Single character blockwise selection ('\\22')", function()
  local buf = create_fixture_buf({ "XYZ" }, "c")
  set_visual_marks(buf, "\22", 1, 2, 1, 2)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "Y", "single char blockwise selection extracts 'Y'")
end)

-- ==========================================================
-- STRESS TEST 3: Multiline Linewise Selections
-- ==========================================================

run_test("ST3.1: Large multiline linewise selection (100 lines)", function()
  local lines = {}
  for i = 1, 100 do
    table.insert(lines, "line_" .. i)
  end
  local buf = create_fixture_buf(lines, "python")
  set_visual_marks(buf, "V", 1, 1, 100, 7)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.start_line, 1, "start_line 1")
  assert_eq(sel.end_line, 100, "end_line 100")
  assert_true(sel.snippet:find("line_1\nline_2", 1, true) ~= nil, "snippet starts with line_1")
  assert_true(sel.snippet:find("line_99\nline_100", 1, true) ~= nil, "snippet ends with line_100")
end)

run_test("ST3.2: Reverse order visual selection marks (bottom-to-top)", function()
  local buf = create_fixture_buf({ "first", "second", "third" }, "lua")
  set_visual_marks(buf, "V", 3, 5, 1, 1)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.start_line, 1, "normalized start_line 1")
  assert_eq(sel.end_line, 3, "normalized end_line 3")
  assert_eq(sel.snippet, "first\nsecond\nthird", "normalized snippet extracts all 3 lines")
end)

-- ==========================================================
-- STRESS TEST 4: Blockwise Visual Selections & Column Limits
-- ==========================================================

run_test("ST4.1: Blockwise selection with missing trailing columns (short lines)", function()
  local buf = create_fixture_buf({
    "1234567890",
    "ab",
    "xyz",
    "long fourth line",
  }, "javascript")
  -- Block columns 5 to 8 across lines 1 to 4
  set_visual_marks(buf, "\22", 1, 5, 4, 8)

  local sel = selection.get_visual_selection(buf)
  -- Line 1: "5678"
  -- Line 2: "" (since length 2 < 5)
  -- Line 3: "" (since length 3 < 5)
  -- Line 4: " fou" (sub(line, 5, 8))
  local expected = "5678\n\n\n fou"
  assert_eq(sel.snippet, expected, "blockwise selection on short lines handled safely without errors")
end)

run_test("ST4.2: Blockwise selection with v:maxcol ($ selection)", function()
  local buf = create_fixture_buf({
    "short",
    "much longer line of text",
  }, "text")
  -- Select block from col 3 to v:maxcol (2147483647)
  set_visual_marks(buf, "\22", 1, 3, 2, 2147483647)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "ort\nch longer line of text", "blockwise selection with maxcol slices to EOL for each line")
end)

-- ==========================================================
-- STRESS TEST 5: Special Characters & Formatting Safety
-- ==========================================================

run_test("ST5.1: Special characters in snippet (%s, %d, \\0, $, \\)", function()
  local raw_code = "print('%s %d \\n \\t % x $VAR %s')"
  local buf = create_fixture_buf({ raw_code }, "lua", "/tmp/test_spec.lua")
  set_visual_marks(buf, "V", 1, 1, 1, #raw_code)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, raw_code, "snippet preserves special characters exactly")

  local payload = format.build_context_prompt("Check format specifiers: %s %d %x", sel)
  assert_true(payload:find(raw_code, 1, true) ~= nil, "payload contains unescaped special code string")
  assert_true(payload:find("Check format specifiers: %s %d %x", 1, true) ~= nil, "payload contains instruction with % characters")
end)

run_test("ST5.2: Code snippet containing Markdown code blocks (```)", function()
  local raw_code = "```lua\nlocal x = 10\n```"
  local buf = create_fixture_buf({ "```lua", "local x = 10", "```" }, "markdown")
  set_visual_marks(buf, "V", 1, 1, 3, 3)

  local sel = selection.get_visual_selection(buf)
  local payload = format.build_context_prompt("Review markdown code", sel)

  assert_true(payload:find(raw_code, 1, true) ~= nil, "payload contains embedded markdown triple backticks")
  -- Check if embedded triple backticks cause format crash
  assert_true(type(payload) == "string" and #payload > 0, "payload generated successfully")
end)

-- ==========================================================
-- STRESS TEST 6: Multibyte UTF-8 Characters & Slicing
-- ==========================================================

run_test("ST6.1: UTF-8 characterwise selection ('v')", function()
  -- UTF-8 string: "Hello 🚀 World"
  -- Bytes: "Hello " (6 bytes), 🚀 (4 bytes: F0 9F 99 82), " World" (6 bytes)
  -- Total byte length = 16.
  local text = "Hello 🚀 World"
  local buf = create_fixture_buf({ text }, "markdown")
  -- In Neovim visual mode, set pos on 🚀
  -- Byte start of 🚀 is col 7. Byte end of 🚀 is col 10 (or start byte 7 depending on mark).
  -- Let's test byte cols 7 to 10 vs 7 to 7:
  set_visual_marks(buf, "v", 1, 7, 1, 10)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "🚀", "UTF-8 emoji extracted cleanly when end_col includes all 4 bytes")
end)

run_test("ST6.2: UTF-8 characterwise selection when mark ends on start byte (potential corruption check)", function()
  -- In Neovim characterwise mode, getpos("'>") for a multibyte char (like 🚀 at col 7)
  -- returns byte col 7 (the start byte of the char).
  -- If selection.lua does string.sub(line, 7, 7), it extracts 1 byte of the 4-byte character.
  local text = "Hello 🚀 World"
  local buf = create_fixture_buf({ text }, "markdown")
  set_visual_marks(buf, "v", 1, 7, 1, 7)

  local sel = selection.get_visual_selection(buf)
  if sel.snippet ~= "🚀" then
    record_warning("UTF-8 Byte Slicing", string.format("Selection on byte col 7..7 extracted byte %q (hex: %02X) instead of full UTF-8 char 🚀. Note: string.sub is byte-based in selection.lua.", sel.snippet, string.byte(sel.snippet or "")))
  else
    assert_eq(sel.snippet, "🚀", "UTF-8 char extracted")
  end
end)

run_test("ST6.3: Multibyte Chinese text linewise selection", function()
  local text1 = "你好世界" -- 12 bytes
  local text2 = "Neovim 插件测试" -- 19 bytes
  local buf = create_fixture_buf({ text1, text2 }, "text")
  set_visual_marks(buf, "V", 1, 1, 2, 19)

  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, text1 .. "\n" .. text2, "multibyte Chinese text extracted in full in linewise mode")
end)

-- ==========================================================
-- STRESS TEST 7: vim.ui.input Cancellation Handling
-- ==========================================================

run_test("ST7.1: vim.ui.input callback with nil (user pressed ESC)", function()
  local buf = create_fixture_buf({ "some code" }, "lua")
  set_visual_marks(buf, "v", 1, 1, 1, 9)

  local orig_input = vim.ui.input
  vim.ui.input = function(opts, cb)
    cb(nil)
  end

  local notified_info = false
  local orig_info = notify.info
  notify.info = function(msg)
    if msg:find("Dispatch cancelled", 1, true) then
      notified_info = true
    end
  end

  local dispatched = false
  local orig_dispatch = init.dispatch_prompt
  init.dispatch_prompt = function()
    dispatched = true
    return true
  end

  selection.send_selection_prompt({ notify = { enabled = true } })

  vim.ui.input = orig_input
  notify.info = orig_info
  init.dispatch_prompt = orig_dispatch

  assert_true(notified_info, "notified user that dispatch was cancelled")
  assert_eq(dispatched, false, "no prompt dispatched when input is nil")
end)

run_test("ST7.2: vim.ui.input callback with empty string ''", function()
  local buf = create_fixture_buf({ "some code" }, "lua")
  set_visual_marks(buf, "v", 1, 1, 1, 9)

  local orig_input = vim.ui.input
  vim.ui.input = function(opts, cb)
    cb("")
  end

  local notified_info = false
  local orig_info = notify.info
  notify.info = function(msg)
    if msg:find("Dispatch cancelled", 1, true) then
      notified_info = true
    end
  end

  local dispatched = false
  local orig_dispatch = init.dispatch_prompt
  init.dispatch_prompt = function()
    dispatched = true
    return true
  end

  selection.send_selection_prompt({ notify = { enabled = true } })

  vim.ui.input = orig_input
  notify.info = orig_info
  init.dispatch_prompt = orig_dispatch

  assert_true(notified_info, "notified user that dispatch was cancelled on empty string")
  assert_eq(dispatched, false, "no prompt dispatched when input is empty string")
end)

-- ==========================================================
-- STRESS TEST 8: LazyVim Spec and Module Integrations
-- ==========================================================

run_test("ST8.1: Verify plugins/herdr-agy.lua spec integrity", function()
  local spec_file = project_root .. "/plugins/herdr-agy.lua"
  local spec_fn = loadfile(spec_file)
  assert_true(spec_fn ~= nil, "plugins/herdr-agy.lua is valid Lua code")

  local spec = spec_fn()
  assert_true(type(spec) == "table", "plugin spec returns table")
  assert_eq(#spec, 2, "spec has 2 entries (which-key and herdr-agy.nvim)")

  local main_spec = spec[2]
  assert_eq(main_spec.name, "herdr-agy.nvim", "main spec name")

  -- Check cmd commands
  local expected_cmds = {
    "HerdrAgyStatus",
    "HerdrAgySelectTarget",
    "HerdrAgyPrompt",
    "HerdrAgySend",
    "HerdrAgyContext",
    "HerdrAgyDiff",
  }
  for _, cmd_name in ipairs(expected_cmds) do
    local found = false
    for _, c in ipairs(main_spec.cmd or {}) do
      if c == cmd_name then found = true break end
    end
    assert_true(found, "cmd contains " .. cmd_name)
  end

  -- Check keys entries
  local keys_map = {}
  for _, k in ipairs(main_spec.keys or {}) do
    local key_id = (k[1] or "") .. ":" .. (type(k.mode) == "table" and table.concat(k.mode, ",") or (k.mode or "n"))
    keys_map[key_id] = k[2]
  end

  assert_true(keys_map["<leader>as:n"] ~= nil, "<leader>as in normal mode is bound")
  assert_true(keys_map["<leader>as:v"] ~= nil, "<leader>as in visual mode is bound")
  assert_true(keys_map["<leader>ac:n"] ~= nil, "<leader>ac in normal mode is bound")
  assert_true(keys_map["<leader>ac:v"] ~= nil, "<leader>ac in visual mode is bound")
end)


-- ==========================================================
-- SUMMARY & VERDICT
-- ==========================================================

print("\n==========================================================")
print(string.format("STRESS TEST SUMMARY: %d Passed, %d Failed, %d Warnings", passed_count, failed_count, #test_warnings))
print("==========================================================")

if #test_warnings > 0 then
  print("\nWarnings:")
  for _, w in ipairs(test_warnings) do
    print("  ⚠️  " .. w)
  end
end

if #test_failures > 0 then
  print("\nFailures:")
  for _, f in ipairs(test_failures) do
    print("  " .. f)
  end
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
