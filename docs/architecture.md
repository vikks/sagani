# System Architecture — sagani.nvim

**sagani.nvim** uses a 4-layer decoupled architecture separating visual buffer interaction from multiplexer placement, protocol communication, and local model discovery.

---

## 🏛️ System Architecture Diagram

```
 +-----------------------------------------------------------------------------------+
 |                                    Neovim Layer                                   |
 |                                                                                   |
 |  +--------------------------+          +--------------------------------+          |
 |  | plugins/sagani.lua       |          | lua/sagani/init.lua            |          |
 |  | (LazyVim Plugin Spec &   |--------->| (Setup, Commands, Keymaps,     |          |
 |  |  WhichKey Configuration) |          |  dispatch_prompt entry point)  |          |
 |  +--------------------------+          +--------+---------------+-------+          |
 |                                                 |               |                  |
 |        +-------------------+   +------------------+             |   +------------+ |
 |        | selection.lua     |   | diff.lua         |             +-->| ui/        | |
 |        | (Visual selection |   | (Diff hunk       |                 | markdown_  | |
 |        |  extraction)      |   |  review/accept)  |                 | popup.lua  | |
 |        +--+----------------+   +------------------+                 +------------+ |
 +-----------|-----------------------------------------------------------------------+
             |                                    |
             | dispatch_prompt                    | get_backend(opts, task_type)
             v                                    v
 +-----------------------------------+   +-------------------------------------------+
 |       Protocol & IPC Layer        |   |           Backend Registry Layer          |
 |                                   |   |                                           |
 |   +---------------------------+   |   |   backend.get_backend(opts) auto-detects: |
 |   | protocol/ (ACP/HTTP/CLI)  |   |   |   Herdr -> Tmux -> Zellij -> Native       |
 |   +-------------+-------------+   |   +-------+---------+--------+--------+-------+
 |                 |                 |           |         |        |        |       |
 |  +--------------+--------------+  |           v         v        v        v       |
 |  | protocol/cli/ (agy, codex,  |  |  +--------+  +------+--+ +---+----+ +--+----+ |
 |  |  opencode, gemini, hermes)  |  |  |backend/|  |backend/ | |backend/| |backend| |
 |  +-----------------------------+  |  |herdr   |  |tmux     | |zellij  | |native |
 +-----------------------------------+  +---+----+  +----+----+ +---+----+ +--+----+
```

---

## 🧩 Four-Layer Decoupled Architecture

| Layer | Responsibility | Key Modules |
|---|---|---|
| **1. Neovim Layer** | Visual selections, diff review, input/output formatting, user commands, keymaps, native Markdown floating UI | `init.lua`, `selection.lua`, `diff/` (`baseline`, `hunks`, `view`, `actions`), `format/` (`input/`, `output/`), `notify.lua`, `ui/markdown_popup/`, `ui/picker/` |
| **2. Deterministic Resolver & Validator Layer** | Fail-fast config validation and single-pass compilation (`build_plan`) into immutable `ExecutionPlan` tables | `resolver.lua`, `config/validator.lua` |
| **3. Backend Registry Layer** | Multiplexer auto-detection (`Herdr` → `Tmux` → `Zellij` → `Native`), layout placement, declarative geometry capabilities | `backend/` (`registry`, `task`, `herdr`, `tmux`, `zellij`, `native`) |
| **4. Protocol & Agent Harness Layer** | System IPC protocols (`acp`, `http`, `cli`, `json_rpc`) decoupled from declarative agent harness definitions (`agy`, `codex`, `opencode`, `hermes`, `gemini`) | `protocol/`, `agents/` |
| **5. Model Cache & State Layer** | 100% dynamic CLI/API model discovery and persistent local disk cache | `cache.lua` (`stdpath('state')/sagani/models.json`) |

---

## 📌 Backend Adapter Contract

Every multiplexer backend adapter MUST implement the standard adapter contract interface:

```lua
{
  name = "backend_name",
  detect_env = function(runner) ... end,       -- Returns { active = bool, id = string|nil }
  discover_target = function(opts) ... end,    -- Returns target_id, err, metadata
  list_agents = function(runner) ... end,      -- Returns array of active agent pane tables
  spawn_pane = function(opts) ... end,         -- Returns pane_id, err, metadata
  spawn_popup = function(opts) ... end,        -- Returns agent_target, err, metadata
  prompt_target = function(id, text, opts) ... end, -- Returns ok (bool), err
  wait_for_ready = function(id, opts) ... end, -- Returns ok (bool)
}
```
