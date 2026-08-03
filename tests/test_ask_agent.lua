-- Headless Neovim Unit Test Suite for sagani.nvim ask_agent module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local init = require("sagani")
local topology = require("sagani.backend.herdr.topology")

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

  run_test("topology.spawn_agent_popup: creates agent pane with mock runner (returns agent_name)", function()
    local mock_runner = function(cmd)
      -- Now expects: herdr pane split --direction right --cwd <cwd>
      if cmd[1] == "herdr" and cmd[2] == "pane" and cmd[3] == "split" and cmd[4] == "--direction" and cmd[5] == "right" then
        return '{"result":{"pane":{"pane_id":"p_popup_1"}}}', 0
      end
      return "", 0
    end

    local agent_name, err, meta = topology.spawn_agent_popup({ runner = mock_runner, target_agent = "opencode" })
    assert_true(type(agent_name) == "string" and agent_name ~= "", "agent_name returned as string")
    assert_true(agent_name:find("opencode") ~= nil, "agent_name contains harness name")
    assert_eq(err, nil, "err is nil")
    assert_eq(meta.pane_id, "p_popup_1", "pane_id in metadata")
    assert_true(meta.is_popup, "is_popup flag set in metadata")
    assert_true(meta.agent_name ~= nil, "agent_name in metadata")
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

    -- Pass ask_agent in call-site opts so ask_opts resolves to "hermes"
    init.ask_agent_prompt("Explain garbage collection", {
      ask_agent = { target_agent = "hermes", popup = true },
      notify = { enabled = false },
    })
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

    -- session cache path: _session_ask_agent is set, bypasses vim.ui.select
    init.ask_agent_prompt("What is ARC in Rust?", { notify = { enabled = false } })
    assert_eq(init._session_ask_agent, "codex", "session cache remembered")
  end)

  run_test("ask_agent_prompt: no cache/config → vim.ui.select fires with agent list", function()
    init.setup({ notify = { enabled = false } })
    _G.RUNNING_TEST_SUITE = true
    init._session_ask_agent = nil

    local selected_items = {}
    local orig_select = vim.ui.select
    vim.ui.select = function(items, _, cb)
      selected_items = items
      cb("opencode")  -- simulate user picking opencode
    end

    local dispatched_agent = nil
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function(text, target, opts)
      dispatched_agent = init._session_ask_agent
      return true, nil
    end

    init.ask_agent_prompt("test question", { notify = { enabled = false } })

    vim.ui.select = orig_select
    init.dispatch_prompt = orig_dispatch

    assert_true(vim.tbl_contains(selected_items, "agy"), "select list contains agy")
    assert_true(vim.tbl_contains(selected_items, "codex"), "select list contains codex")
    assert_true(vim.tbl_contains(selected_items, "opencode"), "select list contains opencode")
    assert_true(vim.tbl_contains(selected_items, "hermes"), "select list contains hermes")
    assert_true(vim.tbl_contains(selected_items, "Other..."), "select list contains Other...")
    assert_eq(init._session_ask_agent, "opencode", "session cache set to selected agent")
  end)

  run_test("native.spawn_popup: reuses persistent buffer and preserves state on reopen", function()
    local native_backend = require("sagani.backend.native")
    native_backend.reset_popup("agy")

    local win1_str, _, _ = native_backend.spawn_popup({ target_agent = "agy" })
    local win1 = tonumber(win1_str)
    local buf1 = vim.api.nvim_win_get_buf(win1)

    -- Write custom line to buffer to simulate running session state
    vim.api.nvim_buf_set_lines(buf1, -1, -1, false, { "Persisted session prompt history line" })

    -- Close window (simulates pressing q or Esc)
    pcall(vim.api.nvim_win_close, win1, false)

    -- Reopen popup
    local win2_str, _, _ = native_backend.spawn_popup({ target_agent = "agy" })
    local win2 = tonumber(win2_str)
    local buf2 = vim.api.nvim_win_get_buf(win2)

    assert_eq(buf2, buf1, "Reopened popup reuses exact same buffer handle")
    local lines = vim.api.nvim_buf_get_lines(buf2, 0, -1, false)
    local text = table.concat(lines, "\n")
    assert_true(text:find("Persisted session prompt history line") ~= nil, "Session conversation state preserved")

    -- Simulate terminal buftype
    pcall(function() vim.bo[buf1].buftype = "terminal" end)
    pcall(vim.api.nvim_win_close, win2, false)

    -- Reopen popup 3rd time on terminal buftype
    local win3_str, _, _ = native_backend.spawn_popup({ target_agent = "agy" })
    local win3 = tonumber(win3_str)
    local buf3 = vim.api.nvim_win_get_buf(win3)
    assert_eq(buf3, buf1, "Reopened popup reuses terminal buffer without E474 error")

    -- Clean up
    pcall(vim.api.nvim_win_close, win3, false)
    native_backend.reset_popup("agy")
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
