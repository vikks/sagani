# sagani.nvim 🔮

[![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?style=for-the-badge&logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%20%2F%20JIT-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

A harness-agnostic Neovim plugin (tailored for [LazyVim](https://www.lazyvim.org/)) that seamlessly connects your Neovim buffer workflows with terminal multiplexers ([`herdr`](https://github.com/herdr/herdr)) and AI coding agent harnesses (`agy`, `codex`, `opencode`, `hermes`, etc.).

---

## ⚡ Features

- **🌐 Harness-Agnostic Agent Switching**: Switch target agent harnesses (`agy`, `codex`, `opencode`, `hermes`, or custom CLI tools) on the fly via an interactive menu (`:SaganiSelectAgent`).
- **⚡ Reliable CLI-Based Agent Dispatch**: Communicates with Herdr via direct CLI commands (`herdr agent prompt`, `herdr pane split`, `herdr agent start --timeout`). Agent startup readiness is verified at the CLI level — no race conditions, no timing hacks.
- **🧩 Automatic Topology Discovery**: Automatically detects your active `herdr` terminal environment (pane, tab, workspace IDs) and discovers active agent target panes.
- **✨ Visual Selection & Code Context**: Dispatch visual selections (`v`, `V`, `<C-v>`) formatted with file path, line range, syntax highlighting, and instruction prompts directly to your agent.
- **💬 Ask General Agent in a New Pane**: Prompt an agent for general questions or assistance in a dedicated new pane (`:SaganiAskAgent`, `<leader>aa`) with automatic file context references (`@[abs_path]`) and session-cached agent selection.
- **🔍 Structured Diff Review**: Review git diffs (via `diffview.nvim` or native Neovim diff split), calculate hunks, and submit formatted Markdown diff review comments to your agent.
- **🔎 Interactive Edit Review & Accept/Reject**: See exactly where agent edits occurred in your buffer via side-by-side diff review splits (`:SaganiReview`), navigate hunks (`]c` / `[c`), and accept (`<leader>ay` / `:SaganiAccept`) or reject (`<leader>ax` / `:SaganiReject`) individual edit hunks or all file changes.
- **⌨️ LazyVim & WhichKey Integration**: Includes pre-configured LazyVim plugin specs with optional `folke/which-key.nvim` menu grouping (`<leader>a` → `"Sagani"`).
- **🧪 Headless Test Suite**: Fully covered by a headless Neovim unit and integration test suite.

---

---

## 📦 Requirements

- **Neovim**: `>= 0.9.0`
- **Terminal Multiplexer**: `herdr` CLI installed and available in `$PATH`
- **AI Agent Harness**: One or more installed agent harnesses (`agy`, `codex`, `opencode`, `hermes`, etc.)
- **(Optional)**: `folke/which-key.nvim` for keymap menu integration

---

## 🚀 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "vikks/sagani",
  opts = {
    target_agent = "agy",
    auto_discover = true,
    auto_spawn = "left",
    ask_agent = {
      target_agent = nil,
    },
    review = {
      enabled = true,
      auto_open = false,
    },
  },
}
```

That's it! `sagani.nvim` will automatically register its default user commands, default keymaps (`<leader>a...`), and WhichKey menu integration upon setup.

---

## ⚙️ Configuration

Configure **sagani.nvim** via `require("sagani").setup(opts)`:

```lua
require("sagani").setup({
  -- Default target AI coding agent harness ("agy", "codex", "opencode", "hermes", "gemini", etc.)
  target_agent = "agy",

  -- Provider Aliases & API Keys (Models are discovered 100% dynamically from live agent CLIs!)
  providers = {
    google = { api_key_env = "GEMINI_API_KEY", alias = "Google Gemini" },
    openai = { api_key_env = "OPENAI_API_KEY", alias = "OpenAI" },
    anthropic = { api_key_env = "ANTHROPIC_API_KEY", alias = "Anthropic" },
  },

  -- 1. Tasks Configuration (WHAT agent harness, provider, model, effort, alias, protocol to run per task)
  tasks = {
    ask = {
      protocol = "acp",
      harness = "agy",
      model = "gemini-3.6-flash-low",
      effort = "low",
      alias = "Gemini 3.6 Flash (Low)",
    },
    review = { protocol = "terminal", harness = "codex", model = "o3", effort = "high" },

    -- Short-form string syntax specifies the agent harness name directly:
    code = "opencode",  -- Short for { harness = "opencode" }
    chat = "agy",       -- Short for { harness = "agy" }
  },

  -- 2. Global Window & UI Styling Defaults (HOW windows look visually)
  window_opts = {
    width = 0.8,         -- Floating popup width (80% or integer columns)
    height = 0.8,        -- Floating popup height (80% or integer lines)
    border = "rounded",  -- Border style: "rounded", "single", "double", "solid", "shadow", "none"
    winblend = 10,       -- Neovim floating window transparency (0-100)
    ratio = 0.3,         -- Pane split size ratio (30% split size)
  },

  -- 3. Backend Placements & Overrides (WHERE tasks get placed per multiplexer + flat UI/backend overrides)
  backends = {
    native = {
      ask = "popup",       -- Native creates a Neovim floating window for 'ask'
      review = "vsplit",   -- Native creates a vertical split for 'review'
      code = "vsplit",
      chat = "vsplit",
      border = "rounded",
      winblend = 15,       -- Native-specific UI transparency override
    },
    herdr = {
      ask = false,         -- Herdr opts out of 'ask' ➡️ falls back directly to native floating popup!
      review = "right-pane",
      code = "right-pane",
      chat = "right-pane",
      ratio = 0.3,         -- Herdr-specific split ratio override (herdr pane split --ratio 0.3)
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
      border = "rounded",  -- tmux display-popup -b rounded
    },
    zellij = {
      ask = "floating",    -- Zellij floating pane for questions
      review = "right-pane",
      code = "right-pane",
      chat = "right-pane",
    },
  },

  -- 4. Provider Configurations (LLM API credentials & endpoints)
  providers = {
    google = { api_key_env = "GEMINI_API_KEY" },
    openai = { api_key_env = "OPENAI_API_KEY" },
    anthropic = { api_key_env = "ANTHROPIC_API_KEY" },
  },

  -- General question agent configuration
  ask_agent = {
    target_agent = nil, -- Specific target agent for general questions (if nil, uses active session agent set via <leader>ah or target_agent)
  },

  -- Agent edit review configuration
  review = {
    enabled = true,    -- Enable interactive edit review & accept/reject workflow
    auto_open = false, -- Automatically open review view when agent edits occur
    mode = "inline",   -- Review display style: "inline" (virtual text & line highlights) or "split" (side-by-side vsplit)
  },

  -- Notification settings
  notify = {
    enabled = true,
    title = "sagani.nvim",
  },
})
```

---

### 🎯 Task & Backend Configuration Guidelines

`sagani.nvim` separates your configuration into four clean concern domains:

1. **`tasks` (WHAT agent runs)**: Configures agent harnesses, providers, models, thinking effort, and timeouts. Short-form string syntax defines the **agent harness name** directly (`code = "opencode"`).
2. **`window_opts` (HOW windows look)**: Configures global visual UI styling (`width`, `height`, `border`, `winblend` transparency, `ratio` split ratio).
3. **`backends` (WHERE tasks get placed)**: Configures per-multiplexer task placements (`ask = false`, `review = "right-pane"`) and backend UI/options overrides.
4. **`providers` (LLM API Settings)**: Configures API keys and base URLs.

#### Supported Placement Specifiers (`opts.backends.<name>`)

| Specifier | Category | Behavior |
|---|---|---|
| `"right-pane"` / `"right"` | Pane Split | Splits current pane to the right |
| `"left-pane"` / `"left"` | Pane Split | Splits current pane to the left |
| `"bottom-pane"` / `"down"` | Pane Split | Splits current pane downwards |
| `"top-pane"` / `"up"` | Pane Split | Splits current pane upwards |
| `"tab"` / `"new-tab"` | Tab | Creates a new tab/window in multiplexer or Neovim |
| `"popup"` / `"floating"` | Floating Window | Spawns a floating popup window |
| `"vsplit"` / `"hsplit"` | Native Split | Vertical or horizontal split in Neovim |
| `false` | Opt-out | Disables active multiplexer for this task ➡️ falls back directly to `native` |

#### Resolution Engine

When `sagani.nvim` dispatches a task (`ask`, `review`, `code`, `chat`, or any custom key):

- **Placement**: Evaluates `opts.backends[active_backend][task_name]`. If `false`, falls back directly to `native` (`opts.backends.native[task_name]`).
- **UI Styling**: Merges `opts.window_opts` with `opts.backends[active_backend]` (`width`, `height`, `border`, `winblend`, `ratio`).
- **Agent Harness**: Evaluates `opts.tasks[task_name]` (`harness`, `provider`, `model`, `effort`).

---

## ⌨️ Keymaps & Commands

### Keymaps Reference

| Keymap | Modes | Command | Description |
|---|---|---|---|
| `<leader>as` | Normal | `:SaganiStatus` | Display Herdr session status, topology, and target pane |
| `<leader>as` | Visual | `:SaganiSend` | Send visual selection with instruction prompt to agent |
| `<leader>ac` | Normal | `:SaganiSelectTarget` | Set manual target pane ID override |
| `<leader>ac` | Visual | `:SaganiContext` | Send visual selection code context to agent |
| `<leader>ad` | Normal / Visual | `:SaganiDiff` | Send diff review comment & Markdown diff block to agent |
| `<leader>ap` | Normal / Visual | `:SaganiPrompt` | Send custom prompt to target agent |
| `<leader>an` | Normal | `:SaganiSpawnPane` | Spawn new Herdr pane for active agent harness |
| `<leader>ah` | Normal | `:SaganiSelectAgent` | Open picker to select agent harness (`agy`, `codex`, etc.) |
| `<leader>aa` | Normal / Visual | `:SaganiAskAgent` | Ask general questions to agent in a new pane |
| `<leader>ar` | Normal | `:SaganiReview` | Toggle side-by-side agent edit review diff view |
| `<leader>ay` | Normal | `:SaganiAccept` | Accept agent edit change (hunk under cursor or all) |
| `<leader>ax` | Normal | `:SaganiReject` | Reject agent edit change (revert hunk under cursor or all) |
| `<leader>a]` | Normal | `:SaganiNextHunk` | Jump cursor to next agent edit hunk |
| `<leader>a[` | Normal | `:SaganiPrevHunk` | Jump cursor to previous agent edit hunk |

### User Commands Reference

| Command | Description |
|---|---|
| `:SaganiStatus` | Show Herdr session topology and target agent pane state |
| `:SaganiSend` | Capture visual selection (`v`, `V`, `<C-v>`) and send with prompt instruction |
| `:SaganiContext` | Capture visual selection code context and send directly to agent |
| `:SaganiDiff` | Capture active diff hunk/selection and send formatted review comment |
| `:SaganiSelectAgent [harness]` | Select target agent harness interactively or via argument |
| `:SaganiAskAgent [prompt]` | Ask general questions/prompts to an agent in a new pane |
| `:SaganiSelectHarness [harness]` | Alias for `:SaganiSelectAgent` |
| `:SaganiSelectTarget` | Prompt interactively to set or clear manual target pane ID |
| `:SaganiSpawnPane` | Spawn a Herdr pane and initialize the target agent harness |
| `:SaganiPrompt [text]` | Dispatch custom prompt text directly to target agent pane |
| `:SaganiReview` | Toggle side-by-side agent edit review diff split against baseline |
| `:SaganiAccept [hunk\|all]` | Accept edit hunk at cursor (or all pending edits in buffer) |
| `:SaganiReject [hunk\|all]` | Reject edit hunk at cursor (or revert all edits to baseline) |
| `:SaganiNextHunk` | Navigate cursor to next change hunk in buffer |
| `:SaganiPrevHunk` | Navigate cursor to previous change hunk in buffer |
| `:SaganiClearCache` | Clear persistent model cache on disk (`stdpath('state')/sagani/models.json`) |

### ❓ Troubleshooting Missing Keymaps

If typing `<leader>a...` does not trigger any commands after installing:

1. **Ensure `opts = {}` or `config = true` is in your plugin spec**:
   Lazy.nvim will **not** invoke `require("sagani").setup()` automatically unless `opts = {}` or `config = true` (or a custom `config` function) is specified:
   ```lua
   { "vikks/sagani.nvim", opts = {} }
   ```
2. **Order of `vim.g.mapleader`**:
   Ensure `vim.g.mapleader = " "` (or your preferred leader key) is defined **before** lazy.nvim or plugin setups in your `init.lua`. If `mapleader` is set after setup runs, Neovim maps `<leader>` to default `\` (backslash).
3. **Lazy-loading without `keys` declared**:
   If using `lazy = true` or `cmd = { ... }`, lazy.nvim delays loading the plugin until a trigger occurs. Declare `keys` in your spec or load on startup.

---

## 🧪 Testing & Verification

Run the headless test suite to verify module behavior:

```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```

---

## 📄 License

[MIT](LICENSE) © 2026
