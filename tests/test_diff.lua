-- Headless Neovim Unit Test Suite for sagani.nvim diff module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local diff = require("sagani.diff")
local format = require("sagani.format")
local init = require("sagani")

local M = {}

function M.run()
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

  local function assert_nil(val, test_name)
    assert_eq(val, nil, test_name)
  end

  local function run_test(name, fn)
    print("\nRunning Test: " .. name)
    local ok, err = pcall(fn)
    if not ok then
      failed_count = failed_count + 1
      local msg = string.format("  ✗ EXCEPTION: %s error: %s", name, tostring(err))
      print(msg)
      table.insert(test_failures, msg)
    end
  end

  -- Fixture helper to set up split diff windows headlessly
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

  -- ==========================================================
  -- 1. SPLIT DIFF HUNK EXTRACTION TESTS
  -- ==========================================================

  run_test("get_diff_hunk_at_cursor: Split diff single line modification", function()
    local fix = setup_split_diff(
      { "line 1", "old line 2", "line 3" },
      { "line 1", "new line 2", "line 3" },
      project_root .. "/lua/sagani/diff.lua"
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 2, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)

    assert_true(hunk ~= nil, "hunk found at cursor line 2")
    assert_eq(hunk.start_line, 2, "start_line is 2")
    assert_eq(hunk.end_line, 2, "end_line is 2")
    assert_true(hunk.diff_text:find("new line 2", 1, true) ~= nil, "diff_text contains modified line")
    assert_true(hunk.file_path:find("diff.lua", 1, true) ~= nil, "file_path contains diff.lua")

    cleanup_split_diff(fix)
  end)

  run_test("get_diff_hunk_at_cursor: Multi-line addition hunk", function()
    local fix = setup_split_diff(
      { "line 1", "line 4" },
      { "line 1", "added 2", "added 3", "line 4" },
      project_root .. "/src/main.rs"
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 3, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)

    assert_true(hunk ~= nil, "hunk found at line 3")
    assert_eq(hunk.start_line, 2, "start_line is 2")
    assert_eq(hunk.end_line, 3, "end_line is 3")
    assert_true(hunk.diff_text:find("added 2", 1, true) ~= nil, "diff_text contains addition 1")
    assert_true(hunk.diff_text:find("added 3", 1, true) ~= nil, "diff_text contains addition 2")

    cleanup_split_diff(fix)
  end)

  run_test("get_diff_hunk_at_cursor: Multiple hunks in split buffers", function()
    local fix = setup_split_diff(
      { "old 1", "same 2", "same 3", "same 4", "old 5" },
      { "new 1", "same 2", "same 3", "same 4", "new 5" },
      project_root .. "/test.py"
    )

    -- Test hunk 1
    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
    local hunk1 = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_true(hunk1 ~= nil, "hunk 1 found")
    assert_eq(hunk1.start_line, 1, "hunk 1 start_line")

    -- Test hunk 2
    vim.api.nvim_win_set_cursor(fix.win_cur, { 5, 0 })
    local hunk2 = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_true(hunk2 ~= nil, "hunk 2 found")
    assert_eq(hunk2.start_line, 5, "hunk 2 start_line")

    cleanup_split_diff(fix)
  end)

  run_test("get_diff_hunk_at_cursor: Cursor positioning on unchanged line", function()
    local fix = setup_split_diff(
      { "old 1", "same 2", "same 3", "same 4", "old 5" },
      { "new 1", "same 2", "same 3", "same 4", "new 5" }
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 3, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_nil(hunk, "unchanged line returns nil hunk")

    cleanup_split_diff(fix)
  end)

  -- ==========================================================
  -- 2. CORNER CASES & NON-DIFF BUFFERS
  -- ==========================================================

  run_test("get_diff_hunk_at_cursor: Non-diff buffer returns nil", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "normal line 1", "normal line 2" })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    local hunk = diff.get_diff_hunk_at_cursor(win)
    assert_nil(hunk, "non-diff window returns nil")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("get_diff_hunk_at_cursor: Identical split diff buffers (empty diff)", function()
    local fix = setup_split_diff(
      { "same line 1", "same line 2" },
      { "same line 1", "same line 2" }
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_nil(hunk, "identical buffers return nil")

    cleanup_split_diff(fix)
  end)

  run_test("get_diff_hunk_at_cursor: Buffer filetype 'diff' parsing", function()
    local diff_lines = {
      "--- a/file.txt",
      "+++ b/file.txt",
      "@@ -1,2 +1,2 @@",
      "-old line",
      "+new line",
    }
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_lines)
    vim.bo[buf].filetype = "diff"
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    vim.api.nvim_win_set_cursor(win, { 5, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(win)
    assert_true(hunk ~= nil, "filetype diff hunk found")
    assert_eq(hunk.file_path, "file.txt", "file_path extracted from patch header")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("get_diff_hunk_at_cursor: Unnamed buffer handling ([No Name])", function()
    local fix = setup_split_diff(
      { "old" },
      { "new" }
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_true(hunk ~= nil, "hunk found for unnamed buffer")
    assert_eq(hunk.file_path, "[No Name]", "unnamed buffer file_path is [No Name]")

    cleanup_split_diff(fix)
  end)

  -- ==========================================================
  -- 3. COMMENT SENDING & PROCESS DISPATCH TESTS
  -- ==========================================================

  run_test("send_diff_comment: Successful comment dispatch with input mock", function()
    local fix = setup_split_diff(
      { "old code" },
      { "new code" },
      project_root .. "/lua/sagani/diff.lua"
    )
    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      assert_eq(opts.prompt, "AGY Diff Comment: ", "input prompt title")
      cb("Refactor this diff hunk")
    end

    local dispatched_payload = nil
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function(payload, target, opts)
      dispatched_payload = payload
      return true, nil
    end

    local res = diff.send_diff_comment({ notify = { enabled = false } })

    vim.ui.input = orig_input
    init.dispatch_prompt = orig_dispatch

    assert_true(res, "send_diff_comment returned true")
    assert_true(dispatched_payload ~= nil, "dispatch_prompt called")
    assert_true(dispatched_payload:find("Refactor this diff hunk", 1, true) ~= nil, "payload contains comment")
    assert_true(dispatched_payload:find("```diff", 1, true) ~= nil, "payload contains ```diff block")

    cleanup_split_diff(fix)
  end)

  run_test("send_diff_comment: User cancellation (nil input)", function()
    local fix = setup_split_diff({ "old" }, { "new" })
    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      cb(nil)
    end

    local dispatched = false
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function()
      dispatched = true
      return true, nil
    end

    diff.send_diff_comment({ notify = { enabled = false } })

    vim.ui.input = orig_input
    init.dispatch_prompt = orig_dispatch

    assert_eq(dispatched, false, "dispatch not executed on nil input")
    cleanup_split_diff(fix)
  end)

  run_test("send_diff_comment: Warning issued when no diff hunk at cursor", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    local dispatched = false
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function()
      dispatched = true
      return true, nil
    end

    local res = diff.send_diff_comment({ notify = { enabled = false } })

    init.dispatch_prompt = orig_dispatch

    assert_eq(res, false, "returns false when no diff hunk at cursor")
    assert_eq(dispatched, false, "dispatch not called")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("init.setup: SaganiDiff user command execution", function()
    init.setup({ notify = { enabled = false } })

    local fix = setup_split_diff(
      { "old code" },
      { "new code" },
      project_root .. "/lua/sagani/diff.lua"
    )
    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      cb("User command diff review comment")
    end

    local dispatched_payload = nil
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function(payload, target, opts)
      dispatched_payload = payload
      return true, nil
    end

    vim.cmd("SaganiDiff")

    vim.ui.input = orig_input
    init.dispatch_prompt = orig_dispatch

    assert_true(dispatched_payload ~= nil, "SaganiDiff command triggered dispatch_prompt")
    assert_true(dispatched_payload:find("User command diff review comment", 1, true) ~= nil, "payload contains user command comment")

    cleanup_split_diff(fix)
  end)

  return {
    passed = passed_count,
    failed = failed_count,
    failures = test_failures,
  }
end

if not _G.RUNNING_TEST_SUITE then
  local results = M.run()
  print("\n==========================================================")
  print(string.format("TEST RESULTS (test_diff): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
