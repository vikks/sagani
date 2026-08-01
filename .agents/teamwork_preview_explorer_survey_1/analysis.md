# Technical Analysis: Requirements R1 & R4 for `herdr-agy.nvim`

**Agent**: Explorer 1  
**Project**: `herdr-agy.nvim`  
**Date**: 2026-08-01  
**Target Directory**: `/Users/vikks/teamwork_projects/nvim_herdr_agy`  
**Agent Directory**: `/Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_explorer_survey_1`

---

## 1. Executive Summary

This report provides a comprehensive technical analysis for requirements **R1** (LazyVim Plugin Specification & Configuration) and **R4** (Herdr Environment & Topology Auto-Discovery) for `herdr-agy.nvim`. 

`herdr-agy.nvim` is a Neovim plugin designed for LazyVim users that integrates Neovim with the `herdr` terminal workspace manager and the `antigravity-cli` (`agy`) AI agent. It allows developers to seamlessly inspect topology, auto-discover right-side `agy` panes, dispatch code selections/context, and submit diff reviews directly from Neovim.

---

## 2. Catalog of Existing Repository & System Environment

### 2.1 Repository Setup
- **Workspace Root**: `/Users/vikks/teamwork_projects/nvim_herdr_agy`
- **Current Repository State**: Greenfield repository.
- **Existing Files**:
  - `ORIGINAL_REQUEST.md`: Specification containing initial requirements (R1–R4) and acceptance criteria.
  - `.agents/`: Metadata directory for agent communications (`DISPATCH.md`, `BRIEFING.md`, `analysis.md`, `handoff.md`).

### 2.2 System & Runtime Environment
- **Neovim Version**: `NVIM v0.12.3` (LuaJIT 2.1.1781602682)
- **CLI Executables Available**:
  - `/opt/homebrew/bin/herdr`
  - `/Users/vikks/.local/bin/agy`
  - `/opt/homebrew/bin/nvim`
- **Live Herdr Session**: `HERDR_ENV=1`, `HERDR_SOCKET_PATH=/Users/vikks/.config/herdr/herdr.sock`

---

## 3. Requirement R1 Analysis: LazyVim Plugin Specification & Configuration

### 3.1 Plugin Spec Architecture & File Layout
LazyVim plugin specifications follow a standard declarative structure. A single-file LazyVim spec under `plugins/herdr-agy.lua` (or imported via `lua/plugins/herdr-agy.lua`) allows LazyVim to manage installation, lazy loading, keybindings, and options.

#### Recommended Directory Layout for `herdr-agy.nvim`:
```
herdr-agy.nvim/
├── plugins/
│   └── herdr-agy.lua         -- LazyVim plugin specification entrypoint
├── lua/
│   └── herdr-agy/
│       ├── init.lua          -- Main module interface (setup, user commands)
│       ├── config.lua        -- Default options, deep extend merging
│       ├── topology.lua      -- Herdr environment detection & agent discovery (R4)
│       ├── dispatch.lua      -- Selection & context prompt generator (R2)
│       ├── diff.lua          -- Diff view integration & markdown diff feedback (R3)
│       └── notify.lua        -- Notification wrapper (LazyVim / vim.notify fallback)
└── tests/
    └── test_topology.lua     -- Headless unit tests for auto-discovery
```

### 3.2 LazyVim Plugin Spec Definition (`plugins/herdr-agy.lua`)
The LazyVim plugin spec must return a table containing:
1. **Plugin Definition**: Specifies plugin module name, `opts`, `config`, `keys`, and `cmd`.
2. **WhichKey Specification Extension**: Automatically registers the `<leader>a` prefix under WhichKey.

```lua
return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, {
        { "<leader>a", group = "AGY / Herdr", icon = "🤖", mode = { "n", "v" } },
      })
    end,
  },
  {
    "herdr-agy.nvim",
    dir = vim.fn.stdpath("config") .. "/lua/plugins/herdr-agy.nvim", -- or local plugin path
    lazy = true,
    cmd = {
      "HerdrAgySend",
      "HerdrAgyPrompt",
      "HerdrAgyDiff",
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
    },
    keys = {
      { "<leader>as", "<cmd>HerdrAgySend<cr>", mode = { "n", "v" }, desc = "Send Selection/Context to AGY" },
      { "<leader>ac", "<cmd>HerdrAgyPrompt<cr>", mode = { "n", "v" }, desc = "Custom Prompt to AGY" },
      { "<leader>ad", "<cmd>HerdrAgyDiff<cr>", mode = { "n" }, desc = "Diff Review to AGY" },
      { "<leader>ap", "<cmd>HerdrAgyStatus<cr>", mode = { "n" }, desc = "Herdr Pane / Topology Status" },
      { "<leader>at", "<cmd>HerdrAgySelectTarget<cr>", mode = { "n" }, desc = "Select Target Herdr Pane" },
    },
    opts = {
      target_agent = "agy",
      auto_discover = true,
      default_timeout_ms = 5000,
      notify = { enabled = true, title = "herdr-agy.nvim" },
    },
    config = function(_, opts)
      require("herdr-agy").setup(opts)
    end,
  },
}
```

### 3.3 WhichKey Integration Mechanics
- **WhichKey v3**: Uses `which-key.add({ { "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } } })`.
- In standard LazyVim, `folke/which-key.nvim` merges `opts.spec`.
- To support non-LazyVim setups or dynamic WhichKey loading, `herdr-agy.setup()` will check `pcall(require, "which-key")` and register the group dynamically if WhichKey is present.

### 3.4 Configuration Options Schema (`lua/herdr-agy/config.lua`)
```lua
local M = {}

M.defaults = {
  target_agent = "agy",
  auto_discover = true,
  pane_override = nil, -- string pane_id or nil
  notify = {
    enabled = true,
    title = "herdr-agy.nvim",
  },
  keymaps = {
    send_selection = "<leader>as",
    custom_prompt = "<leader>ac",
    diff_review = "<leader>ad",
    pane_status = "<leader>ap",
    select_target = "<leader>at",
  },
}

M.options = {}

function M.setup(user_opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
```

---

## 4. Requirement R4 Analysis: Herdr Environment & Topology Auto-Discovery

### 4.1 Herdr Environment Variables
When running inside a Herdr terminal pane, Herdr exposes the following environment variables:
- `HERDR_ENV`: `1` (indicates active Herdr session)
- `HERDR_PANE_ID`: Current pane identifier (e.g. `w65302a56adf322:p1`)
- `HERDR_TAB_ID`: Current tab identifier (e.g. `w65302a56adf322:t1`)
- `HERDR_WORKSPACE_ID`: Current workspace identifier (e.g. `w65302a56adf322`)
- `HERDR_SOCKET_PATH`: Path to IPC UNIX socket (`/Users/vikks/.config/herdr/herdr.sock`)

### 4.2 Querying Herdr Topology (`herdr agent list` / `herdr pane list`)
`herdr agent list` outputs structured JSON over stdout:
```json
{
  "id": "cli:agent:list",
  "result": {
    "agents": [
      {
        "agent": "agy",
        "agent_status": "idle",
        "cwd": "/Users/vikks/CreatorSpace/Configs/Mac.Configs",
        "focused": true,
        "foreground_cwd": "/Users/vikks/CreatorSpace/Configs/Mac.Configs",
        "pane_id": "w65302a56adf322:p1",
        "revision": 96,
        "state_change_seq": 98,
        "tab_id": "w65302a56adf322:t1",
        "terminal_id": "term_657ea5c61c27d5",
        "terminal_title": "agy",
        "terminal_title_stripped": "agy",
        "workspace_id": "w65302a56adf322"
      }
    ]
  },
  "type": "agent_list"
}
```

Similarly, `herdr pane list` lists all panes with additional attributes like `scroll` state and `label`.

### 4.3 Target Discovery Algorithm
The discovery algorithm resolves the target `agy` pane ID via a multi-tiered priority heuristic:

1. **Explicit Override Check**:
   If `options.pane_override` is set, return it directly.
2. **Environment Pre-flight Check**:
   If `vim.env.HERDR_ENV` is not set or empty, flag non-Herdr environment.
3. **Execute & Parse CLI**:
   Run `herdr agent list` via `vim.fn.system({"herdr", "agent", "list"})`. Parse JSON with `pcall(vim.json.decode, output)`.
4. **Candidate Filtering**:
   Filter all returned agents where `agent == target_agent` (default `"agy"`).
5. **Multi-tier Scoring Hierarchy**:
   - **Tier 1 (Exact Tab Match)**: `workspace_id == HERDR_WORKSPACE_ID` AND `tab_id == HERDR_TAB_ID` AND `pane_id ~= HERDR_PANE_ID`.
   - **Tier 2 (Same Tab, Any Pane)**: `workspace_id == HERDR_WORKSPACE_ID` AND `tab_id == HERDR_TAB_ID`.
   - **Tier 3 (Same Workspace Match)**: `workspace_id == HERDR_WORKSPACE_ID` AND `pane_id ~= HERDR_PANE_ID`.
   - **Tier 4 (Same Workspace, Any Pane)**: `workspace_id == HERDR_WORKSPACE_ID`.
   - **Tier 5 (Working Directory Match)**: `cwd == vim.fn.getcwd()`.
   - **Tier 6 (Global Fallback)**: First candidate in `candidates`.

```lua
-- Candidate selection logic
function M.find_target_pane(opts)
  opts = opts or require("herdr-agy.config").options
  if opts.pane_override then
    return opts.pane_override, nil
  end

  if not vim.env.HERDR_ENV then
    return nil, "Not running inside a Herdr environment (HERDR_ENV missing)"
  end

  if vim.fn.executable("herdr") == 0 then
    return nil, "'herdr' CLI executable not found in PATH"
  end

  local out = vim.fn.system({ "herdr", "agent", "list" })
  local ok, data = pcall(vim.json.decode, out)
  if not ok or not data or not data.result or not data.result.agents then
    return nil, "Failed to parse JSON output from 'herdr agent list'"
  end

  local target_agent = opts.target_agent or "agy"
  local workspace_id = vim.env.HERDR_WORKSPACE_ID
  local tab_id = vim.env.HERDR_TAB_ID
  local caller_pane_id = vim.env.HERDR_PANE_ID

  local candidates = {}
  for _, info in ipairs(data.result.agents) do
    if info.agent == target_agent then
      table.insert(candidates, info)
    end
  end

  if #candidates == 0 then
    return nil, string.format("No active '%s' agent found in Herdr session", target_agent)
  end

  -- Tier 1: Same workspace & same tab, excluding caller pane
  for _, c in ipairs(candidates) do
    if c.workspace_id == workspace_id and c.tab_id == tab_id and c.pane_id ~= caller_pane_id then
      return c.pane_id, nil, c
    end
  end

  -- Tier 2: Same workspace & same tab
  for _, c in ipairs(candidates) do
    if c.workspace_id == workspace_id and c.tab_id == tab_id then
      return c.pane_id, nil, c
    end
  end

  -- Tier 3: Same workspace
  for _, c in ipairs(candidates) do
    if c.workspace_id == workspace_id then
      return c.pane_id, nil, c
    end
  end

  -- Tier 4: Global fallback
  return candidates[1].pane_id, nil, candidates[1]
end
```

### 4.4 Notification & Fallback Architecture (`lua/herdr-agy/notify.lua`)
To ensure clean integration with LazyVim standard UI notifications:
- Attempts to use `LazyVim.info`, `LazyVim.warn`, `LazyVim.error` if available.
- Fallback to standard `vim.notify(msg, level, { title = "herdr-agy.nvim" })`.

```lua
local M = {}

function M.notify(msg, level_name, opts)
  local level = vim.log.levels[level_name:upper()] or vim.log.levels.INFO
  local title = (opts and opts.title) or "herdr-agy.nvim"

  local lazy_ok, LazyVim = pcall(require, "lazyvim.util")
  if lazy_ok and LazyVim and LazyVim[level_name:lower()] then
    LazyVim[level_name:lower()](msg, { title = title })
    return
  end

  vim.notify(msg, level, { title = title })
end

return M
```

---

## 5. Technical Dependencies & API Reference

| Component | Dependency / API | Description |
|---|---|---|
| **Neovim Core API** | `vim.fn.system()` / `vim.system()` | Synchronous/asynchronous CLI command execution |
| **JSON Parser** | `vim.json.decode()` | Native JSON decoding (Neovim 0.8+) |
| **Notification** | `vim.notify()` / `lazyvim.util` | Status and error notifications |
| **Keymap Engine** | `vim.keymap.set()` | Registering normal and visual mode keymaps |
| **WhichKey API** | `which-key.nvim` v3 (`opts.spec` or `wk.add`) | Registration of `<leader>a` menu group |
| **Herdr CLI** | `herdr agent list`, `herdr pane list`, `herdr agent prompt <TARGET> <TEXT>` | Herdr IPC communication CLI |

---

## 6. Technical Edge Cases & Risk Mitigation Matrix

| Category | Edge Case | Symptom / Risk | Mitigation Strategy |
|---|---|---|---|
| **Environment** | `HERDR_ENV` missing | Plugin invoked outside Herdr session | Gracefully abort action with `WARN` notification; do not error or crash. |
| **Environment** | `herdr` binary missing | `executable("herdr") == 0` | Fail fast with `ERROR` notification prompting user to install `herdr`. |
| **IPC / CLI** | `herdr agent list` fails or times out | JSON decoding error or non-zero exit | Wrap `vim.json.decode` in `pcall`; report formatted error notification. |
| **Topology** | No `agy` agent running in Herdr | Candidate list empty | Notify `WARN` ("No 'agy' agent found"); provide command `:HerdrAgySelectTarget` for manual target pane entry. |
| **Topology** | Multiple `agy` agents in same tab | Ambiguous target | Apply multi-tiered scoring (prefer right/adjacent pane, not caller pane). |
| **WhichKey** | WhichKey plugin not loaded or older version | Group registration failure | Use optional Lazy spec dependency + fallback `pcall(require, "which-key")`. |
| **Lazy Loading** | Lazy-loading keymaps fail to load module | Command not found | Define `keys` and `cmd` cleanly in Lazy spec so Lazy.nvim auto-loads module before command execution. |

---

## 7. Verification & Testing Strategy

1. **Headless Unit Tests**:
   - Write test scripts in `tests/test_topology.lua` executed via `nvim --headless -u NONE -l tests/test_topology.lua`.
   - Test JSON parsing, candidate filtering, tier scoring, and error handling.
2. **Mocking Herdr Output**:
   - Test topology discovery with mocked `herdr agent list` JSON outputs covering single agent, multiple agents, no agents, and invalid JSON.
3. **Live Environment Validation**:
   - Execute discovery in live Herdr session (`HERDR_ENV=1`) verifying auto-resolution of target pane `w65302a56adf322:p1`.

---

## 8. Summary & Handoff Readiness

Requirements **R1** and **R4** are thoroughly analyzed and documented. The design provides a seamless LazyVim specification, robust topology auto-discovery, WhichKey integration, and graceful notification fallbacks. All edge cases have actionable mitigation strategies.
