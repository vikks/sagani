-- Adversarial Stress Test Suite for herdr-agy.nvim
-- Created by Challenger 2 for Milestone 5 verification

local project_root = vim.fn.getcwd()
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. project_root .. "/?.lua;" .. package.path

local pass_count = 0
local fail_count = 0
local test_logs = {}

local function log_test(name, success, err_msg)
  if success then
    pass_count = pass_count + 1
    table.insert(test_logs, string.format("  ✓ PASS: %s", name))
  else
    fail_count = fail_count + 1
    table.insert(test_logs, string.format("  ✗ FAIL: %s -> %s", name, tostring(err_msg)))
  end
end

local function assert_equal(actual, expected, msg)
  if actual == expected then
    return true
  else
    error(string.format("%s (Expected: %s, Got: %s)", msg or "Assertion failed", vim.inspect(expected), vim.inspect(actual)))
  end
end

local function assert_truthy(val, msg)
  if val then
    return true
  else
    error(string.format("%s (Expected truthy, Got: %s)", msg or "Assertion failed", vim.inspect(val)))
  end
end

local function assert_falsy(val, msg)
  if not val then
    return true
  else
    error(string.format("%s (Expected falsy, Got: %s)", msg or "Assertion failed", vim.inspect(val)))
  end
end

print("\n==========================================================")
print(">>> RUNNING ADVERSARIAL STRESS TEST SUITE (Challenger 2)")
print("==========================================================\n")

-- Module imports
local selection = require("herdr-agy.selection")
local diff = require("herdr-agy.diff")
local format = require("herdr-agy.format")
local topology = require("herdr-agy.topology")
local notify = require("herdr-agy.notify")
local init = require("herdr-agy")
local plugin_spec = require("plugins.herdr-agy")

--------------------------------------------------------------------------------
-- SECTION 1: Visual Selection Parsing Stress Tests
--------------------------------------------------------------------------------
print("--- Section 1: Selection Stress Tests ---")

-- Test 1.1: UTF-8 Multi-Byte Character Handling in Visual Selection
do
  local ok, err = pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "hello 🚀 world 汉字",
      "second line with 🔥 emoji",
    })
    vim.api.nvim_set_current_buf(buf)
    
    -- Mock visual marks for characterwise selection across UTF-8 text
    vim.fn.setpos("'<", { buf, 1, 7, 0 })  -- Starts at 🚀
    vim.fn.setpos("'>", { buf, 1, 23, 0 }) -- Ends after 汉字 (byte pos 23)
    
    local sel = selection.get_visual_selection(buf)
    assert_equal(sel.filetype, "text", "Default filetype for unlisted buffer")
    assert_truthy(sel.snippet:find("🚀"), "Snippet contains UTF-8 emoji")
    assert_truthy(sel.snippet:find("汉字"), "Snippet contains CJK characters")
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
  log_test("Selection: UTF-8 multi-byte characters (emoji/CJK)", ok, err)
end

-- Test 1.2: Blockwise selection on uneven line lengths
do
  local ok, err = pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "1234567890",
      "12",
      "12345",
    })
    vim.api.nvim_set_current_buf(buf)
    
    -- Set visual mode to blockwise \22
    vim.cmd("normal! \22\27")
    vim.fn.setpos("'<", { buf, 1, 4, 0 })
    vim.fn.setpos("'>", { buf, 3, 7, 0 })
    
    local sel = selection.get_visual_selection(buf)
    assert_equal(sel.start_line, 1)
    assert_equal(sel.end_line, 3)
    local lines = vim.split(sel.snippet, "\n")
    assert_equal(#lines, 3)
    assert_equal(lines[1], "4567")
    assert_equal(lines[2], "") -- line 2 was shorter than min_col (4)
    assert_equal(lines[3], "45") -- line 3 length 5, sub(4, 7) gives "45"
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
  log_test("Selection: Blockwise selection on uneven line lengths", ok, err)
end

-- Test 1.3: Selection on empty buffer
do
  local ok, err = pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_set_current_buf(buf)
    
    local sel = selection.get_visual_selection(buf)
    assert_equal(type(sel), "table")
    assert_equal(sel.snippet, "")
    assert_equal(sel.start_line, 1)
    assert_equal(sel.end_line, 1)
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
  log_test("Selection: Empty buffer returns empty snippet safely", ok, err)
end

-- Test 1.4: Selection on huge buffer (10,000 lines)
do
  local ok, err = pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    local huge_lines = {}
    for i = 1, 10000 do
      huge_lines[i] = "line " .. i .. " content"
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, huge_lines)
    vim.api.nvim_set_current_buf(buf)
    
    vim.fn.setpos("'<", { buf, 1, 1, 0 })
    vim.fn.setpos("'>", { buf, 10000, 10, 0 })
    
    local sel = selection.get_visual_selection(buf)
    assert_equal(sel.start_line, 1)
    assert_equal(sel.end_line, 10000)
    assert_truthy(#sel.snippet > 100000, "Huge snippet extracted without OOM")
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
  log_test("Selection: Huge buffer selection (10,000 lines)", ok, err)
end

-- Test 1.5: Invalid bufnr handling
do
  local ok, err = pcall(function()
    -- Passing non-number or negative bufnr defaults to 0 (current buffer)
    local sel1 = selection.get_visual_selection(-1)
    assert_equal(type(sel1), "table")
    
    local sel2 = selection.get_visual_selection("invalid")
    assert_equal(type(sel2), "table")
    
    local sel3 = selection.get_visual_selection(nil)
    assert_equal(type(sel3), "table")
  end)
  log_test("Selection: Invalid bufnr type handling defaults to current buf", ok, err)
end

--------------------------------------------------------------------------------
-- SECTION 2: Diff Hunk Extraction Stress Tests
--------------------------------------------------------------------------------
print("--- Section 2: Diff Stress Tests ---")

-- Test 2.1: Diff filetype with malformed or deletion-only headers
do
  local ok, err = pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "diff"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "--- a/test.txt",
      "+++ b/test.txt",
      "@@ -1,5 @@", -- Missing plus count
      "-deleted line",
      " context line",
    })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_cursor(win, { 4, 0 })
    
    local hunk = diff.get_diff_hunk_at_cursor(win)
    assert_truthy(hunk, "Hunk found even with missing plus count")
    assert_equal(hunk.file_path, "test.txt")
    assert_equal(hunk.start_line, 1)
    assert_equal(hunk.end_line, 1)
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
  log_test("Diff: Filetype 'diff' with missing plus count header", ok, err)
end

-- Test 2.2: Diff filetype with multi-file patches
do
  local ok, err = pcall(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "diff"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "--- a/file1.lua",
      "+++ b/file1.lua",
      "@@ -1,2 +1,2 @@",
      "-old line 1",
      "+new line 1",
      "--- a/file2.lua",
      "+++ b/file2.lua",
      "@@ -10,3 +10,4 @@",
      " context",
      "+added line",
    })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    -- Place cursor on line 9 (in file2.lua hunk)
    vim.api.nvim_win_set_cursor(win, { 9, 0 })
    
    local hunk = diff.get_diff_hunk_at_cursor(win)
    assert_truthy(hunk, "Hunk found in second file")
    assert_equal(hunk.file_path, "file2.lua")
    assert_equal(hunk.start_line, 10)
    assert_equal(hunk.end_line, 13)
    assert_truthy(hunk.diff_text:find("%+added line"), "Hunk text contains added line")
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
  log_test("Diff: Multi-file diff buffer identifies correct file path & range", ok, err)
end

-- Test 2.3: Invalid win_id handling
do
  local ok, err = pcall(function()
    local hunk1 = diff.get_diff_hunk_at_cursor(99999)
    assert_equal(hunk1, nil)
    
    local hunk2 = diff.get_diff_hunk_at_cursor(-5)
    assert_equal(hunk2, nil)
    
    local hunk3 = diff.get_diff_hunk_at_cursor("invalid")
    assert_equal(hunk3, nil)
  end)
  log_test("Diff: Invalid win_id returns nil gracefully", ok, err)
end

-- Test 2.4: Split diff mode when peer window has empty buffer
do
  local ok, err = pcall(function()
    local buf1 = vim.api.nvim_create_buf(false, true)
    local buf2 = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "line 1", "line 2", "line 3" })
    vim.api.nvim_buf_set_lines(buf2, 0, -1, false, {})
    
    local win1 = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win1, buf1)
    vim.wo[win1].diff = true
    
    local win2 = vim.api.nvim_open_win(buf2, false, { split = "right", width = 30, height = 10 })
    vim.wo[win2].diff = true
    
    vim.api.nvim_win_set_cursor(win1, { 2, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(win1)
    assert_truthy(hunk, "Hunk extracted when peer buffer is empty")
    
    vim.wo[win1].diff = false
    vim.wo[win2].diff = false
    vim.api.nvim_win_close(win2, true)
    vim.api.nvim_buf_delete(buf1, { force = true })
    vim.api.nvim_buf_delete(buf2, { force = true })
  end)
  log_test("Diff: Split diff mode against empty peer buffer", ok, err)
end

--------------------------------------------------------------------------------
-- SECTION 3: Prompt Format Stress Tests
--------------------------------------------------------------------------------
print("--- Section 3: Format Stress Tests ---")

-- Test 3.1: Nested code blocks in instruction and snippet
do
  local ok, err = pcall(function()
    local instruction = "Review this ```lua code``` snippet"
    local sel = {
      file_path = "src/demo.md",
      filetype = "markdown",
      start_line = 10,
      end_line = 15,
      snippet = "```python\nprint('hello')\n```",
    }
    local formatted = format.build_context_prompt(instruction, sel)
    assert_truthy(formatted:find("Review this ```lua code``` snippet"))
    assert_truthy(formatted:find("L10%-L15"))
    assert_truthy(formatted:find("```python"))
  end)
  log_test("Format: Context prompt with nested backticks & markdown code blocks", ok, err)
end

-- Test 3.2: Malformed selection table types
do
  local ok, err = pcall(function()
    local res1 = format.build_context_prompt(nil, nil)
    assert_truthy(res1:find("%[No Name%]"))
    assert_truthy(res1:find("%(L1%)"))
    
    local res2 = format.build_context_prompt(12345, {
      file_path = 999,
      filetype = false,
      start_line = "ten",
      end_line = "twenty",
      snippet = nil,
    })
    assert_truthy(res2:find("%[No Name%]"))
    assert_truthy(res2:find("%(L1%)"))
  end)
  log_test("Format: Malformed selection table types handle default fallbacks", ok, err)
end

-- Test 3.3: Huge payload formatting (1 MB snippet text)
do
  local ok, err = pcall(function()
    local huge_str = string.rep("x", 1000000)
    local formatted = format.build_context_prompt("Huge snippet test", {
      file_path = "huge.txt",
      filetype = "text",
      start_line = 1,
      end_line = 50000,
      snippet = huge_str,
    })
    assert_truthy(#formatted > 1000000, "1MB payload formatted without error")
  end)
  log_test("Format: Huge payload (1 MB snippet text) formatted without failure", ok, err)
end

--------------------------------------------------------------------------------
-- SECTION 4: LazyVim Spec & WhichKey Command Wiring Tests
--------------------------------------------------------------------------------
print("--- Section 4: Plugin Spec & Command Wiring Tests ---")

-- Test 4.1: LazyVim Spec Validation
do
  local ok, err = pcall(function()
    assert_equal(type(plugin_spec), "table", "Spec returns table")
    assert_equal(#plugin_spec, 2, "Spec has 2 plugin definitions (WhichKey + plugin)")
    
    local wk_spec = plugin_spec[1]
    assert_equal(wk_spec[1], "folke/which-key.nvim")
    assert_equal(wk_spec.optional, true)
    assert_equal(wk_spec.opts.spec[1].group, "AGY / Herdr")
    
    local main_spec = plugin_spec[2]
    assert_equal(main_spec.name, "herdr-agy.nvim")
    assert_truthy(#main_spec.cmd >= 6, "All 6 commands listed in cmd")
    assert_truthy(#main_spec.keys >= 7, "All 7 keymaps defined in keys")
  end)
  log_test("Plugin Spec: Validated LazyVim spec structure & WhichKey group", ok, err)
end

-- Test 4.2: Idempotent Setup Execution
do
  local ok, err = pcall(function()
    init.setup({ target_agent = "test_agent_1" })
    assert_equal(init.options.target_agent, "test_agent_1")
    
    init.setup({ target_agent = "test_agent_2" })
    assert_equal(init.options.target_agent, "test_agent_2")
  end)
  log_test("Plugin Spec: Repeated setup() calls are idempotent and update options", ok, err)
end

-- Test 4.3: User Commands execution tests
do
  local ok, err = pcall(function()
    -- Ensure commands exist and can be called via vim.cmd
    local commands = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
    }
    for _, cmd_name in ipairs(commands) do
      local exists = vim.fn.exists(":" .. cmd_name)
      assert_equal(exists, 2, "Command :" .. cmd_name .. " exists")
    end
  end)
  log_test("Plugin Spec: Registered Neovim user commands exist", ok, err)
end

--------------------------------------------------------------------------------
-- SECTION 5: Missing Binaries & Environment Edge Cases
--------------------------------------------------------------------------------
print("--- Section 5: Missing Binaries & Environment Edge Cases ---")

-- Test 5.1: Non-Herdr environment discovery
do
  local ok, err = pcall(function()
    local pane, discover_err = topology.discover_target_pane({
      ignore_herdr_env = false,
      agents = {
        { pane_id = "p1", agent = "agy", workspace_id = "w1", tab_id = "t1" }
      }
    })
    -- Without env.in_herdr and without ignore_herdr_env, should return error
    if vim.env.HERDR_ENV == nil or vim.env.HERDR_ENV == "" then
      assert_equal(pane, nil)
      assert_truthy(discover_err:find("HERDR_ENV missing"))
    end
  end)
  log_test("Env Edge Cases: Disallowing auto-discovery outside HERDR_ENV", ok, err)
end

-- Test 5.2: Corrupted / Garbage JSON output from 'herdr agent list'
do
  local ok, err = pcall(function()
    local mock_runner = function(cmd)
      return "{ invalid garbage json string <<<", 0
    end
    local agents, list_err = topology.list_agents(mock_runner)
    assert_equal(agents, nil)
    assert_truthy(list_err:find("Failed to parse JSON"))
  end)
  log_test("Env Edge Cases: Corrupted JSON from 'herdr agent list' handled cleanly", ok, err)
end

-- Test 5.3: Command runner returning non-zero exit code
do
  local ok, err = pcall(function()
    local mock_runner = function(cmd)
      return "herdr: error: permission denied", 127
    end
    local agents, list_err = topology.list_agents(mock_runner)
    assert_equal(agents, nil)
    assert_truthy(list_err:find("127"))
  end)
  log_test("Env Edge Cases: Process exit code failure handled cleanly", ok, err)
end

-- Test 5.4: Missing 'herdr' executable during dispatch_prompt
do
  local ok, err = pcall(function()
    -- Test with pane_override and mock missing executable
    local old_executable = vim.fn.executable
    vim.fn.executable = function(bin)
      if bin == "herdr" then return 0 end
      return old_executable(bin)
    end
    
    local ok_res, dispatch_err = init.dispatch_prompt("test prompt", "p99", { notify = false })
    vim.fn.executable = old_executable
    
    assert_equal(ok_res, false)
    assert_truthy(dispatch_err:find("not found in PATH"))
  end)
  log_test("Env Edge Cases: Missing 'herdr' binary during dispatch returns error cleanly", ok, err)
end

-- Test 5.5: Empty or whitespace-only prompt dispatch
do
  local ok, err = pcall(function()
    local ok1, err1 = init.dispatch_prompt("", "p1", { notify = false })
    assert_equal(ok1, false)
    assert_truthy(err1:find("Invalid prompt text"))
    
    local ok2, err2 = init.dispatch_prompt(nil, "p1", { notify = false })
    assert_equal(ok2, false)
    assert_truthy(err2:find("Invalid prompt text"))
  end)
  log_test("Env Edge Cases: Empty or nil prompt text rejected cleanly", ok, err)
end

--------------------------------------------------------------------------------
-- SECTION 6: Topology Tiers & Robustness Stress Tests
--------------------------------------------------------------------------------
print("--- Section 6: Topology Tiers & Candidate Robustness ---")

-- Test 6.1: Candidate filtering with malformed agent objects in JSON
do
  local ok, err = pcall(function()
    local malformed_agents = {
      "not a table",
      { agent = 123, pane_id = "p1" },
      { agent = "agy", pane_id = nil },
      { agent = "agy", pane_id = "" },
      { agent = "agy", pane_id = "p10", workspace_id = "w1", tab_id = "t1" }
    }
    local pane, discover_err, info = topology.discover_target_pane({
      agents = malformed_agents,
      ignore_herdr_env = true,
      workspace_id = "w1",
      tab_id = "t1"
    })
    assert_equal(pane, "p10")
    assert_equal(discover_err, nil)
  end)
  log_test("Topology: Malformed agent objects in list filtered out gracefully", ok, err)
end

-- Test 6.2: Tier 1 to Tier 6 progression ranking
do
  local ok, err = pcall(function()
    local agents = {
      { agent = "agy", pane_id = "global_p", workspace_id = "other_w", cwd = "/other" },
      { agent = "agy", pane_id = "cwd_p", workspace_id = "other_w", cwd = "/my/project" },
      { agent = "agy", pane_id = "same_ws_p", workspace_id = "w1", tab_id = "other_t" },
      { agent = "agy", pane_id = "same_tab_p", workspace_id = "w1", tab_id = "t1" }
    }
    
    local pane, _, _ = topology.discover_target_pane({
      agents = agents,
      workspace_id = "w1",
      tab_id = "t1",
      caller_pane_id = "caller_p",
      cwd = "/my/project",
      ignore_herdr_env = true
    })
    assert_equal(pane, "same_tab_p", "Selects Tier 1 (same tab + same workspace)")
  end)
  log_test("Topology: Selection follows exact Tier 1 preference ordering", ok, err)
end

--------------------------------------------------------------------------------
-- SECTION 7: Notification System Robustness
--------------------------------------------------------------------------------
print("--- Section 7: Notification Robustness ---")

-- Test 7.1: Notification levels normalization & custom title options
do
  local ok, err = pcall(function()
    -- Level as number, string, invalid type
    notify.notify("test info", "INFO", { title = "Custom Title" })
    notify.notify("test warn", "warning", { notify = { title = "Sub Title" } })
    notify.notify("test error", vim.log.levels.ERROR)
    notify.notify("test default level", 9999)
  end)
  log_test("Notify: Custom notification titles and levels normalized without error", ok, err)
end

-- Test 7.2: Notification suppression flags
do
  local ok, err = pcall(function()
    local called = false
    local orig_notify = vim.notify
    vim.notify = function() called = true end
    
    notify.info("suppressed msg", { notify = false })
    assert_equal(called, false, "Suppressed by notify = false")
    
    notify.info("suppressed msg 2", { notify = { enabled = false } })
    assert_equal(called, false, "Suppressed by notify.enabled = false")
    
    vim.notify = orig_notify
  end)
  log_test("Notify: Explicit suppression flags prevent vim.notify execution", ok, err)
end

--------------------------------------------------------------------------------
-- SECTION 8: Interactive Commands & Input Handling
--------------------------------------------------------------------------------
print("--- Section 8: Interactive Commands & User Inputs ---")

-- Test 8.1: HerdrAgySelectTarget command setting and clearing override
do
  local ok, err = pcall(function()
    -- Set override
    local orig_ui_input = vim.ui.input
    vim.ui.input = function(opts, cb) cb("p99") end
    vim.cmd("HerdrAgySelectTarget")
    assert_equal(init.options.pane_override, "p99")
    
    -- Clear override
    vim.ui.input = function(opts, cb) cb("") end
    vim.cmd("HerdrAgySelectTarget")
    assert_equal(init.options.pane_override, nil)
    
    vim.ui.input = orig_ui_input
  end)
  log_test("Commands: HerdrAgySelectTarget sets and clears pane override", ok, err)
end

-- Test 8.2: HerdrAgyPrompt command with argument parsing
do
  local ok, err = pcall(function()
    local dispatched_prompt = nil
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function(p) dispatched_prompt = p return true end
    
    vim.cmd("HerdrAgyPrompt hello from user")
    assert_equal(dispatched_prompt, "hello from user")
    
    init.dispatch_prompt = orig_dispatch
  end)
  log_test("Commands: HerdrAgyPrompt passes multi-word command args to dispatch", ok, err)
end

--------------------------------------------------------------------------------
-- SUMMARY
--------------------------------------------------------------------------------
print("\n==========================================================")
for _, log_msg in ipairs(test_logs) do
  print(log_msg)
end
print(string.format("\nADVERSARIAL STRESS RESULTS: %d Passed, %d Failed", pass_count, fail_count))
print("==========================================================\n")

if fail_count > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
