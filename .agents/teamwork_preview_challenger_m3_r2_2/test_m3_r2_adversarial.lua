-- Headless Neovim Empirical Adversarial Test Suite for M3 R2
-- Agent: teamwork_preview_challenger_m3_r2_2
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local init = require("herdr-agy")
local topology = require("herdr-agy.topology")
local format = require("herdr-agy.format")
local selection = require("herdr-agy.selection")

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

  local plugin_spec_path = project_root .. "/plugins/herdr-agy.lua"

  print("==========================================================")
  print("  Challenger 2 Empirical Test Harness (M3 R2)")
  print("  Project Root: " .. project_root)
  print("==========================================================")

  -- ==========================================================
  -- 1. LAZYVIM PLUGIN SPEC & COMMAND LAZY-LOADING VERIFICATION
  -- ==========================================================
  run_test("spec: LazyVim spec file structure and lazy load commands", function()
    assert_eq(vim.fn.filereadable(plugin_spec_path), 1, "plugin spec readable")
    local specs = dofile(plugin_spec_path)
    assert_true(type(specs) == "table" and #specs == 2, "spec returns array of 2 plugin configs")

    local main_spec = nil
    for _, s in ipairs(specs) do
      if s.name == "herdr-agy.nvim" or s[1] == "herdr-agy.nvim" then
        main_spec = s
      end
    end
    assert_true(main_spec ~= nil, "main plugin spec herdr-agy.nvim exists")

    local expected_cmds = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyContext",
      "HerdrAgyDiff",
    }
    assert_eq(#main_spec.cmd, #expected_cmds, "cmd list has exactly 6 commands")
    for _, cmd_name in ipairs(expected_cmds) do
      assert_true(vim.tbl_contains(main_spec.cmd, cmd_name), "lazy cmd contains: " .. cmd_name)
    end
  end)

  run_test("spec: Keymaps cover all 6 commands and modes", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = nil
    for _, s in ipairs(specs) do
      if s.name == "herdr-agy.nvim" or s[1] == "herdr-agy.nvim" then
        main_spec = s
      end
    end

    local keys = main_spec.keys
    assert_true(type(keys) == "table" and #keys >= 6, "keys table defined with at least 6 keymaps")

    local registered_cmds = {}
    for _, k in ipairs(keys) do
      local cmd_str = k[2]:match("<cmd>(%w+)<cr>") or k[2]
      registered_cmds[cmd_str] = true
    end

    assert_true(registered_cmds["HerdrAgyStatus"], "Keymap for HerdrAgyStatus present")
    assert_true(registered_cmds["HerdrAgySelectTarget"], "Keymap for HerdrAgySelectTarget present")
    assert_true(registered_cmds["HerdrAgyPrompt"], "Keymap for HerdrAgyPrompt present")
    assert_true(registered_cmds["HerdrAgySend"], "Keymap for HerdrAgySend present")
    assert_true(registered_cmds["HerdrAgyContext"], "Keymap for HerdrAgyContext present")
    assert_true(registered_cmds["HerdrAgyDiff"], "Keymap for HerdrAgyDiff present")
  end)

  -- Setup plugin config for execution tests
  init.setup({ notify = { enabled = false } })

  -- ==========================================================
  -- 2. EMPIRICAL EXECUTION: Command 1 — HerdrAgyStatus
  -- ==========================================================
  run_test("cmd: HerdrAgyStatus execution under active/inactive Herdr env", function()
    local old_env = vim.env.HERDR_ENV
    
    -- Inactive Herdr env
    vim.env.HERDR_ENV = nil
    local ok1 = pcall(vim.cmd, "HerdrAgyStatus")
    assert_true(ok1, "HerdrAgyStatus executes without error in non-Herdr env")

    -- Active Herdr env (mocked)
    vim.env.HERDR_ENV = "test_session:1:1"
    local ok2 = pcall(vim.cmd, "HerdrAgyStatus")
    assert_true(ok2, "HerdrAgyStatus executes without error in active Herdr env")

    -- With manual pane override set
    init.options.pane_override = "pane_override_999"
    local ok3 = pcall(vim.cmd, "HerdrAgyStatus")
    assert_true(ok3, "HerdrAgyStatus executes with pane_override set")
    init.options.pane_override = nil

    vim.env.HERDR_ENV = old_env
  end)

  -- ==========================================================
  -- 3. EMPIRICAL EXECUTION: Command 2 — HerdrAgySelectTarget
  -- ==========================================================
  run_test("cmd: HerdrAgySelectTarget interactive input handling", function()
    local orig_input = vim.ui.input

    -- Case 1: Valid input sets override
    vim.ui.input = function(opts, cb) cb("custom_pane_42") end
    vim.cmd("HerdrAgySelectTarget")
    assert_eq(init.options.pane_override, "custom_pane_42", "override set to custom_pane_42")

    -- Case 2: Empty input clears override
    vim.ui.input = function(opts, cb) cb("") end
    vim.cmd("HerdrAgySelectTarget")
    assert_nil(init.options.pane_override, "empty input clears override to nil")

    -- Case 3: Nil input (cancelled input) clears override
    init.options.pane_override = "temp_pane"
    vim.ui.input = function(opts, cb) cb(nil) end
    vim.cmd("HerdrAgySelectTarget")
    assert_nil(init.options.pane_override, "nil input clears override to nil")

    vim.ui.input = orig_input
  end)

  -- ==========================================================
  -- 4. EMPIRICAL EXECUTION: Command 3 — HerdrAgyPrompt
  -- ==========================================================
  run_test("cmd: HerdrAgyPrompt with inline args and interactive fallback", function()
    local orig_input = vim.ui.input
    local captured_dispatch = nil
    local orig_dispatch = init.dispatch_prompt

    init.dispatch_prompt = function(text, target, opts)
      captured_dispatch = text
      return true, nil
    end

    -- Case 1: Inline arguments
    vim.cmd("HerdrAgyPrompt Hello from test runner")
    assert_eq(captured_dispatch, "Hello from test runner", "HerdrAgyPrompt dispatches inline args")

    -- Case 2: Special characters and quotes in inline args
    vim.cmd([[HerdrAgyPrompt Refactor this code: function foo(x) { return x + "bar"; }]])
    assert_eq(captured_dispatch, [[Refactor this code: function foo(x) { return x + "bar"; }]], "HerdrAgyPrompt handles special characters")

    -- Case 3: Interactive fallback when no args supplied
    captured_dispatch = nil
    vim.ui.input = function(opts, cb) cb("Prompt from input dialog") end
    vim.cmd("HerdrAgyPrompt")
    assert_eq(captured_dispatch, "Prompt from input dialog", "HerdrAgyPrompt triggers vim.ui.input fallback when args empty")

    -- Case 4: Cancelled input (nil or empty)
    captured_dispatch = nil
    vim.ui.input = function(opts, cb) cb("") end
    vim.cmd("HerdrAgyPrompt")
    assert_nil(captured_dispatch, "HerdrAgyPrompt does not dispatch on empty input")

    init.dispatch_prompt = orig_dispatch
    vim.ui.input = orig_input
  end)

  -- ==========================================================
  -- 5. EMPIRICAL EXECUTION: Command 4 — HerdrAgySend
  -- ==========================================================
  run_test("cmd: HerdrAgySend visual selection & instruction prompt formatting", function()
    local orig_input = vim.ui.input
    local captured_payload = nil
    local orig_dispatch = init.dispatch_prompt

    init.dispatch_prompt = function(payload, target, opts)
      captured_payload = payload
      return true, nil
    end

    -- Create test buffer with code
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "/tmp/test_script.lua")
    vim.api.nvim_buf_set_option(buf, "filetype", "lua")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "local function add(a, b)",
      "  return a + b",
      "end",
    })
    vim.api.nvim_set_current_buf(buf)

    -- Mock visual selection range lines 1-2
    vim.fn.setpos("'<", { buf, 1, 1, 0 })
    vim.fn.setpos("'>", { buf, 2, 14, 0 })

    -- Mock user instruction input
    vim.ui.input = function(opts, cb) cb("Optimize this function") end

    local ok = pcall(vim.cmd, "HerdrAgySend")
    assert_true(ok, "HerdrAgySend executes without error")
    assert_true(captured_payload ~= nil, "Payload captured by dispatch_prompt")

    -- Verify markdown formatting of context payload
    assert_true(captured_payload:find("Optimize this function") ~= nil, "Payload contains user instruction")
    assert_true(captured_payload:find("/tmp/test_script.lua") ~= nil, "Payload contains file path")
    assert_true(captured_payload:find("```lua") ~= nil, "Payload contains lua markdown code block")
    assert_true(captured_payload:find("local function add") ~= nil, "Payload contains code snippet")

    init.dispatch_prompt = orig_dispatch
    vim.ui.input = orig_input
  end)

  -- ==========================================================
  -- 6. EMPIRICAL EXECUTION: Command 5 — HerdrAgyContext
  -- ==========================================================
  run_test("cmd: HerdrAgyContext visual selection code context dispatch", function()
    local captured_payload = nil
    local orig_dispatch = init.dispatch_prompt

    init.dispatch_prompt = function(payload, target, opts)
      captured_payload = payload
      return true, nil
    end

    -- Create test buffer with Python code
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "app/main.py")
    vim.api.nvim_buf_set_option(buf, "filetype", "python")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "def greet(name):",
      "    print(f'Hello {name}')",
    })
    vim.api.nvim_set_current_buf(buf)

    vim.fn.setpos("'<", { buf, 1, 1, 0 })
    vim.fn.setpos("'>", { buf, 2, 26, 0 })

    local ok = pcall(vim.cmd, "HerdrAgyContext")
    assert_true(ok, "HerdrAgyContext executes without error")
    assert_true(captured_payload ~= nil, "Payload captured by dispatch_prompt")

    assert_true(captured_payload:find("Context snippet for review:") ~= nil, "Payload contains default context header")
    assert_true(captured_payload:find("app/main.py") ~= nil, "Payload contains file path app/main.py")
    assert_true(captured_payload:find("```python") ~= nil, "Payload contains python code block")
    assert_true(captured_payload:find("def greet%(name%):") ~= nil, "Payload contains snippet text")

    init.dispatch_prompt = orig_dispatch
  end)

  -- ==========================================================
  -- 7. EMPIRICAL EXECUTION: Command 6 — HerdrAgyDiff
  -- ==========================================================
  run_test("cmd: HerdrAgyDiff execution", function()
    local ok = pcall(vim.cmd, "HerdrAgyDiff")
    assert_true(ok, "HerdrAgyDiff executes cleanly")
  end)

  -- ==========================================================
  -- 8. NON-BLOCKING BEHAVIOR & DISPATCH DISCOVERY CORNER CASES
  -- ==========================================================
  run_test("dispatch: non-blocking system execution and missing binary handling", function()
    init.options.pane_override = "pane_target_1"

    -- Mock executable check to return 0 (herdr not installed)
    local orig_exec = vim.fn.executable
    vim.fn.executable = function(cmd)
      if cmd == "herdr" then return 0 end
      return orig_exec(cmd)
    end

    local success, err = init.dispatch_prompt("Test prompt", nil, init.options)
    assert_false(success, "dispatch fails gracefully when herdr binary missing")
    assert_true(err:find("not found in PATH") ~= nil, "error message specifies missing PATH binary")

    vim.fn.executable = orig_exec
    init.options.pane_override = nil
  end)

  run_test("dispatch: non-blocking dispatch with mocked vim.system process execution", function()
    init.options.pane_override = "pane_target_99"

    local sys_cmd_executed = nil
    local orig_system = vim.system
    vim.system = function(cmd)
      sys_cmd_executed = cmd
      return {
        wait = function()
          return { code = 0, stdout = "OK", stderr = "" }
        end
      }
    end

    local success, err = init.dispatch_prompt("Adversarial payload check", nil, init.options)
    assert_true(success, "dispatch succeeds with mocked vim.system")
    assert_nil(err, "no error on success")
    assert_true(sys_cmd_executed ~= nil, "vim.system called")
    assert_eq(sys_cmd_executed[1], "herdr", "cmd binary is herdr")
    assert_eq(sys_cmd_executed[2], "agent", "cmd sub1 is agent")
    assert_eq(sys_cmd_executed[3], "prompt", "cmd sub2 is prompt")
    assert_eq(sys_cmd_executed[4], "pane_target_99", "cmd target pane is pane_target_99")
    assert_eq(sys_cmd_executed[5], "Adversarial payload check", "cmd prompt text is correct")

    vim.system = orig_system
    init.options.pane_override = nil
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
  print(string.format("CHALLENGER TEST RESULTS: %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
