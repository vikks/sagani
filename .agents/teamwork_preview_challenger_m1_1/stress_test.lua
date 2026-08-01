-- Empirical Stress Test Harness for herdr-agy.nvim (M1) - Expanded Suite
-- Created by Challenger 1 (teamwork_preview_challenger_m1_1)

local project_root = vim.fn.getcwd()
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local topology = require("herdr-agy.topology")
local notify = require("herdr-agy.notify")
local init = require("herdr-agy.init")

local results = {
  passed = 0,
  failed = 0,
  details = {},
}

local function log_result(name, passed, detail)
  if passed then
    results.passed = results.passed + 1
    print(string.format("  ✓ PASS: %s", name))
  else
    results.failed = results.failed + 1
    local msg = string.format("  ✗ FAIL: %s — %s", name, detail or "No details")
    print(msg)
    table.insert(results.details, msg)
  end
end

local function run_scenario(name, fn)
  print("\n[STRESS TEST] " .. name)
  local ok, err = pcall(fn)
  if not ok then
    log_result(name, false, "CRASH/UNHANDLED EXCEPTION: " .. tostring(err))
  end
end

-- ===================================================================
-- CATEGORY 1: Malformed JSON and CLI Output in list_agents()
-- ===================================================================

run_scenario("JSON 1.1: Truncated / Invalid JSON syntax", function()
  local mock_runner = function() return '{"result": {"agents": [', 0 end
  local agents, err = topology.list_agents(mock_runner)
  if agents == nil and err ~= nil and err:find("Failed to parse JSON") then
    log_result("JSON 1.1: Truncated JSON handled gracefully", true)
  else
    log_result("JSON 1.1: Truncated JSON handled gracefully", false, "Got agents=" .. tostring(agents) .. ", err=" .. tostring(err))
  end
end)

run_scenario("JSON 1.2: JSON result field is primitive number (data.result = 123)", function()
  local mock_runner = function() return '{"result": 123}', 0 end
  local agents, err = topology.list_agents(mock_runner)
  if agents == nil and err ~= nil then
    log_result("JSON 1.2: Primitive result field handled gracefully", true)
  else
    log_result("JSON 1.2: Primitive result field handled gracefully", false, "Got agents=" .. tostring(agents) .. ", err=" .. tostring(err))
  end
end)

run_scenario("JSON 1.3: JSON result field is boolean true (data.result = true)", function()
  local mock_runner = function() return '{"result": true}', 0 end
  local agents, err = topology.list_agents(mock_runner)
  if agents == nil and err ~= nil then
    log_result("JSON 1.3: Boolean result field handled gracefully", true)
  else
    log_result("JSON 1.3: Boolean result field handled gracefully", false, "Got agents=" .. tostring(agents) .. ", err=" .. tostring(err))
  end
end)

run_scenario("JSON 1.4: JSON result field is string (data.result = 'error')", function()
  local mock_runner = function() return '{"result": "error"}', 0 end
  local agents, err = topology.list_agents(mock_runner)
  if agents == nil and err ~= nil then
    log_result("JSON 1.4: String result field handled gracefully", true)
  else
    log_result("JSON 1.4: String result field handled gracefully", false, "Got agents=" .. tostring(agents) .. ", err=" .. tostring(err))
  end
end)

run_scenario("JSON 1.5: JSON result.agents is string instead of array", function()
  local mock_runner = function() return '{"result": {"agents": "none"}}', 0 end
  local agents, err = topology.list_agents(mock_runner)
  if agents == nil and err ~= nil then
    log_result("JSON 1.5: String agents field handled gracefully", true)
  else
    log_result("JSON 1.5: String agents field handled gracefully", false, "Got agents=" .. tostring(agents) .. ", err=" .. tostring(err))
  end
end)

run_scenario("JSON 1.6: JSON array response instead of object", function()
  local mock_runner = function() return '[{"agent": "agy"}]', 0 end
  local agents, err = topology.list_agents(mock_runner)
  if agents == nil and err ~= nil then
    log_result("JSON 1.6: Top-level JSON array handled gracefully", true)
  else
    log_result("JSON 1.6: Top-level JSON array handled gracefully", false, "Got agents=" .. tostring(agents) .. ", err=" .. tostring(err))
  end
end)

run_scenario("JSON 1.7: JSON primitive string output", function()
  local mock_runner = function() return '"plain string"', 0 end
  local agents, err = topology.list_agents(mock_runner)
  if agents == nil and err ~= nil then
    log_result("JSON 1.7: Primitive JSON string handled gracefully", true)
  else
    log_result("JSON 1.7: Primitive JSON string handled gracefully", false, "Got agents=" .. tostring(agents) .. ", err=" .. tostring(err))
  end
end)

run_scenario("JSON 1.8: Non-table items inside agents array", function()
  local mock_runner = function()
    return '{"result": {"agents": ["invalid_string_agent", 12345]}}', 0
  end
  local agents, err = topology.list_agents(mock_runner)
  if agents then
    local pane, d_err = topology.discover_target_pane({ agents = agents, ignore_herdr_env = true })
    log_result("JSON 1.8: Non-table agents in array handled by discover_target_pane", pane == nil, "pane=" .. tostring(pane) .. ", err=" .. tostring(d_err))
  else
    log_result("JSON 1.8: Non-table agents in array handled", true)
  end
end)

-- ===================================================================
-- CATEGORY 2: discover_target_pane Edge Cases & Data Type Stress
-- ===================================================================

run_scenario("DISCOVER 2.1: Candidates array with non-table elements", function()
  local agents = { "string_agent", 42, true, { agent = "agy", pane_id = "p1" } }
  local pane, err = topology.discover_target_pane({ agents = agents, ignore_herdr_env = true })
  if pane == "p1" then
    log_result("DISCOVER 2.1: Non-table elements in agents array skipped gracefully", true)
  else
    log_result("DISCOVER 2.1: Non-table elements in agents array skipped gracefully", false, "Got pane=" .. tostring(pane) .. ", err=" .. tostring(err))
  end
end)

run_scenario("DISCOVER 2.2: Candidate agent has nil pane_id", function()
  local agents = {
    { agent = "agy", pane_id = nil, tab_id = "t1", workspace_id = "w1" },
  }
  local pane, err = topology.discover_target_pane({ agents = agents, workspace_id = "w1", tab_id = "t1", ignore_herdr_env = true })
  if pane == nil and err ~= nil then
    log_result("DISCOVER 2.2: Candidate with nil pane_id returns nil pane AND non-nil error", true)
  else
    log_result("DISCOVER 2.2: Candidate with nil pane_id returns nil pane AND non-nil error", false, "Got pane=" .. tostring(pane) .. ", err=" .. tostring(err))
  end
end)

run_scenario("DISCOVER 2.3: Candidate agent has empty string pane_id", function()
  local agents = {
    { agent = "agy", pane_id = "", tab_id = "t1", workspace_id = "w1" },
  }
  local pane, err = topology.discover_target_pane({ agents = agents, workspace_id = "w1", tab_id = "t1", ignore_herdr_env = true })
  if pane == nil and err ~= nil then
    log_result("DISCOVER 2.3: Candidate with empty pane_id returns nil pane AND non-nil error", true)
  else
    log_result("DISCOVER 2.3: Candidate with empty pane_id returns nil pane AND non-nil error", false, "Got pane=" .. tostring(pane) .. ", err=" .. tostring(err))
  end
end)

run_scenario("DISCOVER 2.4: Non-string pane_override (e.g. number 100)", function()
  local pane, err = topology.discover_target_pane({ pane_override = 100 })
  if type(pane) == "string" or (pane == nil and err ~= nil) then
    log_result("DISCOVER 2.4: Non-string pane_override handled safely", true)
  else
    log_result("DISCOVER 2.4: Non-string pane_override handled safely", false, "Returned non-string pane: " .. type(pane) .. " (" .. tostring(pane) .. ")")
  end
end)

run_scenario("DISCOVER 2.5: Non-string target_agent (e.g. table)", function()
  local agents = { { agent = "agy", pane_id = "p1" } }
  local pane, err = topology.discover_target_pane({ agents = agents, target_agent = { "agy" }, ignore_herdr_env = true })
  if pane == nil and err ~= nil then
    log_result("DISCOVER 2.5: Non-string target_agent handled safely without string.format crash", true)
  else
    log_result("DISCOVER 2.5: Non-string target_agent handled safely without string.format crash", false, "Got pane=" .. tostring(pane) .. ", err=" .. tostring(err))
  end
end)

run_scenario("DISCOVER 2.6: Caller pane exclusion when caller_pane_id is empty string vs nil", function()
  local agents = {
    { agent = "agy", pane_id = "p1", tab_id = "t1", workspace_id = "w1" },
    { agent = "agy", pane_id = "p2", tab_id = "t1", workspace_id = "w1" },
  }
  local pane1, _ = topology.discover_target_pane({ agents = agents, caller_pane_id = "p1", workspace_id = "w1", tab_id = "t1", ignore_herdr_env = true })
  local pane2, _ = topology.discover_target_pane({ agents = agents, caller_pane_id = "", workspace_id = "w1", tab_id = "t1", ignore_herdr_env = true })
  
  if pane1 == "p2" and (pane2 == "p1" or pane2 == "p2") then
    log_result("DISCOVER 2.6: Caller pane exclusion logic works as expected", true)
  else
    log_result("DISCOVER 2.6: Caller pane exclusion logic works as expected", false, "pane1=" .. tostring(pane1) .. ", pane2=" .. tostring(pane2))
  end
end)

run_scenario("DISCOVER 2.7: Tab vs Workspace matching edge case (tab_id set, workspace_id nil)", function()
  local agents = {
    { agent = "agy", pane_id = "p1", tab_id = "t1", workspace_id = "w1" },
    { agent = "agy", pane_id = "p2", tab_id = "t1", workspace_id = "w2" },
  }
  local pane, err = topology.discover_target_pane({ agents = agents, workspace_id = nil, tab_id = "t1", ignore_herdr_env = true })
  if pane ~= nil then
    log_result("DISCOVER 2.7: Tab matching when workspace_id is nil", true)
  else
    log_result("DISCOVER 2.7: Tab matching when workspace_id is nil", false, "Got nil pane")
  end
end)

-- ===================================================================
-- CATEGORY 3: notify.lua Robustness Stress Tests
-- ===================================================================

run_scenario("NOTIFY 3.1: opts.notify is boolean true (opts = { notify = true })", function()
  local ok, err = pcall(function()
    notify.info("Test message", { notify = true })
  end)
  if ok then
    log_result("NOTIFY 3.1: Boolean opts.notify handled without indexing crash", true)
  else
    log_result("NOTIFY 3.1: Boolean opts.notify handled without indexing crash", false, "Crashed: " .. tostring(err))
  end
end)

run_scenario("NOTIFY 3.2: opts is primitive number (opts = 123)", function()
  local ok, err = pcall(function()
    notify.info("Test message", 123)
  end)
  if ok then
    log_result("NOTIFY 3.2: Primitive number opts handled without crash", true)
  else
    log_result("NOTIFY 3.2: Primitive number opts handled without crash", false, "Crashed: " .. tostring(err))
  end
end)

run_scenario("NOTIFY 3.3: opts is primitive boolean true (opts = true)", function()
  local ok, err = pcall(function()
    notify.info("Test message", true)
  end)
  if ok then
    log_result("NOTIFY 3.3: Primitive boolean opts handled without crash", true)
  else
    log_result("NOTIFY 3.3: Primitive boolean opts handled without crash", false, "Crashed: " .. tostring(err))
  end
end)

run_scenario("NOTIFY 3.4: nil msg passed to notify.info(nil)", function()
  local ok, err = pcall(function()
    notify.info(nil, { notify = { enabled = false } })
  end)
  if ok then
    log_result("NOTIFY 3.4: nil msg handled without crash", true)
  else
    log_result("NOTIFY 3.4: nil msg handled without crash", false, "Crashed: " .. tostring(err))
  end
end)

run_scenario("NOTIFY 3.5: Table passed as msg (notify.info({ key = 'val' }))", function()
  local ok, err = pcall(function()
    notify.info({ key = "val" }, { notify = { enabled = false } })
  end)
  if ok then
    log_result("NOTIFY 3.5: Table msg handled without crash", true)
  else
    log_result("NOTIFY 3.5: Table msg handled without crash", false, "Crashed: " .. tostring(err))
  end
end)

run_scenario("NOTIFY 3.6: Unknown log level (level = {})", function()
  local ok, err = pcall(function()
    notify.notify("Test message", {}, { notify = { enabled = false } })
  end)
  if ok then
    log_result("NOTIFY 3.6: Non-standard log level type handled without crash", true)
  else
    log_result("NOTIFY 3.6: Non-standard log level type handled without crash", false, "Crashed: " .. tostring(err))
  end
end)

-- Print Summary
print("\n==========================================================")
print(string.format("STRESS TEST RESULTS: %d Passed, %d Failed", results.passed, results.failed))
print("==========================================================")
for _, f in ipairs(results.details) do
  print(f)
end

if results.failed > 0 then
  vim.cmd("cquit 1")
else
  vim.cmd("qall!")
end
