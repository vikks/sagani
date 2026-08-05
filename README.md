# sagani.nvim 🔮

[![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?style=for-the-badge&logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%20%2F%20JIT-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org)
[![Tests](https://img.shields.io/badge/Tests-526%20Passed-success?style=for-the-badge&logo=github)](tests/run_tests.lua)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

**sagani.nvim** is a harness-agnostic, decoupled AI coding agent integration plugin for [Neovim](https://neovim.io) (tailored for [LazyVim](https://www.lazyvim.org/)). It bridges your buffer workflows directly with terminal multiplexers ([`herdr`](https://github.com/herdr/herdr), `tmux`, `zellij`, or native Neovim splits/floats) and AI agent harnesses (`agy`, `codex`, `opencode`, `hermes`, `gemini`, etc.).

---

## ✨ Features

- 🖥️ **Multi-Backend Transport Routing**: Auto-detects active terminal environment in order: **Herdr → Tmux → Zellij → Native Neovim**. Run agents seamlessly across multiplexers or in standalone floats/splits without external dependencies.
- 🔌 **Protocol-First Agent Driver Layer**: Transport drivers (`acp`, `http`, `cli`, `json_rpc`) connect directly to agent daemons (e.g. OpenCode HTTP ACP, Gemini JSON-RPC, Antigravity CLI).
- 📌 **Single-Keypress Floating Popup & Pin Mode**: Ask general questions in floating Markdown popups (`:SaganiAskAgent`, `<leader>aa`). Press `p` inside the popup to instantly promote floating windows to directional splits (`[h]` Left, `[l]` Right, `[k]` Top, `[j]` Bottom) or a new tab (`[t]`).
- 🤖 **100% Dynamic Model Discovery**: Discovers models live from agent CLIs, ACP daemons, and system caches (cached under `stdpath('state')/sagani/models.json` with 24h TTL). Intelligent reasoning effort prompts (`low`, `medium`, `high`) are dynamically presented only when supported by the selected model.
- 🔍 **Interactive Edit Review & Hunk Acceptance**: Review agent edits side-by-side (`:SaganiReview`), navigate change hunks (`]c` / `[c`), and accept (`:SaganiAccept`, `<leader>ay`) or reject (`:SaganiReject`, `<leader>ax`) hunks individually or across the whole file.
- 📐 **Visual Context & Diff Feedback**: Extract characterwise, linewise, or blockwise visual selections formatted as structured Markdown code blocks with file path, line range, and syntax highlighting. Send diff review feedback directly to your target agent.
- ⌨️ **LazyVim & WhichKey Integration**: Built-in plugin spec with automatic `folke/which-key.nvim` menu registration (`<leader>a` → `"Sagani"`).
- 🧪 **Zero-Dependency Headless Test Suite**: Tested headlessly with **526 unit & integration tests** covering cross-module stress, multi-turn HTTP ACP sessions, and process table recovery.

---

## 🏛️ System Architecture

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
             |                               |
             | dispatch_prompt               | get_backend(opts, task_type)
             v                               v
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

## 📦 Requirements

- **Neovim**: `>= 0.9.0`
- **Agent Harnesses**: One or more installed agent CLIs (`agy`, `opencode`, `codex`, `gemini`, `hermes`, etc.)
- **(Optional)** Terminal Multiplexer: `herdr`, `tmux`, or `zellij` (if running inside a multiplexer)
- **(Optional)** UI Integrations: `folke/which-key.nvim` for keymap menu popups, `sindrets/diffview.nvim` for diff reviews

---

## 🚀 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "vikks/sagani.nvim",
  opts = {}, -- Automatically merges default options from lua/sagani/init.lua
}
```

---

## ⚙️ Configuration & Defaults (`init.lua`)

Configure **sagani.nvim** via `opts` in lazy.nvim or `require("sagani").setup(opts)`:

```lua
require("sagani").setup({
  -- Global Window & Visual UI Styling Defaults
  window_opts = {
    width = 0.8,         -- Floating popup width (80% or integer columns)
    height = 0.8,        -- Floating popup height (80% or integer lines)
    border = "rounded",  -- Border style: "rounded", "single", "double", "solid", "shadow", "none"
    winblend = 0,        -- Floating window transparency (0-100)
    ratio = 0.3,         -- Pane split size ratio (30% split size)
  },

  -- Backend Placements & Overrides (WHERE tasks get placed per multiplexer)
  -- This is only for UI placement; the actual agent harness to backend link is determined by the `tasks` table below.
  backends = {
    native = {
      ask = "popup",       -- Native creates a Neovim floating popup for 'ask'
      review = "vsplit",   -- Native creates a vertical split for 'review'
      code = "vsplit",
      chat = "vsplit",
      border = "rounded",
      winblend = 0,
      split_direction = "vertical",
    },
    herdr = {
      ask = false,         -- Opts out of Herdr for 'ask' ➡️ falls back directly to native float!
      review = "right-pane",
      code = "right-pane",
      chat = "right-pane",
      ratio = 0.3,
      auto_discover = true,
      auto_spawn = false,
    },
    tmux = {
      ask = "popup",       -- Tmux display-popup for questions
      review = "right-pane",
      code = "right-pane",
      chat = "right-pane",
      width = "80%",
      height = "80%",
      border = "rounded",
      split_direction = "right",
      target_pane = nil,
    },
    zellij = {
      ask = "floating",    -- Zellij floating pane for questions
      review = "right-pane",
      code = "right-pane",
      chat = "right-pane",
      direction = "right",
    },
  },

  -- Provider Configurations (LLM API credentials & display aliases)
  providers = {
    google = { api_key_env = "GEMINI_API_KEY", alias = "Google Gemini" },
    openai = { api_key_env = "OPENAI_API_KEY", alias = "OpenAI" },
    anthropic = { api_key_env = "ANTHROPIC_API_KEY", alias = "Anthropic" },
  },

  -- Agent Registry (Logical Agent ID -> Harness Driver & Execution Command)
  agents = {
    agy = {
      harness = "agy",
      cmd = { "agy" },
      name = "Antigravity CLI",
    },
    codex = {
      harness = "codex",
      cmd = { "codex" },
      name = "Codex CLI",
    },
    opencode = {
      harness = "opencode",
      cmd = { "opencode" },
      name = "Opencode Agent",
      port = 4096,
    },
    hermes = {
      harness = "hermes",
      cmd = { "hermes" },
      name = "Hermes Agent",
    },
    gemini = {
      harness = "gemini",
      cmd = { "gemini" },
      name = "Gemini CLI",
    },
  },

  -- Task Configurations (WHAT agent harness runs per task)
  tasks = {
    chat = "agy",
    ask = {
      agent = "agy",
      backend = "native",
      instructions = "Answer the user's question concisely and accurately.",
    },
    review = {
      agent = "codex",
      backend = "default",
      instructions = "Review the provided code changes and offer actionable feedback.",
    },
    code = {
      agent = "opencode",
      port = 4096,
      backend = "default",
      instructions = "Fulfill the user's coding request directly in the buffer.",
    },
  },

  -- General Settings
  auto_discover = true,
  auto_spawn = false,
  pane_override = nil,
  default_keymaps = true,
  which_key = true,

  -- Notification Settings
  notify = {
    enabled = true,
    title = "sagani.nvim",
  },
})
```

---

## ⌨️ Keymaps & User Commands

### Default Keymaps (`<leader>a`)

| Keymap | Mode | User Command | Description |
|---|---|---|---|
| `<leader>aa` | Normal / Visual | `:SaganiAskAgent` | Ask general question in floating popup or pane |
| `<leader>ab` | Normal | `:SaganiToggleBackend` | Toggle backend mode between `auto` multiplexer detection & `native` Neovim |
| `<leader>as` | Normal | `:SaganiStatus` | Display active backend topology and target pane status |
| `<leader>as` | Visual | `:SaganiSend` | Send visual selection with prompt instruction to agent |
| `<leader>ac` | Normal | `:SaganiSelectTarget` | Set manual target pane ID override |
| `<leader>ac` | Visual | `:SaganiContext` | Send visual selection code context to agent |
| `<leader>ad` | Normal / Visual | `:SaganiDiff` | Send formatted diff review comment & hunk to agent |
| `<leader>ap` | Normal / Visual | `:SaganiPrompt` | Send custom prompt directly to target agent |
| `<leader>an` | Normal | `:SaganiSpawnPane` | Spawn new agent pane in active multiplexer |
| `<leader>ah` | Normal | `:SaganiSelectAgent` | Select target agent harness & model interactively |
| `<leader>ar` | Normal | `:SaganiReview` | Toggle side-by-side agent edit review diff split |
| `<leader>ay` | Normal | `:SaganiAccept` | Accept change hunk under cursor (or all pending edits) |
| `<leader>ax` | Normal | `:SaganiReject` | Reject change hunk under cursor (or revert all edits) |
| `<leader>a]` | Normal | `:SaganiNextHunk` | Navigate cursor to next edit hunk |
| `<leader>a[` | Normal | `:SaganiPrevHunk` | Navigate cursor to previous edit hunk |

---

### User Commands

| Command | Description |
|---|---|
| `:SaganiToggleBackend [mode]` | Toggle backend transport mode between `auto` and `native` (or set explicit backend) |
| `:SaganiBackend [mode]` | Alias for `:SaganiToggleBackend` |
| `:SaganiAskAgent [prompt]` | Ask agent general questions in floating popup or dedicated pane |
| `:SaganiSelectAgent [harness]` | Select active agent harness & model dynamically |
| `:SaganiPromote [placement]` | Promote active floating popup to split (`left`, `right`, `top`, `bottom`, `tab`) |
| `:SaganiStatus` | Display multiplexer topology and target pane status |
| `:SaganiSend` | Capture visual selection (`v`, `V`, `<C-v>`) and send with prompt instruction |
| `:SaganiContext` | Capture visual selection code context and send directly to agent |
| `:SaganiDiff` | Capture active diff hunk and send formatted review comment |
| `:SaganiReview` | Toggle side-by-side agent edit review diff split against baseline |
| `:SaganiAccept [hunk\|all]` | Accept edit hunk at cursor (or all pending edits in buffer) |
| `:SaganiReject [hunk\|all]` | Reject edit hunk at cursor (or revert all edits to baseline) |
| `:SaganiNextHunk` | Navigate cursor to next edit hunk in buffer |
| `:SaganiPrevHunk` | Navigate cursor to previous edit hunk in buffer |
| `:SaganiClearCache` | Flush persistent disk model cache (`stdpath('state')/sagani/models.json`) |
| `:SaganiReload` | Hot-reload all `sagani.*` Lua modules without restarting Neovim |

---

## 📌 Floating Popup & Single-Keypress Pin Mode

When asking questions via `:SaganiAskAgent` (`<leader>aa`), Sagani opens a floating Markdown popup window with interactive keybindings:

```
📌 Pin window: [h] Left | [l] Right | [k] Top | [j] Bottom | [t] Tab | [Esc/q] Cancel
```

- **`p`**: Enter **Single-Keypress Pin Mode**. Pressing `h`, `l`, `k`, `j`, or `t` immediately promotes the float into a vertical/horizontal split or new tab page.
- **`<CR>` / `r`**: Send follow-up prompt to continue multi-turn session.
- **`yr`**: Copy current turn's response text to clipboard register (`+`).
- **`q` / `<Esc>`**: Close popup.

---

## 🧪 Testing & Verification

Sagani includes a master headless test runner verifying **526 unit and integration tests**:

```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```

---

## 📄 License

[MIT](LICENSE) © 2026
