-- Headless Neovim Empirical Stress Test Suite for sagani.nvim
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local init = require("sagani")
local topology = require("sagani.topology")
local selection = require("sagani.selection")
local diff = require("sagani.diff")
local format = require("sagani.format")
local notify = require("sagani.notify")

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

  local function assert_false(cond, test_name)
    assert_eq(cond, false, test_name)
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

  -- Save original env & functions
  local orig_env_herdr = vim.env.HERDR_ENV
  local orig_env_pane = vim.env.HERDR_PANE_ID
  local orig_env_tab = vim.env.HERDR_TAB_ID
  local orig_env_ws = vim.env.HERDR_WORKSPACE_ID
  local orig_executable = vim.fn.executable
  local orig_system = vim.system
  local orig_ui_input = vim.ui.input
  local orig_notify = vim.notify

  local function restore_env()
    vim.env.HERDR_ENV = orig_env_herdr
    vim.env.HERDR_PANE_ID = orig_env_pane
    vim.env.HERDR_TAB_ID = orig_env_tab
    vim.env.HERDR_WORKSPACE_ID = orig_env_ws
    vim.fn.executable = orig_executable
    vim.system = orig_system
    vim.ui.input = orig_ui_input
    vim.notify = orig_notify
  end

  -- ==========================================================
  -- 1. TOPOLOGY MODULE STRESS TESTS
  -- ==========================================================

  run_test("topology_stress: missing herdr executable handling in list_agents", function()
    vim.fn.executable = function(cmd)
      if cmd == "herdr" then return 0 end
      return orig_executable(cmd)
    end

    local agents, err = topology.list_agents()
    assert_nil(agents, "list_agents returns nil when herdr binary is missing")
    assert_true(type(err) == "string" and err:find("not found in PATH", 1, true) ~= nil, "returns binary missing error string")

    restore_env()
  end)

  run_test("topology_stress: malformed JSON responses in list_agents", function()
    local malformed_payloads = {
      "Internal Server Error 500",
      "<html><head><title>502 Bad Gateway</title></head></html>",
      "",
      "null",
      "123.45",
      "{\"status\": \"error\"}",
      "{\"result\": null}",
      "{\"result\": {\"agents\": \"invalid_type\"}}",
      "{\"result\": {\"agents\": 12345}}",
      "{\"result\": {\"agents\": true}}",
    }

    for idx, payload in ipairs(malformed_payloads) do
      local mock_runner = function(cmd)
        return payload, 0
      end
      local agents, err = topology.list_agents(mock_runner)
      assert_nil(agents, string.format("malformed payload #%d returns nil agents", idx))
      assert_true(type(err) == "string", string.format("malformed payload #%d returns error string", idx))
    end
  end)

  run_test("topology_stress: non-table items in agents array handled safely", function()
    local mock_json = vim.json.encode({
      result = {
        agents = {
          "string_item",
          12345,
          true,
          false,
          { agent = "other_agent", pane_id = "p1" },
          { agent = "agy", pane_id = "" }, -- empty pane_id
          { agent = "agy", pane_id = "p99", workspace_id = "w1", tab_id = "t1" },
        }
      }
    })

    local mock_runner = function(cmd) return mock_json, 0 end

    vim.env.HERDR_ENV = "1"
    vim.env.HERDR_PANE_ID = "p0"
    vim.env.HERDR_TAB_ID = "t1"
    vim.env.HERDR_WORKSPACE_ID = "w1"

    local pane_id, err = topology.discover_target_pane({ runner = mock_runner })
    assert_eq(pane_id, "p99", "skips non-table elements and empty pane_id to find p99")
    assert_nil(err, "err is nil on successful discovery")

    restore_env()
  end)

  run_test("topology_stress: invalid target_agent input types", function()
    local pane1, err1 = topology.discover_target_pane({ target_agent = 12345 })
    assert_nil(pane1, "non-string target_agent (number) returns nil")
    assert_true(err1:find("Invalid target_agent", 1, true) ~= nil, "error message specifies invalid target_agent")

    local pane2, err2 = topology.discover_target_pane({ target_agent = true })
    assert_nil(pane2, "non-string target_agent (boolean) returns nil")
    assert_true(err2:find("Invalid target_agent", 1, true) ~= nil, "error message specifies invalid target_agent")

    local pane3, err3 = topology.discover_target_pane({ target_agent = {} })
    assert_nil(pane3, "non-string target_agent (table) returns nil")
    assert_true(err3:find("Invalid target_agent", 1, true) ~= nil, "error message specifies invalid target_agent")
  end)

  run_test("topology_stress: pane_override invalid types", function()
    vim.env.HERDR_ENV = "1"
    vim.env.HERDR_PANE_ID = "p0"
    vim.env.HERDR_TAB_ID = "t1"
    vim.env.HERDR_WORKSPACE_ID = "w1"

    local test_agents = {
      { agent = "agy", pane_id = "p_discovered", workspace_id = "w1", tab_id = "t1" }
    }

    -- boolean pane_override falls through to auto-discovery
    local pane_bool, err_bool = topology.discover_target_pane({ pane_override = true, agents = test_agents })
    assert_eq(pane_bool, "p_discovered", "boolean pane_override falls back to auto-discovery")
    assert_nil(err_bool, "err is nil")

    -- table pane_override falls through to auto-discovery
    local pane_tbl, err_tbl = topology.discover_target_pane({ pane_override = { id = "p1" }, agents = test_agents })
    assert_eq(pane_tbl, "p_discovered", "table pane_override falls back to auto-discovery")
    assert_nil(err_tbl, "err is nil")

    -- number pane_override converts to string
    local pane_num, err_num = topology.discover_target_pane({ pane_override = 777, agents = test_agents })
    assert_eq(pane_num, "777", "number pane_override converted to string '777'")
    assert_nil(err_num, "err is nil")

    restore_env()
  end)

  run_test("topology_stress: full 6-tier discovery resolution order", function()
    local agents = {
      { agent = "agy", pane_id = "p_caller", workspace_id = "w1", tab_id = "t1", cwd = "/proj" },
      { agent = "agy", pane_id = "p_tier1", workspace_id = "w1", tab_id = "t1", cwd = "/proj" },
      { agent = "agy", pane_id = "p_tier2", workspace_id = "w1", tab_id = "t2", cwd = "/proj" },
      { agent = "agy", pane_id = "p_tier5", workspace_id = "w2", tab_id = "t3", cwd = "/match_cwd" },
      { agent = "agy", pane_id = "p_tier6", workspace_id = "w3", tab_id = "t4", cwd = "/other" },
    }

    -- Tier 1: Same workspace + same tab, exclude caller
    local p1 = topology.discover_target_pane({
      agents = agents, workspace_id = "w1", tab_id = "t1", caller_pane_id = "p_caller", cwd = "/proj"
    })
    assert_eq(p1, "p_tier1", "Tier 1 matches same workspace + same tab excluding caller")

    -- Tier 2: Same workspace, different tab, exclude caller
    local tier2_agents = {
      { agent = "agy", pane_id = "p_caller", workspace_id = "w1", tab_id = "t1" },
      { agent = "agy", pane_id = "p_tier2", workspace_id = "w1", tab_id = "t2" },
    }
    local p2 = topology.discover_target_pane({
      agents = tier2_agents, workspace_id = "w1", tab_id = "t1", caller_pane_id = "p_caller"
    })
    assert_eq(p2, "p_tier2", "Tier 2 matches same workspace, different tab")

    -- Tier 3: Same workspace + same tab, caller pane if alone in tab
    local single_tab_agents = {
      { agent = "agy", pane_id = "p_caller", workspace_id = "w1", tab_id = "t1" },
    }
    local p3 = topology.discover_target_pane({
      agents = single_tab_agents, workspace_id = "w1", tab_id = "t1", caller_pane_id = "p_caller"
    })
    assert_eq(p3, "p_caller", "Tier 3 falls back to caller pane if alone in tab")

    -- Tier 5: CWD match across workspaces
    local p5 = topology.discover_target_pane({
      agents = agents, workspace_id = "w_unknown", tab_id = "t_unknown", caller_pane_id = "p_caller", cwd = "/match_cwd"
    })
    assert_eq(p5, "p_tier5", "Tier 5 matches CWD across workspaces")

    -- Tier 6: Global fallback
    local p6 = topology.discover_target_pane({
      agents = agents, workspace_id = "w_unknown", tab_id = "t_unknown", caller_pane_id = "p_none", cwd = "/nomatch"
    })
    assert_eq(p6, "p_caller", "Tier 6 selects first candidate globally")
  end)

  -- ==========================================================
  -- 2. SELECTION MODULE STRESS TESTS
  -- ==========================================================

  run_test("selection_stress: bufnr = 0 defaults to current active buffer", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line A", "line B" })
    vim.api.nvim_win_set_buf(0, buf)

    local sel = selection.get_visual_selection(0)
    assert_true(type(sel) == "table", "returns selection table")
    assert_true(type(sel.snippet) == "string", "returns snippet string")
  end)

  run_test("selection_stress: multi-byte UTF-8 & special characters in visual selection", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local utf8_lines = {
      "function test()",
      "  local msg = \"🚀 Hello World! 🌍 🔥\"",
      "  local cjk = \"こんにちは世界 / 繁體中文\"",
      "end",
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, utf8_lines)
    vim.api.nvim_buf_set_name(buf, "/tmp/utf8_test.lua")
    vim.bo[buf].filetype = "lua"

    -- Set marks for full lines 2-3
    vim.api.nvim_win_set_buf(0, buf)
    vim.fn.setpos("'<", { buf, 2, 1, 0 })
    vim.fn.setpos("'>", { buf, 3, 100, 0 })

    local sel = selection.get_visual_selection(buf)
    assert_eq(sel.start_line, 2, "utf8 selection start line")
    assert_eq(sel.end_line, 3, "utf8 selection end line")
    assert_true(sel.snippet:find("🚀 Hello World!", 1, true) ~= nil, "contains emoji")
    assert_true(sel.snippet:find("こんにちは世界", 1, true) ~= nil, "contains CJK text")
    assert_eq(sel.filetype, "lua", "filetype is lua")
  end)

  run_test("selection_stress: blockwise selection on unequal line lengths", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = {
      "short",
      "this is a much longer line",
      "medium line",
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_buf(0, buf)

    vim.fn.setpos("'<", { buf, 1, 2, 0 })
    vim.fn.setpos("'>", { buf, 3, 10, 0 })

    -- Fake visualmode return blockwise
    local orig_vmode = vim.fn.visualmode
    vim.fn.visualmode = function() return "\22" end

    local sel = selection.get_visual_selection(buf)
    assert_eq(sel.mode, "\22", "blockwise mode captured")
    assert_true(type(sel.snippet) == "string", "snippet formatted cleanly without string.sub out of bounds error")

    vim.fn.visualmode = orig_vmode
  end)

  run_test("selection_stress: empty visual selection prompt cancellation", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_win_set_buf(0, buf)

    local notified_warn = false
    local notify_mock = function(msg, opts)
      if msg:find("No visual selection") then
        notified_warn = true
      end
    end

    local orig_notify_warn = notify.warn
    notify.warn = notify_mock

    local res = selection.send_selection_prompt({ notify = { enabled = false } })
    assert_false(res, "send_selection_prompt returns false when selection is empty")

    notify.warn = orig_notify_warn
  end)

  -- ==========================================================
  -- 3. DIFF MODULE STRESS TESTS
  -- ==========================================================

  run_test("diff_stress: split diff edge cases", function()
    -- Invalid window handle
    local res_invalid = diff.get_diff_hunk_at_cursor(99999)
    assert_nil(res_invalid, "invalid window ID returns nil")

    -- Window not in diff mode
    local win = vim.api.nvim_get_current_win()
    vim.wo[win].diff = false
    local res_nodiff = diff.get_diff_hunk_at_cursor(win)
    assert_nil(res_nodiff, "window not in diff mode returns nil (outside diff ft / git fallback)")
  end)

  run_test("diff_stress: filetype diff patch block parsing", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local diff_content = {
      "diff --git a/lua/sagani/init.lua b/lua/sagani/init.lua",
      "--- a/lua/sagani/init.lua",
      "+++ b/lua/sagani/init.lua",
      "@@ -10,3 +10,4 @@",
      " local M = {}",
      "+-- Added comment line",
      " return M",
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_content)
    vim.bo[buf].filetype = "diff"

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_cursor(win, { 6, 0 }) -- line 6 "+-- Added comment line"

    local hunk = diff.get_diff_hunk_at_cursor(win)
    assert_true(hunk ~= nil, "found diff hunk in diff filetype buffer")
    assert_eq(hunk.file_path, "lua/sagani/init.lua", "extracted patch file path correctly")
    assert_eq(hunk.start_line, 10, "start_line is 10")
    assert_true(hunk.diff_text:find("+-- Added comment line", 1, true) ~= nil, "hunk contains added line")
  end)

  run_test("diff_stress: send_diff_comment prompt cancellation", function()
    local orig_get_hunk = diff.get_diff_hunk_at_cursor
    diff.get_diff_hunk_at_cursor = function()
      return {
        file_path = "test.lua",
        start_line = 1,
        end_line = 5,
        diff_text = "@@ -1,5 +1,5 @@\n-old\n+new",
      }
    end

    -- User cancels input (<Esc>) -> vim.ui.input passes nil
    vim.ui.input = function(opts, cb)
      cb(nil)
    end

    local dispatched = false
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function() dispatched = true end

    local res = diff.send_diff_comment({ notify = { enabled = false } })
    assert_true(res, "send_diff_comment returns true when prompt started")
    assert_false(dispatched, "dispatch_prompt not called on input cancellation")

    diff.get_diff_hunk_at_cursor = orig_get_hunk
    init.dispatch_prompt = orig_dispatch
    restore_env()
  end)

  -- ==========================================================
  -- 4. FORMAT MODULE STRESS TESTS
  -- ==========================================================

  run_test("format_stress: context prompt builder boundary conditions", function()
    -- Nil / empty arguments
    local p1 = format.build_context_prompt(nil, nil)
    assert_true(p1:find("Context snippet for review:", 1, true) ~= nil, "default instruction when user_instruction is nil")
    assert_true(p1:find("`[No Name]` (L1)", 1, true) ~= nil, "default file_path and line range L1")
    assert_true(p1:find("```text", 1, true) ~= nil, "default filetype text")

    -- Multiline user instruction and backticks in snippet
    local multi_inst = "Line 1 instruction\nLine 2 instruction"
    local snippet_bt = "local code = \"```lua\""
    local p2 = format.build_context_prompt(multi_inst, {
      file_path = "src/main.rs",
      filetype = "rust",
      start_line = 10,
      end_line = 25,
      snippet = snippet_bt,
    })

    assert_true(p2:find("Line 1 instruction\nLine 2 instruction", 1, true) ~= nil, "multiline instruction preserved")
    assert_true(p2:find("`src/main.rs` (L10-L25)", 1, true) ~= nil, "file path and range L10-L25")
    assert_true(p2:find("```rust", 1, true) ~= nil, "filetype rust block")
    assert_true(p2:find(snippet_bt, 1, true) ~= nil, "snippet with backticks preserved")
  end)

  run_test("format_stress: diff prompt builder boundary conditions", function()
    -- Nil / empty arguments
    local d1 = format.build_diff_prompt(nil, nil)
    assert_true(d1:find("Diff review comment:", 1, true) ~= nil, "default comment when user_comment is nil")
    assert_true(d1:find("Diff Context from `[No Name]` (L1)", 1, true) ~= nil, "default file_path and range L1")
    assert_true(d1:find("```diff", 1, true) ~= nil, "diff block")

    -- Custom comment and single line range
    local d2 = format.build_diff_prompt("Fix typo in variable name", {
      file_path = "lib/utils.py",
      start_line = 42,
      end_line = 42,
      diff_text = "- x = 1\n+ x = 2",
    })

    assert_true(d2:find("Fix typo in variable name", 1, true) ~= nil, "user comment preserved")
    assert_true(d2:find("`lib/utils.py` (L42)", 1, true) ~= nil, "single line range L42")
    assert_true(d2:find("- x = 1\n+ x = 2", 1, true) ~= nil, "diff snippet content preserved")
  end)

  -- ==========================================================
  -- 5. NOTIFY MODULE STRESS TESTS
  -- ==========================================================

  run_test("notify_stress: notification suppression and log level mapping", function()
    local last_msg, last_level, last_title

    vim.notify = function(msg, level, opts)
      last_msg = msg
      last_level = level
      last_title = opts and opts.title
    end

    -- Test info
    notify.info("Test Info", { title = "MyTitle" })
    assert_eq(last_msg, "Test Info", "info message string")
    assert_eq(last_level, vim.log.levels.INFO, "info log level")
    assert_eq(last_title, "MyTitle", "custom title")

    -- Test warn / warning
    notify.notify("Test Warn", "warning")
    assert_eq(last_msg, "Test Warn", "warning message string")
    assert_eq(last_level, vim.log.levels.WARN, "warning log level")

    -- Test error
    notify.error("Test Error")
    assert_eq(last_msg, "Test Error", "error message string")
    assert_eq(last_level, vim.log.levels.ERROR, "error log level")

    -- Test notification suppression (notify = false)
    last_msg = nil
    notify.info("Should be suppressed", { notify = false })
    assert_nil(last_msg, "notify = false suppresses notification")

    -- Test notification suppression (notify = { enabled = false })
    notify.info("Should be suppressed nested", { notify = { enabled = false } })
    assert_nil(last_msg, "notify.enabled = false suppresses notification")

    -- Test non-string message (table, number)
    notify.info({ key = "val" })
    assert_true(type(last_msg) == "string" and last_msg:find("key", 1, true) ~= nil, "table message inspected to string")

    restore_env()
  end)

  -- ==========================================================
  -- 6. INIT MODULE DISPATCH STRESS TESTS
  -- ==========================================================

  run_test("init_stress: dispatch_prompt invalid prompt inputs", function()
    local ok1, err1 = init.dispatch_prompt(nil)
    assert_false(ok1, "dispatch_prompt(nil) returns false")
    assert_true(err1:find("Invalid prompt text", 1, true) ~= nil, "returns invalid prompt text error")

    local ok2, err2 = init.dispatch_prompt("")
    assert_false(ok2, "dispatch_prompt('') returns false")
    assert_true(err2:find("Invalid prompt text", 1, true) ~= nil, "returns invalid prompt text error")

    local ok3, err3 = init.dispatch_prompt(12345)
    assert_false(ok3, "dispatch_prompt(12345) returns false")
    assert_true(err3:find("Invalid prompt text", 1, true) ~= nil, "returns invalid prompt text error")
  end)

  run_test("init_stress: dispatch_prompt cli failure and stderr capture", function()
    vim.env.HERDR_ENV = "1"
    vim.env.HERDR_PANE_ID = "p1"

    -- Mock herdr executable present
    vim.fn.executable = function(cmd)
      if cmd == "herdr" then return 1 end
      return orig_executable(cmd)
    end

    -- Mock vim.system returning non-zero exit code with stderr
    vim.system = function(cmd, opts)
      return {
        wait = function()
          return {
            code = 1,
            stdout = "",
            stderr = "herdr: error: pane 'p1' not active or unresponsive",
          }
        end
      }
    end

    local ok, err = init.dispatch_prompt("Test prompt", "p1", { notify = { enabled = false } })
    assert_false(ok, "dispatch_prompt returns false on process failure")
    assert_true(err:find("exit code 1", 1, true) ~= nil, "error message includes exit code")
    assert_true(err:find("pane 'p1' not active", 1, true) ~= nil, "error message captures stderr output")

    restore_env()
  end)

  run_test("init_stress: dispatch_prompt success execution path", function()
    vim.env.HERDR_ENV = "1"
    vim.env.HERDR_PANE_ID = "p1"

    vim.fn.executable = function(cmd)
      if cmd == "herdr" then return 1 end
      return orig_executable(cmd)
    end

    local executed_cmd = nil
    vim.system = function(cmd, opts)
      executed_cmd = cmd
      return {
        wait = function()
          return {
            code = 0,
            stdout = "Prompt received by agent pane 'p1'\n",
            stderr = "",
          }
        end
      }
    end

    local ok, err = init.dispatch_prompt("Explain function", "p1", { notify = { enabled = false } })
    assert_true(ok, "dispatch_prompt returns true on process success")
    assert_nil(err, "err is nil on success")
    assert_eq(executed_cmd[1], "herdr", "cmd binary is herdr")
    assert_eq(executed_cmd[2], "agent", "cmd arg 1 is agent")
    assert_eq(executed_cmd[3], "prompt", "cmd arg 2 is prompt")
    assert_eq(executed_cmd[4], "p1", "target pane is p1")
    assert_eq(executed_cmd[5], "Explain function", "prompt string passed")

    restore_env()
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
  print(string.format("TEST RESULTS (test_challenger_stress): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
