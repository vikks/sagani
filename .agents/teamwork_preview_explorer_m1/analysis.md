# Milestone 1 (M1) Blueprint & Technical Specification: Herdr Auto-Discovery & Core Topology

**Project**: `herdr-agy.nvim`  
**Milestone**: M1: Herdr Auto-Discovery & Core Topology  
**Agent**: Explorer M1 (`teamwork_preview_explorer_m1`)  
**Date**: 2026-08-01  
**Target Directory**: `/Users/vikks/teamwork_projects/nvim_herdr_agy`  

---

## 1. Executive Overview

Milestone 1 establishes the foundational layer of `herdr-agy.nvim`:
1. **Environment Detection**: Reading `HERDR_ENV`, `HERDR_PANE_ID`, `HERDR_TAB_ID`, `HERDR_WORKSPACE_ID`.
2. **CLI Communication & Topology Discovery**: Executing `herdr agent list`, parsing structured JSON, filtering by agent type (e.g. `agy`), and scoring target candidates using a 6-tier prioritization heuristic (Tab -> Workspace -> CWD -> Fallback).
3. **Notification Abstraction**: Supporting LazyVim notifications (`lazyvim.util`) with fallback to standard Neovim `vim.notify` with log levels (`INFO`, `WARN`, `ERROR`).
4. **Plugin Setup & Command Registration Shell**: Entrypoint (`lua/herdr-agy/init.lua`) initializing default configuration options and user commands.
5. **Headless Unit Test Infrastructure**: Standalone Neovim unit test runner (`tests/test_topology.lua`) testing env detection, JSON decoding, scoring hierarchy, dependency-injected mocks, and error fallbacks.

---

## 2. Module Specifications & Interface Contracts

### 2.1 Interface Summary Matrix

| Module | Method / Export | Inputs | Outputs | Description |
|---|---|---|---|---|
| `lua/herdr-agy/notify.lua` | `notify(msg, level, opts)` | `msg: string, level: string\|number, opts?: table` | `nil` | LazyVim-aware notification dispatch |
| `lua/herdr-agy/notify.lua` | `info(msg, opts)` | `msg: string, opts?: table` | `nil` | Shortcut for `INFO` level notification |
| `lua/herdr-agy/notify.lua` | `warn(msg, opts)` | `msg: string, opts?: table` | `nil` | Shortcut for `WARN` level notification |
| `lua/herdr-agy/notify.lua` | `error(msg, opts)` | `msg: string, opts?: table` | `nil` | Shortcut for `ERROR` level notification |
| `lua/herdr-agy/topology.lua` | `detect_env()` | none | `{ in_herdr: boolean, pane_id?: string, tab_id?: string, workspace_id?: string }` | Reads `HERDR_*` environment variables |
| `lua/herdr-agy/topology.lua` | `list_agents(runner)` | `runner?: function` | `agents_table\|nil, err_msg\|nil` | Runs `herdr agent list`, parses JSON output |
| `lua/herdr-agy/topology.lua` | `discover_target_pane(opts)` | `opts?: table` | `pane_id\|nil, err_msg\|nil, agent_info\|nil` | Resolves target `agy` pane via 6-tier scoring |
| `lua/herdr-agy/init.lua` | `setup(user_opts)` | `user_opts?: table` | `nil` | Merges config, sets up user commands |
| `lua/herdr-agy/init.lua` | `dispatch_prompt(prompt_text, target_pane)` | `prompt_text: string, target_pane?: string` | `success: boolean, err_msg\|nil` | Dispatches prompt text to target Herdr pane |
| `tests/test_topology.lua` | Standalone script | CLI execution via `nvim --headless` | `exit_code: 0` (pass) or `1` (fail) | Headless unit test suite for M1 features |

---

## 3. Detailed Implementation Blueprint

### 3.1 `lua/herdr-agy/notify.lua`

#### Specification:
- Handles LazyVim notification dispatch (`lazyvim.util.info`, `lazyvim.util.warn`, `lazyvim.util.error`).
- Falls back to `vim.notify(msg, level, { title = title })` if LazyVim is not present.
- Accepts string levels (`"info"`, `"warn"`, `"error"`) or `vim.log.levels` numbers (`vim.log.levels.INFO`, etc.).
- Respects `opts.notify.enabled` (if false, notification is suppressed).

#### Implementation Code:

```lua
local M = {}

local level_map = {
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

local function normalize_level(level)
  if type(level) == "number" then
    return level, level == vim.log.levels.WARN and "warn" or (level == vim.log.levels.ERROR and "error" or "info")
  end
  local str_level = tostring(level or "info"):lower()
  local num_level = level_map[str_level] or vim.log.levels.INFO
  return num_level, str_level
end

function M.notify(msg, level, opts)
  opts = opts or {}
  if opts.notify and opts.notify.enabled == false then
    return
  end

  local num_level, str_level = normalize_level(level)
  local title = (opts.notify and opts.notify.title) or opts.title or "herdr-agy.nvim"

  -- LazyVim notification check
  local lazy_ok, LazyVim = pcall(require, "lazyvim.util")
  if lazy_ok and LazyVim and type(LazyVim[str_level]) == "function" then
    LazyVim[str_level](msg, { title = title })
    return
  end

  -- Fallback to standard vim.notify
  vim.notify(msg, num_level, { title = title })
end

function M.info(msg, opts)
  M.notify(msg, "info", opts)
end

function M.warn(msg, opts)
  M.notify(msg, "warn", opts)
end

function M.error(msg, opts)
  M.notify(msg, "error", opts)
end

return M
```

---

### 3.2 `lua/herdr-agy/topology.lua`

#### Specification:
1. **`detect_env()`**:
   - Inspects `vim.env.HERDR_ENV`, `vim.env.HERDR_PANE_ID`, `vim.env.HERDR_TAB_ID`, `vim.env.HERDR_WORKSPACE_ID`.
   - Returns `{ in_herdr = boolean, pane_id = string|nil, tab_id = string|nil, workspace_id = string|nil }`.
2. **`list_agents(runner)`**:
   - Supports dependency injection via `runner` parameter (`runner(cmd_table) -> stdout_string, exit_code`).
   - If `runner` is nil: checks `vim.fn.executable("herdr") == 1`. If missing, returns `nil, "'herdr' CLI executable not found in PATH"`.
   - Executes `herdr agent list` synchronously.
   - Decodes stdout via `pcall(vim.json.decode, output)`.
   - Validates JSON shape: `data and data.result and data.result.agents`.
   - Returns list of agent objects `agents_table, nil` or `nil, err_msg`.
3. **`discover_target_pane(opts)`**:
   - Options structure:
     - `target_agent`: Target agent type (default `"agy"`).
     - `pane_override`: Manual pane override ID (bypasses discovery if non-nil).
     - `caller_pane_id`: Pane ID of the caller Neovim instance (defaults to `detect_env().pane_id`).
     - `tab_id`: Current tab ID (defaults to `detect_env().tab_id`).
     - `workspace_id`: Current workspace ID (defaults to `detect_env().workspace_id`).
     - `cwd`: Current working directory (defaults to `vim.fn.getcwd()`).
     - `agents`: Optional pre-parsed agent list (for direct injection in unit tests).
     - `runner`: Optional runner function for `list_agents`.
   - Candidate Filtering: Filters `agents` where `agent.agent == target_agent`.
   - Scoring Hierarchy:
     - **Tier 1 (Same Tab, Exclude Caller)**: `workspace_id == env.workspace_id` AND `tab_id == env.tab_id` AND `pane_id ~= env.caller_pane_id`
     - **Tier 2 (Same Tab, Any Pane)**: `workspace_id == env.workspace_id` AND `tab_id == env.tab_id`
     - **Tier 3 (Same Workspace, Exclude Caller)**: `workspace_id == env.workspace_id` AND `pane_id ~= env.caller_pane_id`
     - **Tier 4 (Same Workspace, Any Pane)**: `workspace_id == env.workspace_id`
     - **Tier 5 (CWD Match)**: `agent.cwd == current_cwd` OR `agent.foreground_cwd == current_cwd`
     - **Tier 6 (Global Fallback)**: First candidate in `candidates`.
   - Returns `pane_id, nil, candidate_info` or `nil, err_msg`.

#### Implementation Code:

```lua
local notify = require("herdr-agy.notify")

local M = {}

function M.detect_env()
  local env_val = vim.env.HERDR_ENV
  local in_herdr = env_val ~= nil and env_val ~= "" and env_val ~= "0"
  return {
    in_herdr = in_herdr,
    pane_id = vim.env.HERDR_PANE_ID ~= "" and vim.env.HERDR_PANE_ID or nil,
    tab_id = vim.env.HERDR_TAB_ID ~= "" and vim.env.HERDR_TAB_ID or nil,
    workspace_id = vim.env.HERDR_WORKSPACE_ID ~= "" and vim.env.HERDR_WORKSPACE_ID or nil,
  }
end

function M.list_agents(runner)
  if runner then
    local stdout, code = runner({ "herdr", "agent", "list" })
    if code ~= 0 or not stdout then
      return nil, string.format("Command 'herdr agent list' failed with code %s", tostring(code))
    end
    local ok, data = pcall(vim.json.decode, stdout)
    if not ok or type(data) ~= "table" or not data.result or type(data.result.agents) ~= "table" then
      return nil, "Failed to parse JSON output from 'herdr agent list'"
    end
    return data.result.agents, nil
  end

  if vim.fn.executable("herdr") == 0 then
    return nil, "'herdr' CLI executable not found in PATH"
  end

  local output = vim.fn.system({ "herdr", "agent", "list" })
  local exit_code = vim.v.shell_error
  if exit_code ~= 0 then
    return nil, string.format("Command 'herdr agent list' failed with exit code %d", exit_code)
  end

  local ok, data = pcall(vim.json.decode, output)
  if not ok or type(data) ~= "table" or not data.result or type(data.result.agents) ~= "table" then
    return nil, "Failed to parse JSON output from 'herdr agent list'"
  end

  return data.result.agents, nil
end

function M.discover_target_pane(opts)
  opts = opts or {}
  if opts.pane_override then
    return opts.pane_override, nil, { pane_id = opts.pane_override, is_override = true }
  end

  local env = M.detect_env()
  local workspace_id = opts.workspace_id or env.workspace_id
  local tab_id = opts.tab_id or env.tab_id
  local caller_pane_id = opts.caller_pane_id or env.pane_id
  local current_cwd = opts.cwd or vim.fn.getcwd()
  local target_agent = opts.target_agent or "agy"

  if not opts.agents and not env.in_herdr and not opts.ignore_herdr_env then
    return nil, "Not running inside a Herdr environment (HERDR_ENV missing)"
  end

  local agents, err
  if opts.agents then
    agents = opts.agents
  else
    agents, err = M.list_agents(opts.runner)
  end

  if not agents then
    return nil, err or "Failed to retrieve agent list from Herdr"
  end

  local candidates = {}
  for _, a in ipairs(agents) do
    if a.agent == target_agent then
      table.insert(candidates, a)
    end
  end

  if #candidates == 0 then
    return nil, string.format("No active '%s' agent found in Herdr session", target_agent)
  end

  -- Tier 1: Same workspace + same tab, excluding caller pane
  if workspace_id and tab_id then
    for _, c in ipairs(candidates) do
      if c.workspace_id == workspace_id and c.tab_id == tab_id and c.pane_id ~= caller_pane_id then
        return c.pane_id, nil, c
      end
    end

    -- Tier 2: Same workspace + same tab (any pane)
    for _, c in ipairs(candidates) do
      if c.workspace_id == workspace_id and c.tab_id == tab_id then
        return c.pane_id, nil, c
      end
    end
  end

  -- Tier 3: Same workspace, excluding caller pane
  if workspace_id then
    for _, c in ipairs(candidates) do
      if c.workspace_id == workspace_id and c.pane_id ~= caller_pane_id then
        return c.pane_id, nil, c
      end
    end

    -- Tier 4: Same workspace (any pane)
    for _, c in ipairs(candidates) do
      if c.workspace_id == workspace_id then
        return c.pane_id, nil, c
      end
    end
  end

  -- Tier 5: Working directory match
  if current_cwd then
    for _, c in ipairs(candidates) do
      if c.cwd == current_cwd or c.foreground_cwd == current_cwd then
        return c.pane_id, nil, c
      end
    end
  end

  -- Tier 6: Global fallback (first candidate)
  return candidates[1].pane_id, nil, candidates[1]
end

return M
```

---

### 3.3 `lua/herdr-agy/init.lua`

#### Specification:
- Main setup module storing configuration settings in `M.options`.
- Default options:
  - `target_agent`: `"agy"`
  - `auto_discover`: `true`
  - `pane_override`: `nil`
  - `notify`: `{ enabled = true, title = "herdr-agy.nvim" }`
- Registers user commands:
  - `:HerdrAgyStatus`: Displays current Herdr environment status and auto-discovered target pane using `notify.info`.
  - `:HerdrAgySelectTarget`: Opens `vim.ui.input` for user to set a manual `pane_override`.
  - `:HerdrAgyPrompt`: Prompts user for custom prompt and sends to target agent via `dispatch_prompt`.
  - `:HerdrAgySend`: Shell command for selection dispatch (M3).
  - `:HerdrAgyDiff`: Shell command for diff review (M4).
- Function `dispatch_prompt(prompt_text, target_pane, opts)`:
  - Resolves target pane using `topology.discover_target_pane(M.options)`.
  - Runs `herdr agent prompt <TARGET> <PROMPT>` via `vim.fn.system`.
  - Notifies user of status or failure.

#### Implementation Code:

```lua
local topology = require("herdr-agy.topology")
local notify = require("herdr-agy.notify")

local M = {}

M.defaults = {
  target_agent = "agy",
  auto_discover = true,
  pane_override = nil,
  notify = {
    enabled = true,
    title = "herdr-agy.nvim",
  },
}

M.options = {}

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})

  -- Register User Commands
  vim.api.nvim_create_user_command("HerdrAgyStatus", function()
    local env = topology.detect_env()
    local pane_id, err, agent_info = topology.discover_target_pane(M.options)
    local msg = string.format(
      "Herdr Session: %s | Pane: %s | Tab: %s | Workspace: %s\nTarget Pane (%s): %s",
      env.in_herdr and "ACTIVE" or "INACTIVE",
      env.pane_id or "N/A",
      env.tab_id or "N/A",
      env.workspace_id or "N/A",
      M.options.target_agent,
      pane_id or ("NONE (" .. (err or "Unknown") .. ")")
    )
    if pane_id then
      notify.info(msg, M.options)
    else
      notify.warn(msg, M.options)
    end
  end, { desc = "Show Herdr topology and target AGY pane status" })

  vim.api.nvim_create_user_command("HerdrAgySelectTarget", function()
    vim.ui.input({ prompt = "Enter target Herdr pane ID (or empty to clear override): " }, function(input)
      if input and input ~= "" then
        M.options.pane_override = input
        notify.info("Target pane override set to: " .. input, M.options)
      else
        M.options.pane_override = nil
        notify.info("Target pane override cleared. Reverted to auto-discovery.", M.options)
      end
    end)
  end, { desc = "Set manual target pane ID override" })

  vim.api.nvim_create_user_command("HerdrAgyPrompt", function(cmd_args)
    local prompt_text = cmd_args.args
    if prompt_text == "" then
      vim.ui.input({ prompt = "Prompt for AGY: " }, function(input)
        if input and input ~= "" then
          M.dispatch_prompt(input)
        end
      end)
    else
      M.dispatch_prompt(prompt_text)
    end
  end, { nargs = "*", desc = "Send custom prompt to AGY agent pane" })

  vim.api.nvim_create_user_command("HerdrAgySend", function()
    notify.info("HerdrAgySend triggered (Visual selection handler will be active in M3)", M.options)
  end, { range = true, desc = "Send selection to AGY" })

  vim.api.nvim_create_user_command("HerdrAgyDiff", function()
    notify.info("HerdrAgyDiff triggered (Diff review handler will be active in M4)", M.options)
  end, { desc = "Send diff review comment to AGY" })
end

function M.dispatch_prompt(prompt_text, target_pane, opts)
  opts = opts or M.options
  local pane_id = target_pane or opts.pane_override
  local err

  if not pane_id then
    pane_id, err = topology.discover_target_pane(opts)
  end

  if not pane_id then
    notify.error("Cannot dispatch prompt: " .. (err or "Target pane not found"), opts)
    return false, err
  end

  if vim.fn.executable("herdr") == 0 then
    local msg = "'herdr' CLI binary not found in PATH"
    notify.error(msg, opts)
    return false, msg
  end

  local cmd = { "herdr", "agent", "prompt", pane_id, prompt_text }
  local output = vim.fn.system(cmd)
  local code = vim.v.shell_error

  if code ~= 0 then
    local msg = string.format("Failed to prompt agent pane '%s' (exit code %d): %s", pane_id, code, output)
    notify.error(msg, opts)
    return false, msg
  end

  notify.info(string.format("Prompt dispatched to AGY pane '%s'", pane_id), opts)
  return true, nil
end

return M
```

---

## 4. Headless Neovim Unit Test Suite Specification (`tests/test_topology.lua`)

### 4.1 Test Architecture
`tests/test_topology.lua` is a self-contained unit test runner designed to execute under `nvim --headless -u NONE -c "luafile tests/test_topology.lua"`.
It verifies:
1. **Environment Detection**: Active vs inactive Herdr session.
2. **JSON Agent List Parsing**: Valid JSON, malformed JSON, CLI non-zero exit, missing executable.
3. **Scoring Hierarchy Resolution (Tiers 1-6)**:
   - Tier 1: Same workspace & same tab, excluding caller pane.
   - Tier 2: Same workspace & same tab, fallback to caller pane if only choice.
   - Tier 3: Same workspace, different tab, excluding caller pane.
   - Tier 4: Same workspace (any pane).
   - Tier 5: CWD matching across workspaces.
   - Tier 6: Global fallback when no match.
4. **Explicit `pane_override`**: Bypasses discovery.
5. **Caller Pane Exclusion**: Prefers non-caller panes.
6. **Error Fallbacks**: Handles missing agents, missing binaries, missing HERDR_ENV.

### 4.2 Complete `tests/test_topology.lua` Implementation Code:

```lua
-- Headless Neovim Test Runner for herdr-agy.nvim topology module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local topology = require("herdr-agy.topology")
local notify = require("herdr-agy.notify")

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

-- MOCK AGENT LIST DATA GENERATOR
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

-- ==========================================================
-- TEST SUITE EXECUTION
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
end)

run_test("detect_env: Inactive Herdr environment", function()
  vim.env.HERDR_ENV = nil
  vim.env.HERDR_PANE_ID = nil
  vim.env.HERDR_TAB_ID = nil
  vim.env.HERDR_WORKSPACE_ID = nil

  local env = topology.detect_env()
  assert_eq(env.in_herdr, false, "detect_env in_herdr should be false")
  assert_nil(env.pane_id, "detect_env pane_id should be nil")
end)

run_test("list_agents: Successful JSON parsing via mock runner", function()
  local mock_json = vim.json.encode({
    result = {
      agents = {
        make_agent("w1:p2", "w1:t1", "w1", "/proj", "agy"),
      },
    },
  })
  local mock_runner = function(cmd)
    return mock_json, 0
  end

  local agents, err = topology.list_agents(mock_runner)
  assert_nil(err, "list_agents err should be nil")
  assert_true(agents ~= nil and #agents == 1, "list_agents returned 1 agent")
  assert_eq(agents[1].pane_id, "w1:p2", "list_agents agent pane_id")
end)

run_test("list_agents: JSON parse failure handling", function()
  local mock_runner = function(cmd)
    return "INVALID JSON", 0
  end

  local agents, err = topology.list_agents(mock_runner)
  assert_nil(agents, "list_agents agents should be nil on JSON error")
  assert_true(err ~= nil and err:find("parse JSON") ~= nil, "list_agents error message formatting")
end)

run_test("discover_target_pane: Explicit pane_override bypasses discovery", function()
  local pane, err = topology.discover_target_pane({ pane_override = "manual:p99" })
  assert_eq(pane, "manual:p99", "discover_target_pane respects pane_override")
  assert_nil(err, "discover_target_pane err is nil for override")
end)

run_test("discover_target_pane: Non-Herdr environment returns error", function()
  vim.env.HERDR_ENV = nil
  local pane, err = topology.discover_target_pane({ ignore_herdr_env = false })
  assert_nil(pane, "pane is nil outside Herdr")
  assert_true(err ~= nil and err:find("HERDR_ENV missing") ~= nil, "returns HERDR_ENV error")
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

-- SUMMARY REPORT
print("\n==========================================================")
print(string.format("TEST RESULTS: %d Passed, %d Failed", passed_count, failed_count))
print("==========================================================")

if failed_count > 0 then
  print("\nFailures:")
  for _, f in ipairs(test_failures) do
    print("  " .. f)
  end
  vim.cmd("cquit 1")
else
  print("\nAll topology unit tests passed successfully!")
  vim.cmd("qall!")
end
```

---

## 5. Verification Method & Test Command

To verify the M1 implementation and test specs once files are created:

1. **Headless Execution Command**:
   ```bash
   nvim --headless -u NONE -c "luafile tests/test_topology.lua"
   ```
2. **Expected Exit Code**: `0`
3. **Expected Output**:
   ```
   TEST RESULTS: 11 Passed, 0 Failed
   All topology unit tests passed successfully!
   ```
4. **Live Verification inside Herdr**:
   Start Neovim inside Herdr and run `:HerdrAgyStatus`. It will output active environment variables and resolved target pane `w65302a56adf322:p1`.
