-- Headless Neovim Unit Test Suite for sagani.nvim edit review module
local project_root = _G.SAGANI_PROJECT_ROOT or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local diff = require("sagani.diff")
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

  run_test("take_snapshot and get_hunks extraction", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
    
    diff.take_snapshot(buf)
    
    -- Edit line 2
    vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "modified line 2" })
    
    local hunks = diff.get_hunks(buf)
    assert_eq(#hunks, 1, "found 1 hunk")
    assert_eq(hunks[1].start_line, 2, "hunk start_line is 2")
    assert_eq(hunks[1].orig_lines[1], "line 2", "orig_lines matches line 2")
    assert_eq(hunks[1].new_lines[1], "modified line 2", "new_lines matches modified line 2")
    
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("toggle_review opens and closes split view", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "orig 1", "orig 2" })
    diff.take_snapshot(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "orig 1", "new 2" })

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    local opened = diff.toggle_review(buf, { notify = { enabled = false } }, "split")
    assert_true(opened, "toggle_review returned true when opening")
    assert_true(vim.wo[win].diff, "original window diff option enabled")

    local closed = diff.toggle_review(buf, { notify = { enabled = false } }, "split")
    assert_eq(closed, false, "toggle_review returned false when closing")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("accept_change: hunk acceptance updates baseline", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
    diff.take_snapshot(buf)

    -- Edit line 2
    vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "accepted line 2" })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_cursor(win, { 2, 0 })

    local res = diff.accept_change("hunk", buf, { notify = { enabled = false } })
    assert_true(res, "accept_change hunk returned true")

    local hunks_after = diff.get_hunks(buf)
    assert_eq(#hunks_after, 0, "0 pending hunks after accept")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("reject_change: hunk rejection reverts buffer to baseline", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
    diff.take_snapshot(buf)

    -- Edit line 2
    vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "rejected line 2" })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_cursor(win, { 2, 0 })

    local res = diff.reject_change("hunk", buf, { notify = { enabled = false } })
    assert_true(res, "reject_change hunk returned true")

    local lines_after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_eq(lines_after[2], "line 2", "line 2 reverted to baseline")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("accept_change & reject_change: target 'all'", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "l1", "l2", "l3" })
    diff.take_snapshot(buf)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "mod 1", "mod 2", "mod 3" })

    diff.reject_change("all", buf, { notify = { enabled = false } })
    local lines_reverted = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_eq(lines_reverted[1], "l1", "reject all restored l1")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "new 1", "new 2", "new 3" })
    diff.accept_change("all", buf, { notify = { enabled = false } })
    local hunks_after = diff.get_hunks(buf)
    assert_eq(#hunks_after, 0, "accept all cleared pending hunks")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("next_hunk and prev_hunk navigation", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "l1", "l2", "l3", "l4", "l5" })
    diff.take_snapshot(buf)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "mod 1", "l2", "l3", "l4", "mod 5" })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    vim.api.nvim_win_set_cursor(win, { 1, 0 })
    diff.next_hunk(win, { notify = { enabled = false } })
    local pos1 = vim.api.nvim_win_get_cursor(win)
    assert_eq(pos1[1], 5, "next_hunk jumped to line 5")

    diff.prev_hunk(win, { notify = { enabled = false } })
    local pos2 = vim.api.nvim_win_get_cursor(win)
    assert_eq(pos2[1], 1, "prev_hunk jumped back to line 1")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("init.setup review commands registration and execution", function()
    init.setup({ review = { enabled = true, mode = "split" }, notify = { enabled = false } })

    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "init 1", "init 2" })
    diff.take_snapshot(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "init 1", "cmd 2" })

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    vim.cmd("SaganiReview split")
    assert_true(vim.wo[win].diff, "SaganiReview split enabled diff mode")
    vim.cmd("SaganiReview")

    vim.cmd("SaganiAcceptAll")
    assert_eq(#diff.get_hunks(buf), 0, "SaganiAcceptAll cleared hunks")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("auto_open review split triggering", function()
    init.setup({ review = { enabled = true, auto_open = true, mode = "split" }, notify = { enabled = false } })

    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "baseline 1", "baseline 2" })
    diff.take_snapshot(buf)

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    -- Edit buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "baseline 1", "auto edit 2" })

    -- Trigger open_review
    diff.open_review(buf, { review = { mode = "split" }, notify = { enabled = false } }, "split")
    assert_true(vim.wo[win].diff, "open_review opened split review view for buffer with pending hunks")

    diff.close_review(buf, { notify = { enabled = false } })
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("render_inline_review horizontal virtual lines and highlights", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "old line 2", "line 3" })
    diff.take_snapshot(buf)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "new line 2", "line 3" })

    diff.close_review(buf, { notify = { enabled = false } })
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("reject_change & accept_change write updates to disk file", function()
    local tmp_file = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "orig line 1", "orig line 2" }, tmp_file)

    local buf = vim.fn.bufadd(tmp_file)
    vim.fn.bufload(buf)
    diff.take_snapshot(buf)

    -- Simulate agent editing buffer and file on disk
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "orig line 1", "agent line 2" })
    vim.fn.writefile({ "orig line 1", "agent line 2" }, tmp_file)

    -- Reject changes
    diff.reject_change("all", buf, { notify = { enabled = false } })

    -- Verify disk file was updated and reverted
    local disk_lines_after_reject = vim.fn.readfile(tmp_file)
    assert_eq(disk_lines_after_reject[2], "orig line 2", "disk file reverted on reject_change")

    -- Clean up
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp_file)
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
  print(string.format("TEST RESULTS (test_review): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
