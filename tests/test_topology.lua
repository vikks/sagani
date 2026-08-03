-- Headless Neovim Test Suite for sagani.nvim Topology Module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local topology = require("sagani.backend.herdr.topology")
local notify = require("sagani.notify")
local init = require("sagani.init")

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

  local function make_agent(pane_id, tab_id, ws_id, cwd, agent_type)
    return {
      agent = agent_type or "agy",
      pane_id = pane_id,
      tab_id = tab_id,
      workspace_id = ws_id,
      cwd = cwd or "/workspace",
      foreground_cwd = cwd or "/workspace",
      agent_status = "idle",
    }
  end

  local orig_env = {
    HERDR_ENV = vim.env.HERDR_ENV,
    HERDR_PANE_ID = vim.env.HERDR_PANE_ID,
    HERDR_TAB_ID = vim.env.HERDR_TAB_ID,
    HERDR_WORKSPACE_ID = vim.env.HERDR_WORKSPACE_ID,
  }

  local function restore_env()
    vim.env.HERDR_ENV = orig_env.HERDR_ENV
    vim.env.HERDR_PANE_ID = orig_env.HERDR_PANE_ID
    vim.env.HERDR_TAB_ID = orig_env.HERDR_TAB_ID
    vim.env.HERDR_WORKSPACE_ID = orig_env.HERDR_WORKSPACE_ID
  end

  -- ==========================================================
  -- 1. ENVIRONMENT DETECTION TESTS
  -- ==========================================================

  run_test("detect_env: Active Herdr environment", function()
    vim.env.HERDR_ENV = "1"
    vim.env.HERDR_PANE_ID = "w1:p1"
    vim.env.HERDR_TAB_ID = "w1:t1"
    vim.env.HERDR_WORKSPACE_ID = "w1"

    local env = topology.detect_env()
    assert_true(env.in_herdr, "detect_env in_herdr flag")
    assert_eq(env.pane_id, "w1:p1", "detect_env pane_id")
    assert_eq(env.tab_id, "w1:t1", "detect_env tab_id")
    assert_eq(env.workspace_id, "w1", "detect_env workspace_id")
    restore_env()
  end)

  run_test("detect_env: Inactive Herdr environment", function()
    vim.env.HERDR_ENV = nil
    vim.env.HERDR_PANE_ID = nil
    vim.env.HERDR_TAB_ID = nil
    vim.env.HERDR_WORKSPACE_ID = nil

    local env = topology.detect_env()
    assert_eq(env.in_herdr, false, "detect_env in_herdr should be false")
    assert_nil(env.pane_id, "detect_env pane_id should be nil")
    restore_env()
  end)

  run_test("detect_env: Empty string env values treated as nil", function()
    vim.env.HERDR_ENV = "1"
    vim.env.HERDR_PANE_ID = ""
    vim.env.HERDR_TAB_ID = ""
    vim.env.HERDR_WORKSPACE_ID = ""

    local mock_runner = function() return nil, 1 end
    local env = topology.detect_env(mock_runner)
    assert_true(env.in_herdr, "detect_env in_herdr is true")
    assert_nil(env.pane_id, "empty pane_id should be nil")
    assert_nil(env.tab_id, "empty tab_id should be nil")
    assert_nil(env.workspace_id, "empty workspace_id should be nil")
    restore_env()
  end)

  -- ==========================================================
  -- 2. LIST AGENTS TESTS
  -- ==========================================================

  run_test("list_agents: Successful JSON parsing via mock runner", function()
    local mock_json = vim.json.encode({
      result = {
        agents = {
          make_agent("w1:p2", "w1:t1", "w1", "/proj", "agy"),
        },
      },
    })
    local mock_runner = function(cmd)
      assert_eq(cmd[1], "herdr", "runner cmd[1]")
      assert_eq(cmd[2], "agent", "runner cmd[2]")
      assert_eq(cmd[3], "list", "runner cmd[3]")
      return mock_json, 0
    end

    local agents, err = topology.list_agents(mock_runner)
    assert_nil(err, "list_agents err should be nil")
    assert_true(agents ~= nil and #agents == 1, "list_agents returned 1 agent")
    assert_eq(agents[1].pane_id, "w1:p2", "list_agents agent pane_id")
  end)

  run_test("list_agents: JSON parse failure handling", function()
    local mock_runner = function(_)
      return "INVALID JSON", 0
    end

    local agents, err = topology.list_agents(mock_runner)
    assert_nil(agents, "list_agents agents should be nil on JSON error")
    assert_true(err ~= nil and err:find("parse JSON") ~= nil, "list_agents error message")
  end)

  run_test("list_agents: Command failure exit code handling", function()
    local mock_runner = function(_)
      return nil, 1
    end

    local agents, err = topology.list_agents(mock_runner)
    assert_nil(agents, "agents is nil on runner exit failure")
    assert_true(err ~= nil and err:find("failed with code 1") ~= nil, "error message contains exit code")
  end)

  -- ==========================================================
  -- 3. AUTO-DISCOVERY & SCORING HIERARCHY TESTS
  -- ==========================================================

  run_test("discover_target_pane: Explicit pane_override bypasses discovery", function()
    local pane, err = topology.discover_target_pane({ pane_override = "manual:p99" })
    assert_eq(pane, "manual:p99", "respects pane_override")
    assert_nil(err, "err is nil for override")
  end)

  run_test("discover_target_pane: Non-Herdr environment returns error", function()
    vim.env.HERDR_ENV = nil
    local pane, err = topology.discover_target_pane({ ignore_herdr_env = false })
    assert_nil(pane, "pane is nil outside Herdr")
    assert_true(err ~= nil and err:find("HERDR_ENV missing") ~= nil, "returns HERDR_ENV error")
    restore_env()
  end)

  run_test("discover_target_pane: Tier 1 match (Same workspace + same tab, exclude caller)", function()
    local agents = {
      make_agent("w1:p1", "w1:t1", "w1", "/proj", "agy"), -- caller pane
      make_agent("w1:p2", "w1:t1", "w1", "/proj", "agy"), -- target pane in same tab
      make_agent("w2:p1", "w2:t1", "w2", "/other", "agy"),
    }

    local pane, err = topology.discover_target_pane({
      agents = agents,
      workspace_id = "w1",
      tab_id = "w1:t1",
      caller_pane_id = "w1:p1",
      ignore_herdr_env = true,
    })

    assert_eq(pane, "w1:p2", "Tier 1 selects right pane in same tab excluding caller")
    assert_nil(err, "err is nil")
  end)

  run_test("discover_target_pane: Tier 2 match (Same workspace + same tab, fallback to caller pane if alone)", function()
    local agents = {
      make_agent("w1:p1", "w1:t1", "w1", "/proj", "agy"), -- caller pane only
    }

    local pane, err = topology.discover_target_pane({
      agents = agents,
      workspace_id = "w1",
      tab_id = "w1:t1",
      caller_pane_id = "w1:p1",
      ignore_herdr_env = true,
    })

    assert_eq(pane, "w1:p1", "Tier 2 falls back to caller pane if it is the only agy agent in tab")
    assert_nil(err, "err is nil")
  end)

  run_test("discover_target_pane: Tier 3 match (Same workspace, different tab, exclude caller)", function()
    local agents = {
      make_agent("w1:p1", "w1:t1", "w1", "/proj", "agy"), -- caller in tab 1
      make_agent("w1:p3", "w1:t2", "w1", "/proj", "agy"), -- agy agent in tab 2
    }

    local pane, err = topology.discover_target_pane({
      agents = agents,
      workspace_id = "w1",
      tab_id = "w1:t1",
      caller_pane_id = "w1:p1",
      ignore_herdr_env = true,
    })

    assert_eq(pane, "w1:p3", "Tier 3 selects agy agent in different tab of same workspace")
    assert_nil(err, "err is nil")
  end)

  run_test("discover_target_pane: Tier 4 match (Same workspace, any pane)", function()
    local agents = {
      make_agent("w1:p1", "w1:t2", "w1", "/proj", "agy"), -- only agy agent in workspace in tab 2
    }

    local pane, err = topology.discover_target_pane({
      agents = agents,
      workspace_id = "w1",
      tab_id = "w1:t1",
      caller_pane_id = "w1:p1",
      ignore_herdr_env = true,
    })

    assert_eq(pane, "w1:p1", "Tier 4 matches any pane in same workspace")
    assert_nil(err, "err is nil")
  end)

  run_test("discover_target_pane: Tier 5 match (CWD match across workspaces)", function()
    local agents = {
      make_agent("w9:p1", "w9:t1", "w9", "/my/special/dir", "agy"),
    }

    local pane, err = topology.discover_target_pane({
      agents = agents,
      workspace_id = "w1",
      tab_id = "w1:t1",
      caller_pane_id = "w1:p1",
      cwd = "/my/special/dir",
      ignore_herdr_env = true,
    })

    assert_eq(pane, "w9:p1", "Tier 5 matches CWD across workspaces")
    assert_nil(err, "err is nil")
  end)

  run_test("discover_target_pane: Tier 6 match (Global fallback)", function()
    local agents = {
      make_agent("w99:p1", "w99:t1", "w99", "/different/dir", "agy"),
    }

    local pane, err = topology.discover_target_pane({
      agents = agents,
      workspace_id = "w1",
      tab_id = "w1:t1",
      caller_pane_id = "w1:p1",
      cwd = "/my/dir",
      ignore_herdr_env = true,
    })

    assert_eq(pane, "w99:p1", "Tier 6 falls back to first candidate globally")
    assert_nil(err, "err is nil")
  end)

  run_test("discover_target_pane: No matching target agent type found", function()
    local agents = {
      make_agent("w1:p2", "w1:t1", "w1", "/proj", "other_agent"),
    }

    local pane, err = topology.discover_target_pane({
      agents = agents,
      target_agent = "agy",
      ignore_herdr_env = true,
    })

    assert_nil(pane, "pane is nil when no agy agent exists")
    assert_true(err ~= nil and err:find("No active 'agy' agent found") ~= nil, "error message specifies agent name")
  end)

  run_test("discover_target_pane: Custom target_agent type filtering", function()
    local agents = {
      make_agent("w1:p1", "w1:t1", "w1", "/proj", "agy"),
      make_agent("w1:p2", "w1:t1", "w1", "/proj", "custom_bot"),
    }

    local pane, err = topology.discover_target_pane({
      agents = agents,
      target_agent = "custom_bot",
      ignore_herdr_env = true,
    })

    assert_eq(pane, "w1:p2", "finds custom_bot agent pane")
    assert_nil(err, "err is nil")
  end)

  -- ==========================================================
  -- 4. INIT MODULE & COMMAND TESTS
  -- ==========================================================

  run_test("init: setup() merges user options and registers commands", function()
    init.setup({
      target_agent = "custom_agy",
      notify = { enabled = true, title = "Custom Title" },
    })

    assert_eq(init.options.target_agent, "custom_agy", "setup target_agent")
    assert_eq(init.options.notify.title, "Custom Title", "setup notify title")
    assert_true(vim.fn.exists(":SaganiStatus") == 2, ":SaganiStatus user command registered")
    assert_true(vim.fn.exists(":SaganiSelectTarget") == 2, ":SaganiSelectTarget user command registered")
    assert_true(vim.fn.exists(":SaganiPrompt") == 2, ":SaganiPrompt user command registered")
    assert_true(vim.fn.exists(":SaganiSend") == 2, ":SaganiSend user command registered")
    assert_true(vim.fn.exists(":SaganiDiff") == 2, ":SaganiDiff user command registered")
  end)

  run_test("notify: info/warn/error helpers execute without throwing errors", function()
    local ok = pcall(function()
      notify.info("Test info message", { notify = { enabled = false } })
      notify.warn("Test warn message", { notify = { enabled = false } })
      notify.error("Test error message", { notify = { enabled = false } })
    end)
    assert_true(ok, "notify calls complete without error")
  end)

  run_test("dispatch_prompt: captures stderr output on CLI execution failure", function()
    local orig_sys = vim.system
    vim.system = function()
      return {
        wait = function()
          return { code = 1, stdout = "", stderr = "herdr: error: pane w1:p99 does not exist" }
        end,
      }
    end

    local ok, err = init.dispatch_prompt("hello", "w1:p99")
    vim.system = orig_sys

    assert_eq(ok, false, "dispatch_prompt returns false on process failure")
    assert_true(err ~= nil and err:find("herdr: error: pane w1:p99 does not exist") ~= nil, "error message captures stderr output")
  end)

  run_test("dispatch_prompt: prompt_text validation for nil, empty, or non-string", function()
    local ok1, err1 = init.dispatch_prompt(nil, "w1:p1")
    assert_eq(ok1, false, "dispatch_prompt fails on nil prompt_text")
    assert_true(err1 ~= nil and err1:find("Invalid prompt text") ~= nil, "returns invalid prompt text error")

    local ok2, err2 = init.dispatch_prompt("", "w1:p1")
    assert_eq(ok2, false, "dispatch_prompt fails on empty prompt_text")
    assert_true(err2 ~= nil and err2:find("Invalid prompt text") ~= nil, "returns invalid prompt text error")

    local ok3, err3 = init.dispatch_prompt(12345, "w1:p1")
    assert_eq(ok3, false, "dispatch_prompt fails on number prompt_text")
    assert_true(err3 ~= nil and err3:find("Invalid prompt text") ~= nil, "returns invalid prompt text error")
  end)

  run_test("dispatch_prompt: empty target_pane normalizes to nil and triggers auto-discovery", function()
    vim.env.HERDR_ENV = nil
    local ok, err = init.dispatch_prompt("valid prompt text", "")
    assert_eq(ok, false, "dispatch_prompt fails outside Herdr when target_pane is empty string")
    assert_true(err ~= nil and (err:find("HERDR_ENV missing") ~= nil or err:find("No active native agent target window found") ~= nil), "triggers discover_target_pane auto-discovery")
    restore_env()
  end)

  run_test("notify: boolean and table opts.notify handling and suppression", function()
    local called = false
    local orig_notify = vim.notify
    vim.notify = function()
      called = true
    end

    called = false
    notify.info("Test msg", { notify = true })
    assert_true(called, "notify = true enables notification")

    called = false
    notify.info("Test msg", { notify = false })
    assert_eq(called, false, "notify = false suppresses notification")

    called = false
    notify.info("Test msg", { notify = { enabled = false } })
    assert_eq(called, false, "notify = { enabled = false } suppresses notification")

    called = false
    local ok_prim = pcall(function() notify.info("Test msg", 123) end)
    assert_true(ok_prim, "primitive number opts handles notification safely (no crash)")
    -- In test suite mode, primitive opts without notify=true are silently suppressed
    assert_eq(called, false, "primitive number opts suppressed in test suite mode")

    vim.notify = orig_notify
  end)

  run_test("init.setup: non-table user_opts handled without crash", function()
    local ok1 = pcall(function() init.setup("invalid_string_opts") end)
    assert_true(ok1, "setup handles string user_opts")

    local ok2 = pcall(function() init.setup(12345) end)
    assert_true(ok2, "setup handles number user_opts")

    local ok3 = pcall(function() init.setup(true) end)
    assert_true(ok3, "setup handles boolean user_opts")
  end)

  run_test("topology: malformed JSON and candidate edge case handling", function()
    local runner1 = function() return '{"result": 123}', 0 end
    local agents1, err1 = topology.list_agents(runner1)
    assert_nil(agents1, "agents is nil when data.result is number")
    assert_true(err1 ~= nil, "returns parse JSON error")

    local agents2 = { "string_item", 42, true, { agent = "agy", pane_id = "p99" } }
    local pane2, err2 = topology.discover_target_pane({ agents = agents2, ignore_herdr_env = true })
    assert_eq(pane2, "p99", "skips non-table elements and finds p99")
    assert_nil(err2, "err is nil")

    local agents3 = { { agent = "agy", pane_id = "", tab_id = "t1" } }
    local pane3, err3 = topology.discover_target_pane({ agents = agents3, ignore_herdr_env = true })
    assert_nil(pane3, "pane is nil when candidate has empty pane_id")
    assert_true(err3 ~= nil, "returns no active agy agent error")

    local pane4, err4 = topology.discover_target_pane({ pane_override = 100 })
    assert_eq(pane4, "100", "converts number pane_override to string")
    assert_nil(err4, "err is nil for number override")
  end)

  -- ==========================================================
  -- 5. SPAWN AGENT POPUP TESTS
  -- ==========================================================

  run_test("spawn_agent_popup: returns agent_name and fallback pane in test suite mode", function()
    local agent_name, err, meta = topology.spawn_agent_popup()
    assert_true(type(agent_name) == "string" and agent_name ~= "", "returns agent_name string")
    assert_true(agent_name:find("agy") ~= nil, "agent_name contains default harness 'agy'")
    assert_nil(err, "err is nil")
    assert_true(meta ~= nil and meta.is_popup == true, "meta.is_popup is true")
    assert_eq(meta.pane_id, "p_popup", "meta.pane_id is 'p_popup'")
    -- spawned=false in test suite: fake pane, agent.start was not actually called
    assert_true(meta.spawned == false, "meta.spawned is false for test-suite fake pane")
  end)

  run_test("spawn_agent_popup: runner integration for pane split + agent start", function()
    local called_cmds = {}
    local mock_runner = function(cmd)
      table.insert(called_cmds, cmd)
      -- pane split returns pane_id
      if cmd[1] == "herdr" and cmd[2] == "pane" and cmd[3] == "split" then
        return vim.json.encode({ result = { pane = { pane_id = "w1:p99" } } }), 0
      end
      return "", 0
    end

    local agent_name, err, meta = topology.spawn_agent_popup({ runner = mock_runner, cwd = "/proj" })
    assert_true(type(agent_name) == "string" and agent_name ~= "", "returns agent_name string")
    assert_nil(err, "err is nil")
    assert_true(meta ~= nil and meta.is_popup == true, "meta.is_popup is true")
    assert_eq(meta.pane_id, "w1:p99", "meta.pane_id from runner")
    -- runner was called with --direction right (not --popup)
    local split_cmd = called_cmds[1]
    assert_true(split_cmd ~= nil and vim.tbl_contains(split_cmd, "--direction") and vim.tbl_contains(split_cmd, "right"),
      "runner command uses --direction right")
  end)

  run_test("spawn_agent_popup: CLI executable missing error handling", function()
    local orig_executable = vim.fn.executable
    vim.fn.executable = function(cmd)
      if cmd == "herdr" then return 0 end
      return orig_executable(cmd)
    end
    _G.RUNNING_TEST_SUITE = false

    local agent_name, err, meta = topology.spawn_agent_popup()
    vim.fn.executable = orig_executable
    _G.RUNNING_TEST_SUITE = true

    assert_nil(agent_name, "agent_name is nil when herdr binary is missing")
    assert_true(err ~= nil and err:find("not found in PATH") ~= nil, "returns binary missing error string")
    assert_nil(meta, "metadata is nil on failure")
  end)

  restore_env()

  return {
    passed = passed_count,
    failed = failed_count,
    failures = test_failures,
  }
end

if not _G.RUNNING_TEST_SUITE then
  local results = M.run()
  print("\n==========================================================")
  print(string.format("TEST RESULTS (test_topology): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
