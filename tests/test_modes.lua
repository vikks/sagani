-- Headless Neovim Unit Test Suite for sagani.nvim multi-mode architecture (review, learn, off)
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local sagani = require("sagani")
local format = require("sagani.format")

local M = {}

function M.run()
  sagani._session_mode = nil
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
  -- 1. MODE SETTING AND TOGGLING TESTS
  -- ==========================================================

  run_test("modes: set_mode sets active session mode", function()
    sagani._session_mode = nil
    sagani.set_mode("review")
    assert_eq(sagani._session_mode, "review", "mode set to review")

    sagani.set_mode("learn")
    assert_eq(sagani._session_mode, "learn", "mode set to learn")

    sagani.set_mode("off")
    assert_eq(sagani._session_mode, nil, "mode set to nil when off")
  end)

  run_test("modes: set_mode notifies user when active mode has no matching opts.tasks entry", function()
    local notify = require("sagani.notify")
    local warned_msg = nil
    local orig_warn = notify.warn
    notify.warn = function(msg, _)
      warned_msg = msg
    end

    sagani.options = { tasks = { chat = "agy" } }
    sagani.set_mode("custom_unconfigured")
    assert_eq(sagani._session_mode, "custom_unconfigured", "custom mode set")
    assert_true(warned_msg ~= nil and warned_msg:find("custom_unconfigured") ~= nil, "warned user about missing task config")

    notify.warn = orig_warn
    sagani._session_mode = nil
  end)

  run_test("modes: toggle_mode toggles specific mode on and off", function()
    sagani._session_mode = nil
    sagani.toggle_mode("learn")
    assert_eq(sagani._session_mode, "learn", "toggle_mode learn enables learn mode")

    sagani.toggle_mode("learn")
    assert_eq(sagani._session_mode, nil, "toggle_mode learn disables learn mode when already active")
  end)

  run_test("modes: format.build_context_prompt injects educational prefix when learn mode is active", function()
    sagani._session_mode = "learn"
    local prompt = format.build_context_prompt("Explain code", {
      file_path = "test.lua",
      snippet = "print('hello')",
    })
    assert_true(prompt:find("🎓") ~= nil, "prompt contains educational emoji prefix")
    assert_true(prompt:find("Learning Mode Active") ~= nil, "prompt contains Learning Mode Active string")
    sagani._session_mode = nil
  end)

  run_test("modes: resolve_task_agent routes to opts.tasks[active_mode] when mode is active", function()
    local backend = require("sagani.backend")
    local opts = {
      tasks = {
        chat = "agy",
        learn = {
          agent = "opencode",
          instructions = "Learn Mode Instructions",
        },
        refactor = {
          agent = "codex",
          instructions = "Refactor Mode Instructions",
        },
      },
    }

    sagani._session_mode = "learn"
    local learn_agent = backend.resolve_task_agent(opts, "chat")
    assert_eq(learn_agent.agent, "opencode", "active learn mode resolves opencode agent from opts.tasks.learn")
    assert_eq(learn_agent.instructions, "Learn Mode Instructions", "learn mode resolves custom instructions")

    sagani._session_mode = "refactor"
    local refactor_agent = backend.resolve_task_agent(opts, "chat")
    assert_eq(refactor_agent.agent, "codex", "active refactor mode resolves codex agent from opts.tasks.refactor")
    assert_eq(refactor_agent.instructions, "Refactor Mode Instructions", "refactor mode resolves custom instructions")

    sagani._session_mode = nil
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
  print(string.format("TEST RESULTS (test_modes): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
