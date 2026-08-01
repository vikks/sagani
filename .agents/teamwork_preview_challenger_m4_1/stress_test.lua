-- Adversarial Stress Test Suite for herdr-agy.nvim (Milestone 4)
-- Created by Challenger 1 (.agents/teamwork_preview_challenger_m4_1/stress_test.lua)

local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local diff = require("herdr-agy.diff")
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
    local msg = string.format("  ✗ FAIL: %s (Expected: %s, Got: %s)", test_name, tostring(expected), tostring(actual))
    print(msg)
    table.insert(test_failures, msg)
  end
end

local function assert_true(cond, test_name)
  assert_eq(cond, true, test_name)
end

local function assert_false(cond, test_name)
  assert_eq(cond, false, test_name)
end

local function assert_nil(val, test_name)
  assert_eq(val, nil, test_name)
end

local function assert_not_nil(val, test_name)
  if val ~= nil then
    passed_count = passed_count + 1
    print(string.format("  ✓ PASS: %s", test_name))
  else
    failed_count = failed_count + 1
    local msg = string.format("  ✗ FAIL: %s (Expected non-nil value)", test_name)
    print(msg)
    table.insert(test_failures, msg)
  end
end

local function run_test(name, fn)
  print("\n[STRESS TEST] Running: " .. name)
  local ok, err = pcall(fn)
  if not ok then
    failed_count = failed_count + 1
    local msg = string.format("  ✗ EXCEPTION in test '%s': %s", name, tostring(err))
    print(msg)
    table.insert(test_failures, msg)
  end
end

-- Helper to set up split diff windows
local function setup_split_diff(lines_peer, lines_cur, file_path)
  local buf_peer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf_peer, 0, -1, false, lines_peer)

  local buf_cur = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf_cur, 0, -1, false, lines_cur)
  if file_path then
    vim.api.nvim_buf_set_name(buf_cur, file_path)
  end

  local win_peer = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win_peer, buf_peer)
  vim.wo[win_peer].diff = true

  vim.cmd("vsplit")
  local win_cur = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win_cur, buf_cur)
  vim.wo[win_cur].diff = true

  return {
    buf_peer = buf_peer,
    buf_cur = buf_cur,
    win_peer = win_peer,
    win_cur = win_cur,
  }
end

local function cleanup_split_diff(fix)
  if fix then
    pcall(function()
      if fix.win_cur and vim.api.nvim_win_is_valid(fix.win_cur) then
        vim.wo[fix.win_cur].diff = false
        vim.api.nvim_win_close(fix.win_cur, true)
      end
      if fix.win_peer and vim.api.nvim_win_is_valid(fix.win_peer) then
        vim.wo[fix.win_peer].diff = false
      end
      vim.cmd("diffoff!")
      if fix.buf_cur and vim.api.nvim_buf_is_valid(fix.buf_cur) then
        vim.api.nvim_buf_delete(fix.buf_cur, { force = true })
      end
      if fix.buf_peer and vim.api.nvim_buf_is_valid(fix.buf_peer) then
        vim.api.nvim_buf_delete(fix.buf_peer, { force = true })
      end
    end)
  end
end

-- ===================================================================
-- TEST GROUP 1: INVALID WINDOW IDS & BAD TYPES
-- ===================================================================

run_test("Invalid Window IDs (-1, 99999, strings, tables, booleans, nil)", function()
  -- Non-existent window ID 99999
  local hunk = diff.get_diff_hunk_at_cursor(99999)
  assert_nil(hunk, "get_diff_hunk_at_cursor(99999) returns nil")

  -- Negative window ID -1
  local cur_win = vim.api.nvim_get_current_win()
  vim.wo[cur_win].diff = false
  hunk = diff.get_diff_hunk_at_cursor(-1)
  assert_nil(hunk, "get_diff_hunk_at_cursor(-1) returns nil when current win has no diff")

  -- String window ID "invalid_win"
  hunk = diff.get_diff_hunk_at_cursor("invalid_win")
  assert_nil(hunk, "get_diff_hunk_at_cursor('invalid_win') returns nil")

  -- Table window ID {}
  hunk = diff.get_diff_hunk_at_cursor({})
  assert_nil(hunk, "get_diff_hunk_at_cursor({}) returns nil")

  -- Boolean window ID false
  hunk = diff.get_diff_hunk_at_cursor(false)
  assert_nil(hunk, "get_diff_hunk_at_cursor(false) returns nil")

  -- Nil window ID
  hunk = diff.get_diff_hunk_at_cursor(nil)
  assert_nil(hunk, "get_diff_hunk_at_cursor(nil) returns nil when current win has no diff")
end)

-- ===================================================================
-- TEST GROUP 2: DIFFS WITH NO CHANGES
-- ===================================================================

run_test("Split diff mode with identical buffers (no changes)", function()
  local fix = setup_split_diff({ "line 1", "line 2", "line 3" }, { "line 1", "line 2", "line 3" }, "/tmp/identical.lua")
  vim.api.nvim_set_current_win(fix.win_cur)
  vim.api.nvim_win_set_cursor(fix.win_cur, { 2, 0 })

  local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_nil(hunk, "get_diff_hunk_at_cursor returns nil for identical buffers in split diff")

  cleanup_split_diff(fix)
end)

run_test("Filetype 'diff' buffer with no hunks/changes", function()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "diff --git a/foo.txt b/foo.txt",
    "index 1234567..89abcdef 100644",
    "--- a/foo.txt",
    "+++ b/foo.txt",
  })
  vim.bo[buf].filetype = "diff"
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_cursor(win, { 1, 0 })

  local hunk = diff.get_diff_hunk_at_cursor(win)
  assert_nil(hunk, "get_diff_hunk_at_cursor returns nil when no @@ hunk line exists")

  vim.api.nvim_buf_delete(buf, { force = true })
end)

-- ===================================================================
-- TEST GROUP 3: CURSOR OUTSIDE DIFF HUNKS
-- ===================================================================

run_test("Cursor outside diff hunk in split diff mode", function()
  local peer_lines = {}
  local cur_lines = {}
  for i = 1, 50 do
    peer_lines[i] = "line " .. i
    cur_lines[i] = "line " .. i
  end
  -- Hunk is at line 25
  cur_lines[25] = "line 25 modified"

  local fix = setup_split_diff(peer_lines, cur_lines, "/tmp/large.txt")
  vim.api.nvim_set_current_win(fix.win_cur)

  -- Test cursor at line 1 (outside hunk)
  vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
  local hunk_1 = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_nil(hunk_1, "Cursor at line 1 (outside hunk) returns nil")

  -- Test cursor at line 50 (outside hunk)
  vim.api.nvim_win_set_cursor(fix.win_cur, { 50, 0 })
  local hunk_50 = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_nil(hunk_50, "Cursor at line 50 (outside hunk) returns nil")

  -- Test cursor at line 25 (inside hunk)
  vim.api.nvim_win_set_cursor(fix.win_cur, { 25, 0 })
  local hunk_25 = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_not_nil(hunk_25, "Cursor at line 25 (inside hunk) returns diff hunk")
  if hunk_25 then
    assert_eq(hunk_25.start_line, 25, "hunk_25.start_line is 25")
    assert_eq(hunk_25.end_line, 25, "hunk_25.end_line is 25")
  end

  cleanup_split_diff(fix)
end)

run_test("Multi-hunk buffer: verify cursor in hunk 1, between hunks, and in hunk 2", function()
  local peer_lines = { "alpha", "beta", "gamma", "delta", "epsilon", "zeta" }
  local cur_lines  = { "alpha", "BETA", "gamma", "delta", "EPSILON", "zeta" }

  local fix = setup_split_diff(peer_lines, cur_lines, "/tmp/multi_hunk.lua")
  vim.api.nvim_set_current_win(fix.win_cur)

  -- Cursor on line 2 ("BETA" - Hunk 1)
  vim.api.nvim_win_set_cursor(fix.win_cur, { 2, 0 })
  local hunk1 = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_not_nil(hunk1, "Hunk 1 found at line 2")
  if hunk1 then
    assert_eq(hunk1.start_line, 2, "Hunk 1 start_line is 2")
    assert_true(hunk1.diff_text:find("+BETA") ~= nil, "Hunk 1 contains +BETA")
  end

  -- Cursor on line 4 ("delta" - between hunks)
  vim.api.nvim_win_set_cursor(fix.win_cur, { 4, 0 })
  local hunk_mid = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_nil(hunk_mid, "No hunk found between hunks at line 4")

  -- Cursor on line 5 ("EPSILON" - Hunk 2)
  vim.api.nvim_win_set_cursor(fix.win_cur, { 5, 0 })
  local hunk2 = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_not_nil(hunk2, "Hunk 2 found at line 5")
  if hunk2 then
    assert_eq(hunk2.start_line, 5, "Hunk 2 start_line is 5")
    assert_true(hunk2.diff_text:find("+EPSILON") ~= nil, "Hunk 2 contains +EPSILON")
  end

  cleanup_split_diff(fix)
end)

-- ===================================================================
-- TEST GROUP 4: SINGLE-LINE ADDITIONS AND DELETIONS
-- ===================================================================

run_test("Single-line addition in split diff mode", function()
  local fix = setup_split_diff({ "alpha", "gamma" }, { "alpha", "beta", "gamma" }, "/tmp/single_add.txt")
  vim.api.nvim_set_current_win(fix.win_cur)

  -- Cursor on added line "beta" (line 2)
  vim.api.nvim_win_set_cursor(fix.win_cur, { 2, 0 })
  local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_not_nil(hunk, "Single line addition hunk found")
  if hunk then
    assert_eq(hunk.start_line, 2, "start_line is 2")
    assert_eq(hunk.end_line, 2, "end_line is 2")
    assert_true(hunk.diff_text:find("+beta") ~= nil, "diff_text contains '+beta'")
  end

  cleanup_split_diff(fix)
end)

run_test("Single-line deletion in split diff mode", function()
  local fix = setup_split_diff({ "alpha", "beta", "gamma" }, { "alpha", "gamma" }, "/tmp/single_del.txt")
  vim.api.nvim_set_current_win(fix.win_cur)

  -- In cur buffer ("alpha", "gamma"), deletion of "beta" happened between line 1 and 2.
  -- In vim.diff indices, sa=2, ca=1, sb=1, cb=0 -> start_line=1.
  -- Cursor on line 1 ("alpha")
  vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
  local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_not_nil(hunk, "Single line deletion hunk found at predecessor line")
  if hunk then
    assert_eq(hunk.start_line, 1, "start_line is 1")
    assert_eq(hunk.end_line, 1, "end_line is 1")
    assert_true(hunk.diff_text:find("-beta") ~= nil, "diff_text contains '-beta'")
  end

  cleanup_split_diff(fix)
end)

run_test("Single-line addition at line 1 (top of file)", function()
  local fix = setup_split_diff({ "line 2" }, { "line 1 added", "line 2" }, "/tmp/top_add.txt")
  vim.api.nvim_set_current_win(fix.win_cur)

  vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
  local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_not_nil(hunk, "Top-of-file addition hunk found")
  if hunk then
    assert_eq(hunk.start_line, 1, "start_line is 1")
    assert_eq(hunk.end_line, 1, "end_line is 1")
  end

  cleanup_split_diff(fix)
end)

run_test("Single-line deletion at top of file (line 1)", function()
  local fix = setup_split_diff({ "removed top line", "line 2" }, { "line 2" }, "/tmp/top_del.txt")
  vim.api.nvim_set_current_win(fix.win_cur)

  vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
  local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
  assert_not_nil(hunk, "Top-of-file deletion hunk found")
  if hunk then
    assert_eq(hunk.start_line, 1, "start_line is 1")
    assert_eq(hunk.end_line, 1, "end_line is 1")
    assert_true(hunk.diff_text:find("-removed top line") ~= nil, "diff_text contains deleted line")
  end

  cleanup_split_diff(fix)
end)

-- ===================================================================
-- TEST GROUP 5: USER CANCELLING VIM.UI.INPUT (NIL) & SPECIAL INPUTS
-- ===================================================================

run_test("send_diff_comment: user cancels vim.ui.input (input is nil)", function()
  local fix = setup_split_diff({ "old line" }, { "new line" }, "/tmp/cancel_test.txt")
  vim.api.nvim_set_current_win(fix.win_cur)
  vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })

  -- Mock vim.ui.input to simulate user pressing ESC (input = nil)
  local original_ui_input = vim.ui.input
  local input_called = false
  vim.ui.input = function(opts, on_confirm)
    input_called = true
    on_confirm(nil)
  end

  -- Track notify calls
  local original_notify_info = notify.info
  local notify_called = false
  local notify_msg = nil
  notify.info = function(msg, opts)
    notify_called = true
    notify_msg = msg
  end

  local res = diff.send_diff_comment()
  assert_true(res, "send_diff_comment returns true indicating prompt initiated")
  assert_true(input_called, "vim.ui.input was invoked")
  assert_true(notify_called, "notify.info was called on cancellation")
  assert_eq(notify_msg, "Diff comment cancelled", "notify.info received correct cancellation message")

  -- Restore mocks
  vim.ui.input = original_ui_input
  notify.info = original_notify_info
  cleanup_split_diff(fix)
end)

run_test("send_diff_comment when no diff hunk at cursor", function()
  local cur_win = vim.api.nvim_get_current_win()
  vim.wo[cur_win].diff = false

  local warn_called = false
  local original_warn = notify.warn
  notify.warn = function(msg, opts)
    warn_called = true
  end

  local res = diff.send_diff_comment()
  assert_false(res, "send_diff_comment returns false when no diff hunk exists")
  assert_true(warn_called, "notify.warn called when no diff hunk")

  notify.warn = original_warn
end)

-- ===================================================================
-- TEST GROUP 6: SPECIAL MARKDOWN CHARACTERS & STRING FORMATTING STRESS
-- ===================================================================

run_test("format.build_diff_prompt with special markdown & format specifiers in user comment", function()
  local special_comments = {
    "Comment with `backticks` and ```codeblock```",
    "Comment with %s and %d format specifiers %X %p %%",
    "Comment with markdown headers # Title ## Subtitle **bold** _italic_",
    "Comment with quotes \"double\" 'single' \\n \\t \\r",
    "Comment with HTML/XML <script>alert('xss')</script> & <div>",
    "Comment with shell tokens $(whoami) `id` | grep foo && rm -rf /",
    "Comment with unicode 🚀 🎉 ⚡ \xe2\x82\xac",
  }

  local diff_info = {
    file_path = "src/special_%s_file.lua",
    start_line = 10,
    end_line = 20,
    diff_text = "@@ -10,5 +10,5 @@\n- old_code()\n+ new_code()\n+ -- comment with `%s` and ````diff````",
  }

  for _, comm in ipairs(special_comments) do
    local ok, prompt = pcall(function()
      return format.build_diff_prompt(comm, diff_info)
    end)
    assert_true(ok, "build_diff_prompt did not throw error for: " .. comm)
    assert_true(prompt:find(comm, 1, true) ~= nil, "Prompt contains verbatim user comment")
    assert_true(prompt:find("src/special_%s_file.lua", 1, true) ~= nil, "Prompt contains verbatim file path")
    assert_true(prompt:find("L10-L20", 1, true) ~= nil, "Prompt contains line range L10-L20")
    assert_true(prompt:find("```diff", 1, true) ~= nil, "Prompt contains diff block header")
  end
end)

run_test("format.build_diff_prompt with extreme/nil edge inputs", function()
  -- Nil inputs
  local p1 = format.build_diff_prompt(nil, nil)
  assert_true(p1:find("Diff review comment:", 1, true) ~= nil, "Default comment used when comment is nil")
  assert_true(p1:find("[No Name]", 1, true) ~= nil, "Default file_path used when diff_info is nil")
  assert_true(p1:find("L1", 1, true) ~= nil, "Default line range L1 used when line numbers missing")

  -- Empty string comment
  local p2 = format.build_diff_prompt("", { file_path = "test.txt", start_line = 5, end_line = 5, diff_text = "+line" })
  assert_true(p2:find("Diff review comment:", 1, true) ~= nil, "Default comment used when comment is empty string")
  assert_true(p2:find("L5", 1, true) ~= nil, "Line range L5 used for single line diff")

  -- Huge comment string (100k chars)
  local huge_comment = string.rep("A", 100000)
  local ok, p3 = pcall(function()
    return format.build_diff_prompt(huge_comment, { file_path = "huge.txt", start_line = 1, end_line = 1, diff_text = "test" })
  end)
  assert_true(ok, "build_diff_prompt handles 100,000 char comment without crashing")
  assert_eq(#huge_comment, 100000, "Huge comment length maintained")
end)

run_test("format.build_context_prompt with invalid/nil inputs", function()
  local p = format.build_context_prompt(nil, { snippet = "local x = 1", file_path = nil, filetype = nil, start_line = nil, end_line = nil })
  assert_true(p:find("Context snippet for review:", 1, true) ~= nil, "Default instruction used")
  assert_true(p:find("[No Name]", 1, true) ~= nil, "Default file path used")
  assert_true(p:find("text", 1, true) ~= nil, "Default filetype used")
  assert_true(p:find("L1", 1, true) ~= nil, "Default line range used")
end)

-- ===================================================================
-- SUMMARY AND EXIT
-- ===================================================================

print("\n==================================================")
print(string.format("STRESS TEST RESULTS: %d Passed, %d Failed", passed_count, failed_count))
print("==================================================")

if failed_count > 0 then
  print("\nFAILURES DETECTED:")
  for _, f in ipairs(test_failures) do
    print(f)
  end
  vim.cmd("cquit 1")
else
  print("\nALL STRESS TESTS PASSED SUCCESSFULLY!")
  vim.cmd("qall!")
end
