# AGENT.md — Development & Maintenance Guide for sagani.nvim

This document serves as the authoritative developer and agent manual for **sagani.nvim** ("Sagani"). It consolidates project architecture, interface contracts, feature inventories, testing guidelines, and workflow protocols for AI agents and human contributors.

---

## 🏛️ 1. Architecture & Design Principles

**sagani.nvim** is a harness-agnostic Lua plugin for Neovim (tailored for [LazyVim](https://www.lazyvim.org/)) that connects Neovim buffer workflows with terminal multiplexers ([`herdr`](https://github.com/herdr/herdr)) and AI coding agent harnesses (`agy`, `codex`, `opencode`, `hermes`, etc.).

### System Architecture Diagram

```
 +-------------------------------------------------------------------------+
 |                                  Neovim                                 |
 |                                                                         |
 |  +--------------------------+          +-----------------------------+  |
 |  | plugins/sagani.lua       |          | lua/sagani/init.lua         |  |
 |  | (LazyVim Plugin Spec &   |--------->| (Plugin Setup & Commands)   |  |
 |  |  WhichKey Configuration) |          +--------------+--------------+  |
 |  +--------------------------+                         |                 |
 |                                                       v                 |
 |  +----------------------+  +--------------------+  +-----------------+  |
 |  | selection.lua        |  | diff.lua           |  | topology.lua    |  |
 |  | (Visual selection &  |  | (Diffview/Split    |  | (Herdr env &    |  |
 |  |  context dispatch)   |  |  hunk commenting)  |  |  pane auto-     |  |
 |  +----------+-----------+  +---------+----------+  |  discovery)     |  |
 |             |                        |             +--------+--------+  |
 |             v                        v                      |           |
 |       +-----+------------------------+------+               |           |
 |       | format.lua                          |               |           |
 |       | (Markdown prompt & diff block format)|               |           |
 |       +------------------+------------------+               |           |
 |                          |                                  |           |
 |                          v                                  v           |
 |       +------------------+--------------------------------------+       |
 |       | notify.lua (LazyVim-aware notifications & fallback)      |       |
 |       +------------------+--------------------------------------+       |
 +--------------------------|----------------------------------------------+
                            | (vim.system process execution)
                            v
               +--------------------------+
               | herdr agent prompt       |
               | --pane <target> "<msg>"  |
               +------------+-------------+
                            |
                            v
               +--------------------------+
               | Target agent harness     |
               | in adjacent herdr pane   |
               +--------------------------+
```

---

## ⚡ 2. Feature Inventory

| # | Feature | Description | Primary Module | Source |
|---|---------|-------------|----------------|--------|
| 1 | **F1: Herdr Env Detection** | Detect `HERDR_ENV`, `HERDR_PANE_ID`, `HERDR_TAB_ID`, `HERDR_WORKSPACE_ID`, handle missing `herdr` binary gracefully | `lua/sagani/topology.lua` | R4 |
| 2 | **F2: Topology Auto-Discovery** | Query `herdr agent list` / `herdr pane list`, parse JSON, resolve target agent pane via Tab → Workspace → CWD → Fallback (`wait_for_agent_ready`, `spawn_agent_pane`) | `lua/sagani/topology.lua` | R4 |
| 3 | **F3: LazyVim Plugin Spec** | Standard plugin specification under `plugins/sagani.lua` with single-line `{ "vikks/sagani.nvim", opts = {} }` integration | `plugins/sagani.lua` | R1 |
| 4 | **F4: WhichKey Integration** | Automatic WhichKey menu group `"Sagani"` and keymap bindings (`<leader>as`, `<leader>ac`, `<leader>ad`, `<leader>ap`, `<leader>an`, `<leader>aa`) | `lua/sagani/init.lua` | R1 |
| 5 | **F5: Visual Selection Extraction** | Robust extraction of visual selection handling characterwise (`v`), linewise (`V`), and blockwise (`<C-v>`) with mark normalization | `lua/sagani/selection.lua` | R2 |
| 6 | **F6: Context Dispatch to Agent** | Format selection context (file path, line range, filetype, snippet) with user input (`vim.ui.input`), dispatch via `vim.system` | `lua/sagani/selection.lua` | R2 |
| 7 | **F7: Interactive Diff Review** | Integration with `diffview.nvim` and Neovim split diffs (`vim.wo.diff`), calculate hunks via `vim.diff()`, capture range comments | `lua/sagani/diff.lua` | R3 |
| 8 | **F8: Structured Diff Formatting** | Format diff feedback as markdown diff blocks (````diff ````) with file path, line range, and user commentary sent to agent | `lua/sagani/format.lua` | R3 |
| 9 | **F9: Automated Testing Suite** | Headless Neovim test runner (`tests/run_tests.lua`) and Plenary test harness (`tests/minimal_init.lua`) covering all `sagani` modules | `tests/` | Acceptance Criteria |
| 10 | **F10: Harness-Agnostic Agent Selection** | Dynamic agent harness switching (`:SaganiSelectAgent`, `:SaganiSelectHarness`, `<leader>aa`, `<leader>ah`) supporting `agy`, `codex`, `opencode`, `hermes`, etc. | `lua/sagani/init.lua` | User Request |

---

## 🔌 3. Interface Contracts & API Reference

### `lua/sagani/init.lua`
- `init.setup(user_opts)`: Initializes default options, registers user commands (`:SaganiStatus`, `:SaganiSend`, `:SaganiContext`, `:SaganiDiff`, `:SaganiPrompt`, `:SaganiSpawnPane`, `:SaganiSelectAgent`, `:SaganiSelectHarness`), binds default keymaps, and registers WhichKey group.
- `init.select_agent_harness(arg, opts)`: Switches target agent harness (`agy`, `codex`, `opencode`, `hermes`, etc.) interactively or via argument.
- `init.dispatch_prompt(prompt_text, target_pane, opts)`: Dispatches prompt text to target Herdr agent pane via `herdr agent prompt`. Contains safety guard `_G.RUNNING_TEST_SUITE` to prevent live shell execution during test runs.

### `lua/sagani/topology.lua`
- `topology.detect_env(runner)`: Returns `{ in_herdr = boolean, pane_id = string|nil, tab_id = string|nil, workspace_id = string|nil, cwd = string|nil }`.
- `topology.list_agents(runner)`: Queries `herdr agent list` and returns table of agents or error.
- `topology.discover_target_pane(opts)`: Auto-discovers target agent pane using Tier 1-8 fallback hierarchy (Override → Tab → Workspace → CWD → Auto-Spawn → Global).
- `topology.wait_for_agent_ready(pane_id, timeout_ms, opts)`: Waits for target agent CLI to authenticate and render interactive ready prompt.
- `topology.spawn_agent_pane(opts)`: Splits current Herdr pane and initializes new target agent pane.

### `lua/sagani/selection.lua`
- `selection.get_visual_selection(bufnr)`: Returns `{ snippet, start_line, end_line, start_col, end_col, mode, file_path, filetype }`.
- `selection.send_selection_prompt(opts)`: Prompts user for instruction, formats visual selection, and dispatches to agent.
- `selection.send_code_context(opts)`: Dispatches visual selection context directly to agent with default review prompt.

### `lua/sagani/diff.lua`
- `diff.get_diff_hunk_at_cursor()`: Extracts current diff hunk context (`file_path`, `start_line`, `end_line`, `diff_text`).
- `diff.send_diff_comment(opts)`: Captures diff review comment and dispatches formatted diff block to agent.

### `lua/sagani/format.lua`
- `format.build_context_prompt(user_instruction, selection)`: Constructs Markdown code context prompt string.
- `format.build_diff_prompt(user_comment, diff_info)`: Constructs Markdown diff block prompt string.

### `lua/sagani/notify.lua`
- `notify.info(msg, opts)`: Displays info notification via `vim.notify` or fallback.
- `notify.warn(msg, opts)`: Displays warning notification.
- `notify.error(msg, opts)`: Displays error notification.

---

## 🧪 4. Testing & Verification Protocol

All code changes **must** be verified using the headless test suite before completion.

### Verification Command
```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```

### Test Suite Structure
- `tests/run_tests.lua`: Zero-dependency master headless test runner.
- `tests/minimal_init.lua`: Plenary Busted test harness launcher.
- `tests/test_topology.lua`: Topology discovery, environment detection, agent listing, and pane auto-spawning tests.
- `tests/test_selection.lua`: Visual selection extraction (v, V, `<C-v>`) and prompt dispatch tests.
- `tests/test_diff.lua`: Diff hunk extraction and review comment formatting tests.
- `tests/test_format.lua`: Markdown code block and diff block builder tests.
- `tests/test_plugin_spec.lua`: Minimal setup, options merging, command registration, and WhichKey integration tests.
- `tests/test_adversarial_m2.lua`: Cross-module integration and stress recovery tests.
- `tests/test_challenger_stress.lua`: Boundary condition and stress suite tests.

### Test Isolation Guard Rule
When adding or modifying `dispatch_prompt` or shell execution code, ensure `_G.RUNNING_TEST_SUITE` checks bypass unmocked external `herdr` shell execution so running test suites never dispatches live messages to an active agent conversation.

---

## ⚙️ 5. Directory & File Organization

```
sagani.nvim/
├── AGENT.md                 # Permanent Developer & Agent Manual
├── README.md                # Public Plugin Documentation & Installation Guide
├── LICENSE                  # MIT License
├── .gitignore               # Ignores .agents/ local agent workspace logs
├── plugins/
│   └── sagani.lua           # LazyVim specification
├── lua/
│   └── sagani/
│       ├── init.lua         # Plugin setup, commands, keymaps, dispatch
│       ├── topology.lua     # Herdr topology discovery & pane spawning
│       ├── selection.lua    # Visual selection extraction
│       ├── diff.lua         # Diff hunk & review comment extraction
│       ├── format.lua       # Markdown prompt formatting helpers
│       └── notify.lua       # Notification handler
└── tests/
    ├── run_tests.lua        # Master headless test runner
    ├── minimal_init.lua     # Plenary test runner
    ├── test_topology.lua    # Topology unit tests
    ├── test_selection.lua   # Selection unit tests
    ├── test_diff.lua        # Diff unit tests
    ├── test_format.lua      # Formatting unit tests
    ├── test_plugin_spec.lua # Spec & setup unit tests
    ├── test_adversarial_m2.lua
    └── test_challenger_stress.lua
```

---

## 🤖 6. Rules for Future Agent Developers

1. **Incremental Edits & Testing**: Run `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` after every code modification. Never declare success without 100% test pass rate.
2. **Preserve Compatibility**: Keep the single-line installation spec (`{ "vikks/sagani.nvim", opts = {} }`) fully functional by ensuring `require("sagani").setup(opts)` handles default keymap and WhichKey registration out of the box.
3. **No Unneeded File Churn**: Do not commit local `.agents/` workspace logs to git. Keep `.gitignore` updated.
