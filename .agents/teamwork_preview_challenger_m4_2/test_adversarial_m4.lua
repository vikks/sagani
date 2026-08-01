-- Empirical Adversarial Test Harness for Milestone 4 (herdr-agy.nvim)
-- Location: .agents/teamwork_preview_challenger_m4_2/test_adversarial_m4.lua

local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local init = require("herdr-agy")
local diff = require("herdr-agy.diff")
local notify = require("herdr-agy.notify")
local format = require("herdr-agy.format")
local topology = require("herdr-agy.topology")

local M = {}

function M.run()
  local passed_count = 0
  local failed_count = 0
  local test_failures = {}
  local notifications = {}

  local orig_notify_info = notify.info
  local orig_notify_warn = notify.warn
  local orig_notify_error = notify.error

  local function clear_notifications()
    notifications = {}
  end

  notify.info = function(msg, opts)
    table.insert(notifications, { level = "info", msg = msg })
    if orig_notify_info then orig_notify_info(msg, opts) end
  end

  notify.warn = function(msg, opts)
    table.insert(notifications, { level = "warn", msg = msg })
    if orig_notify_warn then orig_notify_warn(msg, opts) end
  end

  notify.error = function(msg, opts)
    table.insert(notifications, { level = "error", msg = msg })
    if orig_notify_error then orig_notify_error(msg, opts) end
  end

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

  local function run_test(name, fn)
    print("\nRunning Test: " .. name)
    clear_notifications()
    local ok, err = pcall(fn)
    if not ok then
      failed_count = failed_count + 1
      local msg = string.format("  ✗ EXCEPTION: %s error: %s", name, tostring(err))
      print(msg)
      table.insert(test_failures, msg)
    end
  end

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

  init.setup({ notify = { enabled = true } })

  -- ==========================================================
  -- SECTION 1: COMMAND & KEYMAP REGISTRATION
  -- ==========================================================

  run_test("Command: :HerdrAgyDiff user command exists", function()
    assert_eq(vim.fn.exists(":HerdrAgyDiff"), 2, ":HerdrAgyDiff registered in neovim")
  end)

  run_test("Plugin Spec: <leader>ad keymap dispatch mapping", function()
    local spec_path = project_root .. "/plugins/herdr-agy.lua"
    local specs = dofile(spec_path)
    local main_spec = nil
    for _, s in ipairs(specs) do
      if type(s) == "table" and s.name == "herdr-agy.nvim" then
        main_spec = s
      end
    end
    assert_true(main_spec ~= nil, "main_spec found")
    local found_ad = false
    for _, k in ipairs(main_spec.keys) do
      if k[1] == "<leader>ad" then
        found_ad = true
        assert_eq(k[2], "<cmd>HerdrAgyDiff<cr>", "<leader>ad maps to <cmd>HerdrAgyDiff<cr>")
      end
    end
    assert_true(found_ad, "<leader>ad keymap found in spec")
  end)

  -- ==========================================================
  -- SECTION 2: BUFFER STATES ADVERSARIAL TESTING FOR :HerdrAgyDiff
  -- ==========================================================

  run_test("Buffer State: Normal clean buffer (no diff) triggers warning notification", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    local res = diff.send_diff_comment({ notify = { enabled = true } })

    assert_false(res, "send_diff_comment returns false on normal buffer with no diff")
    assert_true(#notifications > 0, "notification issued")
    assert_eq(notifications[1].level, "warn", "warning notification level")
    assert_true(notifications[1].msg:find("No diff hunk found", 1, true) ~= nil, "warning message contents")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("Buffer State: Un-saved [No Name] buffer triggers warning notification", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved content line 1", "unsaved content line 2" })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    local res = diff.send_diff_comment({ notify = { enabled = true } })

    assert_false(res, "send_diff_comment returns false on [No Name] buffer")
    assert_true(#notifications > 0, "notification issued")
    assert_eq(notifications[1].level, "warn", "warning notification level")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("Buffer State: In-memory unsaved changes vs Git HEAD (Git Fixture)", function()
    -- Create temporary git repo fixture
    local tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")
    local test_file = tmp_dir .. "/sample.txt"
    
    -- Initialize git repo in tmp_dir
    vim.system({ "git", "init" }, { cwd = tmp_dir }):wait()
    vim.system({ "git", "config", "user.name", "Test" }, { cwd = tmp_dir }):wait()
    vim.system({ "git", "config", "user.email", "test@test.com" }, { cwd = tmp_dir }):wait()
    
    -- Create initial file & commit
    local f = io.open(test_file, "w")
    if f then
      f:write("line 1\nline 2 old\nline 3\n")
      f:close()
    end
    vim.system({ "git", "add", "sample.txt" }, { cwd = tmp_dir }):wait()
    vim.system({ "git", "commit", "-m", "initial" }, { cwd = tmp_dir }):wait()

    -- Load file into buffer and modify in memory without saving to disk
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, test_file)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2 NEW IN MEMORY", "line 3" })

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_cursor(win, { 2, 0 })

    local cwd_orig = vim.fn.getcwd()
    vim.cmd("cd " .. tmp_dir)

    local hunk = diff.get_diff_hunk_at_cursor(win)

    vim.cmd("cd " .. cwd_orig)
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp_dir, "rf")

    assert_true(hunk ~= nil, "hunk found for unsaved in-memory modification vs git HEAD")
    assert_eq(hunk.start_line, 2, "start_line is 2")
    assert_true(hunk.diff_text:find("NEW IN MEMORY", 1, true) ~= nil, "diff_text contains in-memory modification")
  end)

  run_test("Buffer State: Cursor on unchanged line in git modified file returns nil", function()
    local tmp_dir = vim.fn.tempname()
    vim.fn.mkdir(tmp_dir, "p")
    local test_file = tmp_dir .. "/sample.txt"

    vim.system({ "git", "init" }, { cwd = tmp_dir }):wait()
    vim.system({ "git", "config", "user.name", "Test" }, { cwd = tmp_dir }):wait()
    vim.system({ "git", "config", "user.email", "test@test.com" }, { cwd = tmp_dir }):wait()

    local f = io.open(test_file, "w")
    if f then
      f:write("line 1\nline 2 old\nline 3\n")
      f:close()
    end
    vim.system({ "git", "add", "sample.txt" }, { cwd = tmp_dir }):wait()
    vim.system({ "git", "commit", "-m", "initial" }, { cwd = tmp_dir }):wait()

    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, test_file)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2 NEW IN MEMORY", "line 3" })

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    -- Cursor on line 1 (unchanged)
    vim.api.nvim_win_set_cursor(win, { 1, 0 })

    local cwd_orig = vim.fn.getcwd()
    vim.cmd("cd " .. tmp_dir)

    local hunk = diff.get_diff_hunk_at_cursor(win)

    vim.cmd("cd " .. cwd_orig)
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.fn.delete(tmp_dir, "rf")

    assert_nil(hunk, "unchanged line returns nil hunk")
  end)

  run_test("Buffer State: Split diff buffer with active diff hunk", function()
    local fix = setup_split_diff(
      { "alpha", "beta", "gamma" },
      { "alpha", "BETA_MODIFIED", "gamma" },
      project_root .. "/test_diff_split.lua"
    )
    vim.api.nvim_win_set_cursor(fix.win_cur, { 2, 0 })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      cb("Inline comment on split diff line 2")
    end

    local dispatched_payload = nil
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function(payload, target, opts)
      dispatched_payload = payload
      return true, nil
    end

    vim.cmd("HerdrAgyDiff")

    vim.ui.input = orig_input
    init.dispatch_prompt = orig_dispatch

    assert_true(dispatched_payload ~= nil, "dispatched_payload captured from :HerdrAgyDiff")
    assert_true(dispatched_payload:find("BETA_MODIFIED", 1, true) ~= nil, "payload contains diff text")
    assert_true(dispatched_payload:find("Inline comment on split diff line 2", 1, true) ~= nil, "payload contains user comment")

    cleanup_split_diff(fix)
  end)

  run_test("Buffer State: Filetype 'diff' patch buffer extraction", function()
    local patch = {
      "--- a/src/lib.rs",
      "+++ b/src/lib.rs",
      "@@ -10,3 +10,3 @@ fn test() {",
      "-    let x = 1;",
      "+    let x = 42;",
      "     let y = 2;",
    }
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, patch)
    vim.bo[buf].filetype = "diff"
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_cursor(win, { 5, 0 })

    local hunk = diff.get_diff_hunk_at_cursor(win)
    assert_true(hunk ~= nil, "hunk found in patch buffer")
    assert_eq(hunk.file_path, "src/lib.rs", "parsed file path from patch header")
    assert_eq(hunk.start_line, 10, "start_line is 10")
    assert_eq(hunk.end_line, 12, "end_line is 12")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("Buffer State: Untracked file (not in git) triggers warning", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, project_root .. "/non_existent_untracked_file_12345.lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local a = 1" })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    local res = diff.send_diff_comment({ notify = { enabled = true } })
    assert_false(res, "send_diff_comment returns false for untracked file")
    assert_true(#notifications > 0 and notifications[1].level == "warn", "warn notification issued")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  -- ==========================================================
  -- SECTION 3: USER INPUT & CANCELLATION
  -- ==========================================================

  run_test("User Input: Pressing Esc (nil input) cancels diff comment", function()
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

    diff.send_diff_comment({ notify = { enabled = true } })

    vim.ui.input = orig_input
    init.dispatch_prompt = orig_dispatch

    assert_false(dispatched, "dispatch not executed when user cancels input")
    assert_true(#notifications > 0 and notifications[1].msg:find("cancelled", 1, true) ~= nil, "cancellation info notification issued")

    cleanup_split_diff(fix)
  end)

  -- ==========================================================
  -- SECTION 4: NON-BLOCKING PROCESS DISPATCH & VIM.SYSTEM BEHAVIOR
  -- ==========================================================

  run_test("Process Dispatch: Verify vim.system sync wait behavior and measure latency", function()
    local orig_discover = topology.discover_target_pane
    local orig_executable = vim.fn.executable
    topology.discover_target_pane = function() return "pane-99", nil end
    vim.fn.executable = function(cmd) return 1 end

    local orig_vim_system = vim.system
    local sys_obj_waited = false

    -- Intercept vim.system to detect if :wait() is invoked on returned SystemObj
    vim.system = function(cmd, opts, cb)
      local sys_obj = orig_vim_system(cmd, opts, cb)
      local orig_wait = sys_obj.wait
      sys_obj.wait = function(self, timeout)
        sys_obj_waited = true
        return orig_wait(self, timeout)
      end
      return sys_obj
    end

    -- Run dispatch_prompt targeting sleep command
    -- We pass a command that delays execution to measure blocking
    local start_time = vim.loop.hrtime()
    local res, err = init.dispatch_prompt("test timing prompt", "pane-99")
    local elapsed_ms = (vim.loop.hrtime() - start_time) / 1e6

    vim.system = orig_vim_system
    topology.discover_target_pane = orig_discover
    vim.fn.executable = orig_executable

    assert_true(sys_obj_waited, "init.dispatch_prompt calls :wait() synchronously on vim.system return object")
    print(string.format("  [EMPIRICAL MEASUREMENT] dispatch_prompt execution completed in %.2f ms (sys_obj_waited = %s)", elapsed_ms, tostring(sys_obj_waited)))
  end)

  -- ==========================================================
  -- SECTION 5: ERROR NOTIFICATIONS & DEFENSIVE ERROR HANDLING
  -- ==========================================================

  run_test("Error Notification: Target pane not found in topology", function()
    init.options.pane_override = nil
    local orig_discover = topology.discover_target_pane
    topology.discover_target_pane = function()
      return nil, "No AGY agent pane available"
    end

    local ok, err = init.dispatch_prompt("Test prompt", nil, { notify = { enabled = true } })

    topology.discover_target_pane = orig_discover

    assert_false(ok, "dispatch_prompt returns false when pane not found")
    assert_eq(err, "No AGY agent pane available", "error message returned")
    assert_true(#notifications > 0 and notifications[1].level == "error", "error notification issued")
  end)

  run_test("Error Notification: Invalid empty prompt text", function()
    local ok, err = init.dispatch_prompt("", "pane-1", { notify = { enabled = true } })
    assert_false(ok, "dispatch_prompt returns false on empty string")
    assert_true(#notifications > 0 and notifications[1].level == "error", "error notification issued for empty prompt")
  end)

  run_test("Error Notification: Failed process execution (exit code != 0)", function()
    local orig_discover = topology.discover_target_pane
    local orig_executable = vim.fn.executable
    local orig_system = vim.system

    topology.discover_target_pane = function() return "pane-99", nil end
    vim.fn.executable = function(cmd) return 1 end

    vim.system = function(cmd, opts)
      return {
        wait = function()
          return { code = 1, stderr = "herdr error: pane target inaccessible", stdout = "" }
        end
      }
    end

    local ok, err = init.dispatch_prompt("Test error", "pane-99", { notify = { enabled = true } })

    topology.discover_target_pane = orig_discover
    vim.fn.executable = orig_executable
    vim.system = orig_system

    assert_false(ok, "dispatch_prompt returns false when process fails")
    assert_true(err ~= nil and err:find("exit code 1", 1, true) ~= nil, "error message contains exit code")
    assert_true(#notifications > 0 and notifications[1].level == "error", "error notification issued on non-zero exit")
  end)

  notify.info = orig_notify_info
  notify.warn = orig_notify_warn
  notify.error = orig_notify_error

  return {
    passed = passed_count,
    failed = failed_count,
    failures = test_failures,
  }
end

if not _G.RUNNING_TEST_SUITE then
  local results = M.run()
  print("\n==========================================================")
  print(string.format("TEST RESULTS (test_adversarial_m4): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
