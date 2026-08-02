-- Headless Neovim Unit Test Suite for sagani.nvim ask_agent module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local init = require("sagani")
local topology = require("sagani.topology")

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

  -- ==========================================================
  -- 1. TOPOLOGY SPAWN AGENT POPUP TESTS
  -- ==========================================================

  run_test("topology.spawn_agent_popup: creates popup pane with mock runner", function()
    local mock_runner = function(cmd)
      if cmd[1] == "herdr" and cmd[2] == "pane" and cmd[3] == "split" then
        return '{"result":{"pane":{"pane_id":"p_popup_1"}}}', 0
      end
      return "", 0
    end

    local pane_id, err, meta = topology.spawn_agent_popup({ runner = mock_runner, target_agent = "opencode" })
    assert_eq(pane_id, "p_popup_1", "popup pane_id returned")
    assert_eq(err, nil, "err is nil")
    assert_true(meta.is_popup, "is_popup flag set in metadata")
  end)

  -- ==========================================================
  -- 2. INIT ASK_AGENT_PROMPT RESOLUTION TESTS
  -- ==========================================================

  run_test("ask_agent_prompt: configured ask_agent.target_agent takes precedence", function()
    init.setup({
      ask_agent = {
        target_agent = "hermes",
        popup = true,
      },
      notify = { enabled = false },
    })

    _G.RUNNING_TEST_SUITE = true
    init._session_ask_agent = nil

    init.ask_agent_prompt("Explain garbage collection", { notify = { enabled = false } })
    assert_eq(init.options.ask_agent.target_agent, "hermes", "configured target_agent preserved")
  end)

  run_test("ask_agent_prompt: session cache remembered on subsequent calls", function()
    init.setup({
      ask_agent = {
        target_agent = nil,
        popup = true,
      },
      notify = { enabled = false },
    })

    _G.RUNNING_TEST_SUITE = true
    init._session_ask_agent = "codex"

    init.ask_agent_prompt("What is ARC in Rust?", { notify = { enabled = false } })
    assert_eq(init._session_ask_agent, "codex", "session cache remembered")
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
  print(string.format("TEST RESULTS (test_ask_agent): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
