-- Challenger 2 Empirical Verification Test Harness (Gen 2)
-- herdr-agy.nvim (M1)

local project_root = vim.fn.getcwd()
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local topology = require("herdr-agy.topology")
local notify = require("herdr-agy.notify")
local init = require("herdr-agy.init")

local results = {
  passed = 0,
  failed = 0,
  failures = {},
}

local function log_test(name, pass, detail)
  if pass then
    results.passed = results.passed + 1
    print("  ✓ PASS: " .. name)
  else
    results.failed = results.failed + 1
    local msg = "  ✗ FAIL: " .. name .. " — " .. (detail or "Unexpected result")
    print(msg)
    table.insert(results.failures, msg)
  end
end

local function run_test(name, fn)
  print("\n[CHALLENGER 2 STRESS] " .. name)
  local ok, err = pcall(fn)
  if not ok then
    log_test(name, false, "CRASH: " .. tostring(err))
  end
end

-- ===================================================================
-- DEFECT CATEGORY 1: Stderr Capture in CLI Execution
-- ===================================================================

run_test("1.1 Stderr Captured when code ~= 0 and stderr is non-empty", function()
  local orig_sys = vim.system
  vim.system = function()
    return {
      wait = function()
        return { code = 1, stdout = "stdout warning", stderr = "herdr: error: pane w1:p99 does not exist" }
      end,
    }
  end

  local ok, err = init.dispatch_prompt("test prompt", "w1:p99")
  vim.system = orig_sys

  log_test("1.1 Stderr preferred over stdout on failure", ok == false and err ~= nil and err:find("herdr: error: pane w1:p99 does not exist") ~= nil, "err=" .. tostring(err))
end)

run_test("1.2 Stdout Fallback when code ~= 0 and stderr is empty", function()
  local orig_sys = vim.system
  vim.system = function()
    return {
      wait = function()
        return { code = 1, stdout = "CLI execution failure in stdout", stderr = "" }
      end,
    }
  end

  local ok, err = init.dispatch_prompt("test prompt", "w1:p99")
  vim.system = orig_sys

  log_test("1.2 Stdout fallback used when stderr empty", ok == false and err ~= nil and err:find("CLI execution failure in stdout") ~= nil, "err=" .. tostring(err))
end)

run_test("1.3 Empty Stderr and Stdout handled cleanly without crash", function()
  local orig_sys = vim.system
  vim.system = function()
    return {
      wait = function()
        return { code = 1, stdout = "", stderr = "" }
      end,
    }
  end

  local ok, err = init.dispatch_prompt("test prompt", "w1:p99")
  vim.system = orig_sys

  log_test("1.3 Empty outputs handled without crash", ok == false and err ~= nil, "err=" .. tostring(err))
end)

-- ===================================================================
-- DEFECT CATEGORY 2: Boolean & Flexible Notify Options
-- ===================================================================

run_test("2.1 notify = true enables notification without indexing crash", function()
  local called = false
  local orig_notify = vim.notify
  vim.notify = function(msg, level, opts)
    called = true
  end

  notify.info("Hello world", { notify = true })
  vim.notify = orig_notify

  log_test("2.1 notify = true enables notification", called == true)
end)

run_test("2.2 notify = false suppresses notification cleanly", function()
  local called = false
  local orig_notify = vim.notify
  vim.notify = function(msg, level, opts)
    called = true
  end

  notify.info("Hello world", { notify = false })
  vim.notify = orig_notify

  log_test("2.2 notify = false suppresses notification", called == false)
end)

run_test("2.3 notify = { enabled = false } suppresses notification", function()
  local called = false
  local orig_notify = vim.notify
  vim.notify = function(msg, level, opts)
    called = true
  end

  notify.info("Hello world", { notify = { enabled = false } })
  vim.notify = orig_notify

  log_test("2.3 notify = { enabled = false } suppresses notification", called == false)
end)

run_test("2.4 notify = { title = 'Custom' } sets notification title", function()
  local captured_title = nil
  local orig_notify = vim.notify
  vim.notify = function(msg, level, opts)
    captured_title = opts and opts.title
  end

  notify.info("Hello world", { notify = { title = "Custom AGY Title" } })
  vim.notify = orig_notify

  log_test("2.4 notify table title extracted correctly", captured_title == "Custom AGY Title", "title=" .. tostring(captured_title))
end)

run_test("2.5 Primitive options (number, boolean, string) handled safely", function()
  local called_count = 0
  local orig_notify = vim.notify
  vim.notify = function()
    called_count = called_count + 1
  end

  notify.info("Msg 1", 12345)
  notify.info("Msg 2", true)
  notify.info("Msg 3", "invalid_opts_str")

  vim.notify = orig_notify

  log_test("2.5 Primitive opts handled safely", called_count == 3, "called_count=" .. tostring(called_count))
end)

-- ===================================================================
-- DEFECT CATEGORY 3: Empty Target Pane Handling
-- ===================================================================

run_test("3.1 Empty string target_pane normalizes to nil and invokes discover_target_pane", function()
  local orig_env = vim.env.HERDR_ENV
  vim.env.HERDR_ENV = nil

  local ok, err = init.dispatch_prompt("valid prompt", "")

  vim.env.HERDR_ENV = orig_env

  log_test("3.1 empty target_pane triggers discover_target_pane", ok == false and err ~= nil and err:find("HERDR_ENV missing") ~= nil, "err=" .. tostring(err))
end)

run_test("3.2 nil target_pane invokes discover_target_pane", function()
  local orig_env = vim.env.HERDR_ENV
  vim.env.HERDR_ENV = nil

  local ok, err = init.dispatch_prompt("valid prompt", nil)

  vim.env.HERDR_ENV = orig_env

  log_test("3.2 nil target_pane triggers discover_target_pane", ok == false and err ~= nil and err:find("HERDR_ENV missing") ~= nil, "err=" .. tostring(err))
end)

-- ===================================================================
-- DEFECT CATEGORY 4: Prompt Text Validation
-- ===================================================================

run_test("4.1 dispatch_prompt validates nil, empty string, or non-string prompt_text", function()
  local ok1, err1 = init.dispatch_prompt(nil, "p1")
  local ok2, err2 = init.dispatch_prompt("", "p1")
  local ok3, err3 = init.dispatch_prompt(12345, "p1")
  local ok4, err4 = init.dispatch_prompt({}, "p1")

  local pass = (ok1 == false and err1:find("Invalid prompt text") ~= nil) and
               (ok2 == false and err2:find("Invalid prompt text") ~= nil) and
               (ok3 == false and err3:find("Invalid prompt text") ~= nil) and
               (ok4 == false and err4:find("Invalid prompt text") ~= nil)

  log_test("4.1 Prompt text type & presence validation", pass, "err1=" .. tostring(err1))
end)

-- ===================================================================
-- DEFECT CATEGORY 5: Setup user_opts Validation
-- ===================================================================

run_test("5.1 setup() handles non-table user_opts gracefully", function()
  local ok1 = pcall(function() init.setup("string_opts") end)
  local ok2 = pcall(function() init.setup(999) end)
  local ok3 = pcall(function() init.setup(true) end)
  local ok4 = pcall(function() init.setup(nil) end)

  log_test("5.1 setup handles primitive/nil user_opts without throwing error", ok1 and ok2 and ok3 and ok4)
end)

run_test("5.2 setup() merges valid user_opts table with defaults", function()
  init.setup({
    target_agent = "my_custom_agent",
    auto_discover = false,
  })

  log_test("5.2 setup merges table options with defaults", init.options.target_agent == "my_custom_agent" and init.options.auto_discover == false and init.options.notify ~= nil)
end)

print("\n==========================================================")
print(string.format("CHALLENGER 2 STRESS TEST RESULTS: %d Passed, %d Failed", results.passed, results.failed))
print("==========================================================")

if results.failed > 0 then
  for _, f in ipairs(results.failures) do
    print(f)
  end
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
