-- tests/test_challenger2_empirical.lua
-- Empirical stress testing & boundary verification suite by Challenger 2

local project_root = _G.SAGANI_PROJECT_ROOT or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. project_root .. "/?.lua;" .. package.path

_G.RUNNING_TEST_SUITE = true

local sagani = require("sagani")
local topology = require("sagani.backend.herdr.topology")
local selection = require("sagani.selection")
local diff = require("sagani.diff")
local format = require("sagani.format")
local notify = require("sagani.notify")

local M = {}

function M.run()
  local test_count = 0
  local pass_count = 0
  local fail_count = 0
  local failures = {}

  local function test(name, fn)
    test_count = test_count + 1
    print(string.format("\nChallenger 2 Empirical Test [%d]: %s", test_count, name))
    local ok, err = pcall(fn)
    if ok then
      pass_count = pass_count + 1
      print("  ✓ PASS")
    else
      fail_count = fail_count + 1
      table.insert(failures, string.format("%s: %s", name, tostring(err)))
      print("  ✗ FAIL: " .. tostring(err))
    end
  end

  local function assert_equal(expected, actual, msg)
    if expected ~= actual then
      error(string.format("%s - Expected: %s, Got: %s", msg or "Assertion failed", vim.inspect(expected), vim.inspect(actual)))
    end
  end

  local function assert_true(cond, msg)
    if not cond then
      error(msg or "Expected condition to be true")
    end
  end

  local function assert_false(cond, msg)
    if cond then
      error(msg or "Expected condition to be false")
    end
  end

  -- ============================================================================
  -- 1. SESSION CACHING LIFECYCLE TESTS
  -- ============================================================================

  test("Target Agent Lifecycle: Selection via select_agent_harness propagates to ask_agent_prompt", function()
    sagani.setup({ tasks = { ask = "agy" }, ask_agent = { popup = true } })

    local last_dispatched_opts = nil
    local orig_dispatch = sagani.dispatch_prompt
    sagani.dispatch_prompt = function(prompt, pane, opts)
      last_dispatched_opts = opts
      return true, nil
    end

    sagani.select_agent_harness("hermes")
    assert_equal("hermes", sagani._session_harness, "Target agent set to 'hermes'")

    sagani.ask_agent_prompt("Test prompt", { notify = { enabled = false } })
    local dispatched_harness = last_dispatched_opts.agent_opts and last_dispatched_opts.agent_opts.harness
    assert_equal("hermes", dispatched_harness, "ask_agent_prompt uses target_agent 'hermes'")

    sagani.dispatch_prompt = orig_dispatch
  end)

  test("Session Caching Lifecycle: Explicit opts.tasks.ask overrides default", function()
    sagani.setup({ tasks = { ask = "agy" } })

    local dispatched_opts = nil
    sagani.dispatch_prompt = function(prompt, pane, opts)
      dispatched_opts = opts
      return true, nil
    end

    local original_input = vim.ui.input
    vim.ui.input = function(opts, on_confirm)
      on_confirm("Test query")
    end

    -- Invoke with explicit tasks.ask in options
    sagani.ask_agent_prompt("Test prompt", { tasks = { ask = "codex" } })
    local dispatched_harness = dispatched_opts.agent_opts and dispatched_opts.agent_opts.harness
    assert_equal("codex", dispatched_harness, "Dispatched opts should use explicit 'codex'")

    vim.ui.input = original_input
  end)

  test("Session Caching Lifecycle: Setup re-initialization preserves vs reload clears cache", function()
    sagani._session_ask_agent = "opencode"
    sagani.setup({ target_agent = "agy" })
    assert_equal("opencode", sagani._session_ask_agent, "setup() should preserve _session_ask_agent")

    -- Test SaganiReload user command behavior
    sagani.setup({})
    sagani._session_ask_agent = "opencode"
    for k in pairs(package.loaded) do
      if k:find("^sagani") then
        package.loaded[k] = nil
      end
    end
    sagani = require("sagani")
    assert_equal(nil, sagani._session_ask_agent, "Fresh module require after reload should reset session cache")
  end)

  test("Session Caching Lifecycle: Cancellation does not pollute session cache", function()
    sagani.setup({ ask_agent = { target_agent = nil } })
    sagani._session_ask_agent = nil

    local original_select = vim.ui.select
    vim.ui.select = function(items, opts, on_confirm)
      on_confirm(nil) -- User cancels (nil = no selection)
    end

    sagani.ask_agent_prompt(nil)
    assert_equal(nil, sagani._session_ask_agent, "Cancelled selection should leave session cache as nil")

    vim.ui.select = original_select
  end)

  -- ============================================================================
  -- 2. MULTI-BUFFER PATH REFERENCE HANDLING TESTS
  -- ============================================================================

  test("Multi-Buffer Path Reference: Correct @[abs_path] injection across active buffers", function()
    local buf1 = vim.api.nvim_create_buf(true, false)
    local buf2 = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf1, "/tmp/project/src/main.lua")
    vim.api.nvim_buf_set_name(buf2, "/tmp/project/tests/test_main.py")

    local orig_dispatch = sagani.dispatch_prompt
    local last_prompt = nil
    sagani.dispatch_prompt = function(prompt, pane, opts)
      last_prompt = prompt
      return true, nil
    end

    -- Set active buffer to buf1
    vim.api.nvim_set_current_buf(buf1)
    sagani.ask_agent_prompt("Explain function", { ask_agent = { target_agent = "agy" } })
    assert_true(last_prompt:find("@[/tmp/project/src/main.lua]", 1, true) ~= nil, "Should inject buf1 path into prompt")

    -- Switch active buffer to buf2
    vim.api.nvim_set_current_buf(buf2)
    sagani.ask_agent_prompt("Check imports", { ask_agent = { target_agent = "agy" } })
    assert_true(last_prompt:find("@[/tmp/project/tests/test_main.py]", 1, true) ~= nil, "Should inject buf2 path into prompt")

    sagani.dispatch_prompt = orig_dispatch
    vim.api.nvim_buf_delete(buf1, { force = true })
    vim.api.nvim_buf_delete(buf2, { force = true })
  end)

  test("Multi-Buffer Path Reference: Unnamed buffer ([No Name]) does not inject empty or invalid @[]", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(buf) -- [No Name] buffer

    local orig_dispatch = sagani.dispatch_prompt
    local last_prompt = nil
    sagani.dispatch_prompt = function(prompt, pane, opts)
      last_prompt = prompt
      return true, nil
    end

    sagani.ask_agent_prompt("What is this?", { ask_agent = { target_agent = "agy" } })
    assert_equal("What is this?", last_prompt, "Prompt should be unchanged for unnamed buffer")
    assert_false(last_prompt:find("@%[") ~= nil, "No @[] reference should be added for unnamed buffer")

    sagani.dispatch_prompt = orig_dispatch
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("Multi-Buffer Path Reference: Existing @[...] in prompt text prevents duplicate injection", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, "/tmp/project/src/app.lua")
    vim.api.nvim_set_current_buf(buf)

    local orig_dispatch = sagani.dispatch_prompt
    local last_prompt = nil
    sagani.dispatch_prompt = function(prompt, pane, opts)
      last_prompt = prompt
      return true, nil
    end

    sagani.ask_agent_prompt("Refactor @[/tmp/other.lua] please", { ask_agent = { target_agent = "agy" } })
    assert_equal("Refactor @[/tmp/other.lua] please", last_prompt, "Should preserve existing @[...] reference without appending active buffer")

    sagani.dispatch_prompt = orig_dispatch
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("Multi-Buffer Path Reference: Special characters and spaces in file paths", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, "/tmp/my path/file [v1].lua")
    vim.api.nvim_set_current_buf(buf)

    local orig_dispatch = sagani.dispatch_prompt
    local last_prompt = nil
    sagani.dispatch_prompt = function(prompt, pane, opts)
      last_prompt = prompt
      return true, nil
    end

    sagani.ask_agent_prompt("Review this file", { ask_agent = { target_agent = "agy" } })
    assert_true(last_prompt:find("@[/tmp/my path/file [v1].lua]", 1, true) ~= nil, "Should correctly handle spaces and brackets in path")

    sagani.dispatch_prompt = orig_dispatch
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  -- ============================================================================
  -- 3. LAZYVIM SPEC OPTIONS MERGING TESTS
  -- ============================================================================

  test("LazyVim Spec: Plugin spec structure and options merging", function()
    local spec_file = vim.fn.expand("plugins/sagani.lua")
    assert_true(vim.fn.filereadable(spec_file) == 1, "plugins/sagani.lua must exist and be readable")

    local specs = dofile(spec_file)
    assert_equal("table", type(specs), "Spec file should return a table")
    assert_true(#specs >= 2, "Spec file should return WhichKey and plugin specs")

    local main_spec = specs[2]
    assert_equal("sagani.nvim", main_spec.name, "Plugin name must be sagani.nvim")
    assert_equal("table", type(main_spec.cmd), "Cmds must be a table")
    assert_equal("table", type(main_spec.keys), "Keys must be a table")
    assert_equal("table", type(main_spec.opts), "Default opts must be a table")
    assert_equal("function", type(main_spec.config), "Config must be a function")

    sagani.setup(main_spec.opts)
    local ask_agent_name = type(sagani.options.tasks.ask) == "table" and sagani.options.tasks.ask.agent or sagani.options.tasks.ask
    assert_equal("agy", ask_agent_name, "Default task ask should be agy")

    sagani.setup({ tasks = { ask = "codex" } })
    local override_ask_name = type(sagani.options.tasks.ask) == "table" and sagani.options.tasks.ask.agent or sagani.options.tasks.ask
    assert_equal("codex", override_ask_name, "Partial tasks.ask override should apply")

    sagani.setup({ modes = { review = { auto_open = true } } })
    assert_equal(true, sagani.options.modes.review.enabled, "Unspecified modes.review.enabled should retain default true")
    assert_equal(true, sagani.options.modes.review.auto_open, "Explicit modes.review.auto_open should be true")
  end)

  -- ============================================================================
  -- 4. VISUAL MODE RANGE PASSING & SELECTION TESTS
  -- ============================================================================

  test("Visual Mode Range: Forward linewise visual selection ('V')", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3", "line 4" })
    vim.api.nvim_set_current_buf(buf)

    vim.fn.setpos("'<", { buf, 2, 1, 0 })
    vim.fn.setpos("'>", { buf, 3, 6, 0 })

    local sel = selection.get_visual_selection(buf)
    assert_equal(2, sel.start_line, "start_line should be 2")
    assert_equal(3, sel.end_line, "end_line should be 3")
    assert_equal("line 2\nline 3", sel.snippet, "Snippet should contain lines 2 and 3")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("Visual Mode Range: Reversed visual selection (bottom-to-top)", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "alpha", "beta", "gamma", "delta" })
    vim.api.nvim_set_current_buf(buf)

    vim.fn.setpos("'<", { buf, 4, 5, 0 })
    vim.fn.setpos("'>", { buf, 2, 1, 0 })

    local sel = selection.get_visual_selection(buf)
    assert_equal(2, sel.start_line, "Normalized start_line should be 2")
    assert_equal(4, sel.end_line, "Normalized end_line should be 4")
    assert_true(sel.snippet:find("beta\ngamma\ndelta") ~= nil, "Snippet should match normalized range")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("Visual Mode Range: Characterwise selection across line boundary ('v')", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello world", "foo bar baz" })
    vim.api.nvim_set_current_buf(buf)

    vim.fn.setpos("'<", { buf, 1, 7, 0 })
    vim.fn.setpos("'>", { buf, 2, 7, 0 })

    local sel = selection.get_visual_selection(buf)
    assert_equal(1, sel.start_line)
    assert_equal(2, sel.end_line)
    assert_equal("world\nfoo bar", sel.snippet)

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  test("Visual Mode Range: Non-current buffer parameter in get_visual_selection", function()
    local buf1 = vim.api.nvim_create_buf(true, false)
    local buf2 = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "buf1 line 1", "buf1 line 2" })
    vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "buf2 line 1", "buf2 line 2", "buf2 line 3" })

    vim.api.nvim_set_current_buf(buf1)
    vim.fn.setpos("'<", { buf1, 1, 1, 0 })
    vim.fn.setpos("'>", { buf1, 2, 11, 0 })

    local sel = selection.get_visual_selection(buf2)
    assert_equal("buf2 line 1\nbuf2 line 2", sel.snippet, "get_visual_selection(buf2) should retrieve lines from buf2")

    vim.api.nvim_buf_delete(buf1, { force = true })
    vim.api.nvim_buf_delete(buf2, { force = true })
  end)

  return {
    passed = pass_count,
    failed = fail_count,
    failures = failures,
  }
end

return M
