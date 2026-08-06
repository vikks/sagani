--- ==============================================================================
--- Spec: unit/resolver_spec.lua
---
--- Description:
---   Unit tests for sagani.resolver, sagani.agents, backend capabilities, and
---   sagani.config.validator.
--- ==============================================================================

local project_root = _G.SAGANI_PROJECT_ROOT or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local resolver = require("sagani.resolver")
local agents = require("sagani.agents")
local validator = require("sagani.config.validator")
local defaults = require("sagani.defaults")

local test_count = 0
local pass_count = 0

local function test(name, fn)
  test_count = test_count + 1
  print("\nRunning Test: " .. name)
  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print("  ✓ PASS: " .. name)
  else
    print("  ✗ FAIL: " .. name .. "\n    Error: " .. tostring(err))
    error(err)
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected '%s', got '%s'", msg or "Assertion failed", tostring(expected), tostring(actual)))
  end
end

local function assert_true(cond, msg)
  if not cond then
    error(msg or "Expected condition to be true")
  end
end

-- Test 1: Agents Registry & Declarative Capabilities
test("agents.get: retrieves agent harness modules and capabilities", function()
  local opencode = agents.get("opencode")
  assert_true(opencode ~= nil, "opencode agent module should exist")
  assert_eq(opencode.id, "opencode", "opencode ID match")
  assert_true(opencode.capabilities ~= nil, "opencode capabilities exist")
  assert_true(vim.tbl_contains(opencode.capabilities.protocols, "acp"), "opencode supports acp protocol")
  assert_eq(opencode.capabilities.streaming, true, "opencode supports streaming")

  local agy = agents.get("agy")
  assert_true(agy ~= nil, "agy agent module should exist")
  assert_eq(agy.id, "agy", "agy ID match")
  assert_true(vim.tbl_contains(agy.capabilities.protocols, "cli"), "agy supports cli protocol")

  local codex = agents.get("codex")
  assert_true(codex ~= nil, "codex agent module should exist")
  assert_eq(codex.capabilities.streaming, false, "codex streaming is false")
end)

-- Test 2: Backend Declarative Capabilities
test("backend.capabilities: exposes layout placements and geometry flags", function()
  local native = require("sagani.backend.native")
  assert_true(native.capabilities.float, "native float capability is true")
  assert_true(vim.tbl_contains(native.capabilities.placements, "popup"), "native supports popup placement")

  local herdr = require("sagani.backend.herdr")
  assert_eq(herdr.capabilities.float, false, "herdr float capability is false")
  assert_true(vim.tbl_contains(herdr.capabilities.placements, "pane"), "herdr supports pane placement")
end)

-- Test 3: Resolver builds complete ExecutionPlan without nils
test("resolver.build_plan: compiles raw request into complete ExecutionPlan", function()
  local plan = resolver.build_plan("ask", "What is Lua?", defaults.defaults)
  assert_eq(plan.task_type, "ask", "plan task_type is ask")
  assert_true(plan.agent.id ~= nil, "plan agent ID is non-nil")
  assert_true(plan.agent.cmd ~= nil and #plan.agent.cmd > 0, "plan agent cmd is non-empty array")
  assert_true(plan.backend.name ~= nil, "plan backend name is non-nil")
  assert_true(plan.backend.adapter ~= nil, "plan backend adapter is non-nil")
  assert_true(plan.ui.placement ~= nil, "plan ui placement is non-nil")
  assert_eq(plan.payload.raw_prompt, "What is Lua?", "plan payload prompt matches input")
end)

-- Test 4: Capability Matcher redirects unsupported backend placements
test("resolver.build_plan: redirects popup placement to native when backend float is false", function()
  local mock_opts = vim.deepcopy(defaults.defaults)
  mock_opts.tasks.ask = { agent = "agy", backend = "herdr" }
  mock_opts.backends.herdr.ask = "popup"

  local plan = resolver.build_plan("ask", "Test popup redirect", mock_opts)
  assert_eq(plan.backend.name, "native", "backend redirected to native float because herdr float is false")
  assert_eq(plan.ui.placement, "popup", "ui placement remains popup")
end)

-- Test 5: Config Validator detects invalid options early
test("validator.validate: catches invalid configuration options", function()
  local is_valid, errors = validator.validate(defaults.defaults)
  assert_true(is_valid, "default options are valid")
  assert_eq(#errors, 0, "no errors for default options")

  local bad_opts = { window_opts = { width = 1.5 } }
  local is_bad_valid, bad_errors = validator.validate(bad_opts)
  assert_eq(is_bad_valid, false, "invalid width triggers validation failure")
  assert_true(#bad_errors > 0, "errors returned for invalid width")
end)

print(string.format("\nResolver Spec Completed: %d passed out of %d tests.", pass_count, test_count))
