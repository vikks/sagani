# sagani.nvim 🔮

[![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?style=for-the-badge&logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%20%2F%20JIT-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

A harness-agnostic Neovim plugin (tailored for [LazyVim](https://www.lazyvim.org/)) that seamlessly connects your Neovim buffer workflows with terminal multiplexers ([`herdr`](https://github.com/herdr/herdr)) and AI coding agent harnesses (`agy`, `codex`, `opencode`, `hermes`, etc.).

---

## ⚡ Features

- **🌐 Harness-Agnostic Agent Switching**: Switch target agent harnesses (`agy`, `codex`, `opencode`, `hermes`, or custom CLI tools) on the fly via an interactive menu (`:SaganiSelectAgent`).
- **🧩 Automatic Topology Discovery**: Automatically detects your active `herdr` terminal environment (pane, tab, workspace IDs) and discovers active agent target panes.
- **✨ Visual Selection & Code Context**: Dispatch visual selections (`v`, `V`, `<C-v>`) formatted with file path, line range, syntax highlighting, and instruction prompts directly to your agent.
- **🔍 Structured Diff Review**: Review git diffs (via `diffview.nvim` or native Neovim diff split), calculate hunks, and submit formatted Markdown diff review comments to your agent.
- **⌨️ LazyVim & WhichKey Integration**: Includes pre-configured LazyVim plugin specs with optional `folke/which-key.nvim` menu grouping (`<leader>a` → `"Sagani"`).
- **🧪 Headless Test Suite**: Fully covered by a headless Neovim unit and integration test suite.

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
  -- Optional: Register WhichKey menu group
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "Sagani", mode = { "n", "v" } },
      },
    },
  },

  -- sagani.nvim
  {
    "username/sagani.nvim", -- Replace with your GitHub repo handle
    cmd = {
      "SaganiStatus",
      "SaganiSelectTarget",
      "SaganiSelectAgent",
      "SaganiSelectHarness",
      "SaganiSpawnPane",
      "SaganiPrompt",
      "SaganiSend",
      "SaganiContext",
      "SaganiDiff",
    },
    keys = {
      { "<leader>as", "<cmd>SaganiStatus<cr>", desc = "Sagani Status" },
      { "<leader>as", "<cmd>SaganiSend<cr>", desc = "Send Selection to Sagani", mode = "v" },
      { "<leader>ac", "<cmd>SaganiSelectTarget<cr>", desc = "Select Sagani Target Pane" },
      { "<leader>ac", "<cmd>SaganiContext<cr>", desc = "Send Context to Sagani", mode = "v" },
      { "<leader>ad", "<cmd>SaganiDiff<cr>", desc = "Send Diff Comment to Sagani", mode = { "n", "v" } },
      { "<leader>ap", "<cmd>SaganiPrompt<cr>", desc = "Send Prompt to Sagani", mode = { "n", "v" } },
      { "<leader>an", "<cmd>SaganiSpawnPane<cr>", desc = "Spawn New Sagani Pane", mode = "n" },
      { "<leader>aa", "<cmd>SaganiSelectAgent<cr>", desc = "Select Agent Harness", mode = "n" },
    },
    opts = {
      target_agent = "agy",
      auto_discover = true,
      auto_spawn = "left", -- Options: "right", "bottom", "left", "top", false
      startup_delay = 5000,
    },
    config = function(_, opts)
      require("sagani").setup(opts)
    end,
  },
}
```

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

  -- Timeout in milliseconds when waiting for agent CLI readiness
  startup_delay = 5000,

  -- Manual target pane ID override (string like "w1:p2", or nil to use auto-discovery)
  pane_override = nil,

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
| `<leader>aa` | Normal | `:SaganiSelectAgent` | Open picker to select agent harness (`agy`, `codex`, etc.) |

### User Commands Reference

| Command | Description |
|---|---|
| `:SaganiStatus` | Show Herdr session topology and target agent pane state |
| `:SaganiSend` | Capture visual selection (`v`, `V`, `<C-v>`) and send with prompt instruction |
| `:SaganiContext` | Capture visual selection code context and send directly to agent |
| `:SaganiDiff` | Capture active diff hunk/selection and send formatted review comment |
| `:SaganiSelectAgent [harness]` | Select target agent harness interactively or via argument |
| `:SaganiSelectHarness [harness]` | Alias for `:SaganiSelectAgent` |
| `:SaganiSelectTarget` | Prompt interactively to set or clear manual target pane ID |
| `:SaganiSpawnPane` | Spawn a Herdr pane and initialize the target agent harness |
| `:SaganiPrompt [text]` | Dispatch custom prompt text directly to target agent pane |

---

## 🧪 Testing & Verification

Run the headless test suite to verify module behavior:

```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```

---

## 📄 License

[MIT](LICENSE) © 2026
