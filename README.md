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
  -- Default target AI coding agent harness ("agy", "codex", "opencode", "hermes", etc.)
  target_agent = "agy",

  -- Automatically discover active target agent pane in herdr session
  auto_discover = true,

  -- Direction to automatically spawn agent pane if none exists ("left", "right", "bottom", "top", false)
  auto_spawn = "left",

  -- Manual target pane ID override (string like "w1:p2", or nil to use auto-discovery)
  pane_override = nil,

  -- General question / popup agent configuration
  ask_agent = {
    target_agent = nil, -- Target agent harness for general questions (if nil, prompts on first use & remembers for session)
    popup = true,       -- Open general question sessions in a Herdr popup pane
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
