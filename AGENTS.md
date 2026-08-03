# AGENTS.md — Development & Maintenance Guide for sagani.nvim

This document serves as the authoritative developer and agent manual for **sagani.nvim** ("Sagani"). It consolidates project architecture, interface contracts, feature inventories, testing guidelines, and workflow protocols for AI agents and human contributors.

---

## 🏛️ 1. Architecture & Design Principles

**sagani.nvim** is a harness-agnostic Lua plugin for Neovim (tailored for [LazyVim](https://www.lazyvim.org/)) that connects Neovim buffer workflows with AI coding agent harnesses (`agy`, `codex`, `opencode`, `hermes`, etc.) across multiple terminal multiplexers.

### Three-Layer Decoupled Architecture

The plugin is being deliberately decoupled into three independent layers:

| Layer | Responsibility | Key Modules |
|-------|----------------|-------------|
| **Neovim Layer** | Visual selections, diff review, prompt formatting, user commands, keymaps | `init.lua`, `selection.lua`, `diff.lua`, `format.lua`, `notify.lua` |
| **Backend Registry** | Multiplexer detection, routing, and adapter resolution | `backend.lua`, `backend/herdr.lua`, `backend/native.lua`, `backend/tmux.lua`, `backend/zellij.lua` |
| **Transport / IPC Layer** | CLI subprocess communication (`vim.system`) | `backend/herdr/topology.lua` |

> **Status**: Decoupling complete. The Neovim layer routes all dispatch through `backend.get_backend(opts)` → adapter contract. Herdr topology discovery resides in `lua/sagani/backend/herdr/topology.lua`.

### System Architecture Diagram

```
 +-----------------------------------------------------------------------------------+
 |                                    Neovim Layer                                   |
 |                                                                                   |
 |  +--------------------------+          +--------------------------------+          |
 |  | plugins/sagani.lua       |          | lua/sagani/init.lua            |          |
 |  | (LazyVim Plugin Spec &   |--------->| (Setup, Commands, Keymaps,     |          |
 |  |  WhichKey Configuration) |          |  dispatch_prompt entry point)  |          |
 |  +--------------------------+          +----------------+---------------+          |
 |                                                         |                         |
 |        +-------------------+   +------------------+    |    +------------------+ |
 |        | selection.lua     |   | diff.lua         |    |    | format.lua       | |
 |        | (Visual selection |   | (Diff hunk       |<---+    | (Markdown prompt | |
 |        |  extraction)      |   |  review/accept/  |         |  & diff builder) | |
 |        +--+----------------+   |  reject)         |         +------------------+ |
 |           |                    +------------------+                               |
 |           |         +----------------------------------------------+             |
 |           +-------->| notify.lua (LazyVim-aware notifications)      |             |
 |                     +----------------------------------------------+             |
 +-----------------------------------------------------------------------------------+
                                         |
                          dispatch_prompt / spawn_popup
                                         |
                                         v
 +-----------------------------------------------------------------------------------+
 |                               Backend Registry Layer                               |
 |                                                                                   |
 |   +-------------------------------+  backend.get_backend(opts) auto-detects:      |
 |   | backend.lua                   |  Herdr -> Tmux -> Zellij -> Native            |
 |   | (Registry & auto-detection)   |                                               |
 |   +-------+-------+-------+-------+                                               |
 |           |       |       |       |                                               |
 |           v       v       v       v                                               |
 |  +--------+  +----+--+ +-+-----+ +-------+   Each adapter implements:            |
 |  |backend/|  |backend| |backend| |backend|   - detect_env(runner)                |
 |  |herdr   |  |tmux   | |zellij | |native |   - discover_target(opts)             |
 |  +---+----+  +---+---+ +--+----+ +--+----+   - spawn_pane(opts)                 |
 |      |           |        |         |         - spawn_popup(opts)                |
 +------|-----------|--------|---------|------------------------------------------+
        |           |        |         |           - prompt_target(id, text, opts)
        v           v        v         v
 +-----------------------------------------------------------------------------------+
 |                          Transport / Multiplexer Layer                             |
 |                                                                                   |
 |  +-------------------+  +--------+  +---------------+                            |
 |  | topology.lua      |  | tmux   |  | zellij action |                            |
 |  | (Herdr CLI:       |  | CLI    |  | CLI           |                            |
 |  |  pane/agent cmds, |  | cmds   |  | cmds          |                            |
 |  |  env detection,   |  +--------+  +---------------+                            |
 |  |  topology)        |                                                            |
 |  +-------------------+                                                            |
 +-----------------------------------------------------------------------------------+
                                |
                      Subshell Process Execution
                           (vim.system)
```

### Backend Adapter Contract

Every backend adapter **must** implement the following interface:

```lua
{
  name = "backend_name",              -- string identifier

  detect_env(runner)                  -- returns { active=bool, id=string|nil, metadata=table }
  discover_target(opts)               -- returns pane_id, err, metadata
  spawn_pane(opts)                    -- returns pane_id, err, metadata
  spawn_popup(opts)                   -- returns agent_target, err, metadata
                                      -- (for Herdr: agent_target is the agent name used by `herdr agent prompt`)
  prompt_target(id, text, opts)       -- returns ok (bool), err
}
```

---

## ⚡ 2. Feature Inventory

| # | Feature | Description | Primary Module | Status |
|---|---------|-------------|----------------|--------|
| 1 | **F1: Herdr Env Detection** | Detect `HERDR_ENV`, `HERDR_PANE_ID`, `HERDR_TAB_ID`, `HERDR_WORKSPACE_ID`, handle missing `herdr` binary gracefully | `lua/sagani/backend/herdr/topology.lua` | ✅ Done |
| 2 | **F2: Topology Auto-Discovery** | Query `herdr agent list` / `herdr pane list`, parse JSON, resolve target agent pane via Tab → Workspace → CWD → Fallback | `lua/sagani/backend/herdr/topology.lua` | ✅ Done |
| 3 | **F3: LazyVim Plugin Spec** | Standard plugin spec under `plugins/sagani.lua` with `config = function(_, opts) require("sagani").setup(opts) end` — all init owned by the lazy.nvim spec, no `plugin/` auto-init needed | `plugins/sagani.lua` | ✅ Done |
| 4 | **F4: WhichKey Integration** | Automatic WhichKey menu group `"Sagani"` (`<leader>a`) and all keymap bindings | `lua/sagani/init.lua` | ✅ Done |
| 5 | **F5: Visual Selection Extraction** | Robust extraction handling characterwise (`v`), linewise (`V`), and blockwise (`<C-v>`) with mark normalization | `lua/sagani/selection.lua` | ✅ Done |
| 6 | **F6: Context Dispatch to Agent** | Format selection context (file path, line range, filetype, snippet) with user input (`vim.ui.input`), dispatch via backend | `lua/sagani/selection.lua` | ✅ Done |
| 7 | **F7: Interactive Diff Review** | Integration with `diffview.nvim` and Neovim split diffs (`vim.wo.diff`), calculate hunks via `vim.diff()`, capture range comments | `lua/sagani/diff.lua` | ✅ Done |
| 8 | **F8: Structured Diff Formatting** | Format diff feedback as markdown diff blocks with file path, line range, and user commentary sent to agent | `lua/sagani/format.lua` | ✅ Done |
| 9 | **F9: Automated Testing Suite** | Headless Neovim test runner (`tests/run_tests.lua`) and Plenary test harness (`tests/minimal_init.lua`) | `tests/` | ✅ Done |
| 10 | **F10: Harness-Agnostic Agent Selection** | Dynamic agent harness switching (`:SaganiSelectAgent`, `:SaganiSelectHarness`, `<leader>ah`) supporting `agy`, `codex`, `opencode`, `hermes`, etc. | `lua/sagani/init.lua` | ✅ Done |
| 11 | **F11: Agent Edit Review & Accept/Reject** | Interactive edit review (`:SaganiReview`, `<leader>ar`), hunk navigation, change acceptance (`:SaganiAccept`) or rejection (`:SaganiReject`) | `lua/sagani/diff.lua` | ✅ Done |
| 12 | **F12: Ask General Agent in Popup** | Asks general questions to agent in a popup pane (`:SaganiAskAgent`, `<leader>aa`), using configurable or session-cached target agent, routed via active backend | `lua/sagani/init.lua` | ✅ Done |
| 13 | **F13: Pluggable Backend Registry** | Decoupled multiplexer backend architecture with `backend.register(name, adapter)` and `backend.get_backend(opts)` auto-detection (Herdr → Tmux → Zellij → Native) | `lua/sagani/backend.lua` | ✅ Done |
| 14 | **F14: Herdr CLI Backend Adapter** | Pure CLI Herdr adapter — `herdr pane split --direction right` to create a new agent pane, `herdr agent start --timeout <sec>` to wait for agent readiness (eliminates race conditions), `herdr agent prompt <name>` to dispatch prompts | `lua/sagani/backend/herdr.lua` | ✅ Done |
| 17 | **F17: Native Neovim Backend** | Pure Neovim float/split adapter — no external multiplexer required, runs agent via `vim.fn.termopen` | `lua/sagani/backend/native.lua` | ✅ Done |
| 18 | **F18: Tmux Backend Adapter** | `tmux split-window` / `tmux display-popup` / `tmux send-keys` transport adapter | `lua/sagani/backend/tmux.lua` | ✅ Done |
| 19 | **F19: Zellij Backend Adapter** | `zellij action new-pane` / `zellij action write-chars` transport adapter | `lua/sagani/backend/zellij.lua` | ✅ Done |
| 20 | **F20: Hot Module Reload** | `:SaganiReload` flushes all `sagani.*` from `package.loaded` and re-initializes with saved options | `lua/sagani/init.lua` | ✅ Done |
| — | **Transport Abstraction Layer** | Generic `transport/` interface to unify socket, CLI, HTTP, JSON-RPC behind a single contract | _planned_ | 🔲 Planned |
| — | **Agent Protocol Adapters** | Per-harness protocol adapters to separate "how to talk to agy/codex" from "where to send it" | _planned_ | 🔲 Planned |

---

## 🔌 3. Interface Contracts & API Reference

### `lua/sagani/init.lua`
- `init.setup(user_opts)`: Initializes default options, registers all user commands, binds default keymaps, and registers WhichKey group. Routes all dispatch through `backend.get_backend(opts)` rather than calling topology or herdr directly. **Called exclusively via the `config` function in `plugins/sagani.lua`** — there is no `plugin/` auto-init.
- `init.dispatch_prompt(prompt_text, target_pane, opts)`: Main dispatch entry point. Calls `adapter.discover_target(opts)` if no pane given, then `adapter.prompt_target(pane_id, text, opts)`. Pre-captures diff baseline snapshot. Contains safety guard `_G.RUNNING_TEST_SUITE`.
- `init.ask_agent_prompt(prompt_text, opts)`: Spawns a popup via `adapter.spawn_popup(popup_opts)` and dispatches prompt. Resolves agent via `ask_agent.target_agent` → session cache (`M._session_ask_agent`) → runtime input prompt. Appends `@[abs_path]` file reference.
- `init.select_agent_harness(arg, opts)`: Switches target agent harness interactively (`vim.ui.select`) or via argument.

**Registered Commands:**

| Command | Keymap | Description |
|---------|--------|-------------|
| `:SaganiStatus` | `<leader>as` (n) | Show topology and target pane status |
| `:SaganiSend` | `<leader>as` (v), `<leader>at` (v) | Send visual selection with instruction |
| `:SaganiSelectTarget` | `<leader>ac` (n) | Set manual pane override |
| `:SaganiContext` | `<leader>ac` (v) | Send code context to agent |
| `:SaganiDiff` | `<leader>ad` (n,v) | Send diff comment to agent |
| `:SaganiPrompt` | `<leader>ap` (n,v) | Send custom prompt |
| `:SaganiSpawnPane` | `<leader>an` (n) | Spawn new agent pane |
| `:SaganiSelectAgent` / `:SaganiSelectHarness` | `<leader>ah` (n) | Select agent harness |
| `:SaganiAskAgent` | `<leader>aa` (n,v) | Ask agent in popup |
| `:SaganiReview` / `:SaganiReviewToggle` | `<leader>ar` (n) | Toggle diff review |
| `:SaganiAccept` / `:SaganiAcceptHunk` / `:SaganiAcceptAll` | `<leader>ay` (n) | Accept edit hunk or all |
| `:SaganiReject` / `:SaganiRejectHunk` / `:SaganiRejectAll` | `<leader>ax` (n) | Reject edit hunk or all |
| `:SaganiNextHunk` | `<leader>a]` (n) | Jump to next edit hunk |
| `:SaganiPrevHunk` | `<leader>a[` (n) | Jump to previous edit hunk |
| `:SaganiReload` | — | Hot-reload all sagani modules |

### `lua/sagani/backend.lua`
- `backend.register(name, adapter)`: Registers a backend adapter by name. Called in `init.lua` for all four built-in backends.
- `backend.get_backend(opts)`: Resolves the active backend adapter. Returns `adapter, backend_name`. If `opts.backend = "auto"`, auto-detects via `detect_env()` in priority order: **Herdr → Tmux → Zellij → Native**. If `opts.backend` is a string, looks up registered adapter by name. If it is a table, uses it directly as a custom adapter.

### `lua/sagani/backend/herdr.lua`
- `herdr.detect_env(runner)`: Returns `{ active, id, metadata }` based on `topology.detect_env`.
- `herdr.discover_target(opts)`: Delegates to `topology.discover_target_pane(opts)`.
- `herdr.spawn_pane(opts)`: Delegates to `topology.spawn_agent_pane(opts)`.
- `herdr.spawn_popup(opts)`: Delegates to `topology.spawn_agent_popup(opts)`. Returns `agent_name, err, metadata`. The `agent_name` is the dispatch target passed to `herdr agent prompt`.
- `herdr.prompt_target(target_id, prompt_text, opts)`: Runs `herdr agent prompt <target_id> <prompt_text>` via `vim.system` (or `opts.runner` in tests).

### `lua/sagani/backend/native.lua`
- `native.detect_env(_)`: Always returns `{ active = true }` (native is always available as last resort).
- `native.discover_target(opts)`: Returns `opts.pane_override` or the last tracked `_active_win` handle.
- `native.spawn_pane(opts)`: Opens a vertical/horizontal split, runs `vim.fn.termopen(agent)` if binary exists.
- `native.spawn_popup(opts)`: Opens a centered float window via `vim.api.nvim_open_win`, runs agent in terminal.
- `native.prompt_target(target_id, prompt_text, opts)`: Sends text to terminal channel via `vim.api.nvim_chan_send`, or appends to plain buffer.

### `lua/sagani/backend/tmux.lua`
- `tmux.detect_env(_)`: Checks `$TMUX` env var. Returns `{ active, id = $TMUX_PANE }`.
- `tmux.discover_target(opts)`: Returns `opts.pane_override` or `opts.backends.tmux.target_pane`.
- `tmux.spawn_pane(opts)`: Runs `tmux split-window -h/-v -P -F "#{pane_id}" <agent>`.
- `tmux.spawn_popup(opts)`: Runs `tmux display-popup -E -w 80% -h 80% <agent>`.
- `tmux.prompt_target(target_id, prompt_text, opts)`: Runs `tmux send-keys -t <id> <text> C-m`.

### `lua/sagani/backend/zellij.lua`
- `zellij.detect_env(_)`: Checks `$ZELLIJ` env var. Returns `{ active, id = $ZELLIJ_PANE_ID }`.
- `zellij.discover_target(opts)`: Returns `opts.pane_override` or `opts.backends.zellij.target_pane`.
- `zellij.spawn_pane(opts)`: Runs `zellij action new-pane -d <dir> -- <agent>`.
- `zellij.spawn_popup(opts)`: Runs `zellij action new-pane -f -- <agent>`.
- `zellij.prompt_target(target_id, prompt_text, opts)`: Runs `zellij action write-chars "<text>\n"`.

### `lua/sagani/backend/herdr/topology.lua`
> **Herdr-specific.** Contains Herdr CLI topology discovery encapsulated under the Herdr backend package.

- `topology.detect_env(runner)`: Returns `{ in_herdr, pane_id, tab_id, workspace_id, cwd }`.
- `topology.get_current_pane_info(runner)`: Runs `herdr pane current --current` and parses JSON result.
- `topology.list_agents(runner)`: Queries `herdr agent list` and returns table of agents or error.
- `topology.discover_target_pane(opts)`: Auto-discovers target agent pane using Tier 1-8 fallback hierarchy (Override → Tab → Workspace → CWD → Auto-Spawn → Global).
- `topology.wait_for_agent_ready(pane_id, timeout_ms, opts)`: Waits for target agent CLI to authenticate and render interactive ready prompt.
- `topology.spawn_agent_pane(opts)`: Splits current Herdr pane and initializes new target agent pane.
- `topology.spawn_agent_popup(opts)`: Splits a right pane (`herdr pane split --direction right`), starts the agent and waits for readiness (`herdr agent start --timeout <sec>`). Returns `agent_name, err, metadata` — `agent_name` is used as the `herdr agent prompt` dispatch target.

### `lua/sagani/selection.lua`
- `selection.get_visual_selection(bufnr)`: Returns `{ snippet, start_line, end_line, start_col, end_col, mode, file_path, filetype }`.
- `selection.send_selection_prompt(opts)`: Prompts user for instruction, formats visual selection, dispatches via `init.dispatch_prompt`.
- `selection.send_code_context(opts)`: Dispatches visual selection context directly to agent with default review prompt.

### `lua/sagani/diff.lua`
- `diff.take_snapshot(bufnr)`: Captures baseline snapshot lines array of current buffer.
- `diff.get_baseline_lines(bufnr)`: Retrieves baseline (from snapshot, git HEAD, or file on disk).
- `diff.get_hunks(bufnr)`: Calculates hunks between baseline lines and current buffer lines.
- `diff.toggle_review(bufnr, opts, mode_arg)` / `diff.open_review(bufnr, opts)`: Opens or closes side-by-side split review diff view.
- `diff.accept_change(target, bufnr, opts)`: Accepts hunk under cursor or all pending changes.
- `diff.reject_change(target, bufnr, opts)`: Reverts hunk or all changes back to baseline.
- `diff.next_hunk(win_id, opts)` / `diff.prev_hunk(win_id, opts)`: Navigates cursor to next/previous hunk.
- `diff.get_diff_hunk_at_cursor()`: Extracts current hunk context (`file_path`, `start_line`, `end_line`, `diff_text`).
- `diff.send_diff_comment(opts)`: Captures diff review comment and dispatches formatted diff block to agent.

### `lua/sagani/format.lua`
- `format.build_context_prompt(user_instruction, selection)`: Constructs Markdown code context prompt string.
- `format.build_diff_prompt(user_comment, diff_info)`: Constructs Markdown diff block prompt string.

### `lua/sagani/notify.lua`
- `notify.info(msg, opts)` / `notify.warn(msg, opts)` / `notify.error(msg, opts)`: LazyVim-aware notifications with fallback to `vim.notify`.

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
- `tests/test_selection.lua`: Visual selection extraction (`v`, `V`, `<C-v>`) and prompt dispatch tests.
- `tests/test_diff.lua`: Diff hunk extraction, baseline snapshotting, and review comment formatting tests.
- `tests/test_format.lua`: Markdown code block and diff block builder tests.
- `tests/test_plugin_spec.lua`: Minimal setup, options merging, command registration, and WhichKey integration tests.
- `tests/test_backend.lua`: Backend registry (`backend.register` / `backend.get_backend`) unit tests.
- `tests/test_ask_agent.lua`: `ask_agent_prompt` session caching and popup routing tests.
- `tests/test_review.lua`: Diff review auto-open, accept/reject hunk, and watcher integration tests.
- `tests/test_adversarial_m2.lua`: Cross-module integration and stress recovery tests.
- `tests/test_challenger_stress.lua`: Boundary condition and stress suite tests.
- `tests/test_challenger2_empirical.lua`: Empirical edge-case and concurrent dispatch tests.

### Test Isolation Guard Rule
When adding or modifying `dispatch_prompt` or shell execution code, ensure `_G.RUNNING_TEST_SUITE` checks bypass live external `herdr` shell execution so the test suite never dispatches live messages to active agent conversations. Pass `opts.runner` to inject mock CLI runners in tests.

---

## ⚙️ 5. Directory & File Organization

```
sagani.nvim/
├── AGENTS.md                # Permanent Developer & Agent Manual
├── README.md                # Public Plugin Documentation & Installation Guide
├── LICENSE                  # MIT License
├── .gitignore               # Ignores .agents/ local agent workspace logs
├── plugins/
│   └── sagani.lua           # LazyVim plugin specification
├── lua/
│   └── sagani/
│       ├── init.lua         # Plugin setup, commands, keymaps, dispatch entry point
│       ├── backend.lua      # Backend registry & auto-detection router
│       ├── topology.lua     # Herdr-specific topology discovery & CLI transport
│       ├── selection.lua    # Visual selection extraction & prompt dispatch
│       ├── diff.lua         # Diff hunk review, accept/reject, watcher
│       ├── format.lua       # Markdown prompt & diff block formatting helpers
│       ├── notify.lua       # LazyVim-aware notification handler
│       ├── backend/         # Multiplexer backend adapters (all implement the contract)
│       │   ├── herdr.lua    # Herdr adapter (pure CLI: pane split + agent start + agent prompt)
│       │   ├── herdr/
│       │   │   └── topology.lua # Herdr-specific topology discovery & CLI transport
│       │   ├── native.lua   # Native Neovim float/split/terminal adapter
│       │   ├── tmux.lua     # Tmux adapter (split-window, display-popup, send-keys)
│       │   └── zellij.lua   # Zellij adapter (new-pane, write-chars)
└── tests/
    ├── run_tests.lua                    # Master headless test runner
    ├── minimal_init.lua                 # Plenary Busted test runner
    ├── test_topology.lua                # Topology unit tests
    ├── test_selection.lua               # Selection unit tests
    ├── test_diff.lua                    # Diff unit tests
    ├── test_format.lua                  # Formatting unit tests
    ├── test_plugin_spec.lua             # Spec & setup unit tests
    ├── test_backend.lua                 # Backend registry unit tests
    ├── test_ask_agent.lua               # ask_agent_prompt unit tests
    ├── test_review.lua                  # Diff review integration tests
    ├── test_adversarial_m2.lua          # Cross-module stress & recovery tests
    ├── test_challenger_stress.lua       # Boundary condition stress suite
    └── test_challenger2_empirical.lua   # Empirical edge-case tests
```

---

## 🗺️ 6. Decoupling Roadmap (In Progress)

The three-layer separation is partially complete. Below is the current state and remaining work:

### ✅ Done
- **Backend registry** (`backend.lua`): `register` / `get_backend` contract is live.
- **Four backend adapters** fully implemented: `native`, `herdr`, `tmux`, `zellij`.
- **`init.lua` routes through `backend.get_backend(opts)`** for all `dispatch_prompt`, `spawn_popup`, `spawn_pane` calls.

### 🔲 Planned / In Progress
- **Transport abstraction layer** (`transport/`) — a generic interface to unify socket, CLI subprocess, HTTP REST, and other comms behind a single `transport.send(method, params)` contract. This would allow `backend/herdr.lua` to use any transport without knowing the implementation.
- **Agent protocol adapters** — separate "how to format a message for `agy` vs `codex`" from "where to send it." Currently prompt formatting is done inline in `init.lua` and `selection.lua`.
- **`topology.lua` refactored** — moved into `lua/sagani/backend/herdr/topology.lua` so Herdr topology discovery is encapsulated within its adapter package.

---

## 🤖 7. Rules for Future Agent Developers

1. **Incremental Edits & Testing**: Run `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` after every code modification. Never declare success without 100% test pass rate.
2. **Preserve Backend Contract**: Every backend adapter **must** implement all five methods: `detect_env`, `discover_target`, `spawn_pane`, `spawn_popup`, `prompt_target`. Never call topology or socket modules from `init.lua` directly — always go through `backend.get_backend(opts)`.
3. **Preserve Compatibility**: Keep the single-line installation spec (`{ "vikks/sagani", opts = {} }`) fully functional by ensuring `require("sagani").setup(opts)` handles default keymap and WhichKey registration out of the box.
4. **Test Isolation**: All CLI and shell execution code must honour `_G.RUNNING_TEST_SUITE`. Pass `opts.runner` to mock external commands in tests.
5. **No Unneeded File Churn**: Do not commit local `.agents/` workspace logs to git. Keep `.gitignore` updated.
6. **Decoupling Direction**: When adding new transport mechanisms (HTTP, stdio, etc.), add a new module under `lib/`. When adding new multiplexer support, add a new adapter under `backend/`. Never mix transport logic into `init.lua` or `selection.lua`/`diff.lua`.
