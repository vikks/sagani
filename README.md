# sagani.nvim ("Sagani")

A harness-agnostic Neovim plugin (tailored for [LazyVim](https://www.lazyvim.org/)) that seamlessly connects Neovim with terminal multiplexers ([`herdr`](https://github.com/herdr/herdr)) and AI coding agent harnesses (`agy`, `codex`, `opencode`, `hermes`, etc.).

---

## Overview

**sagani.nvim** provides a bridge between Neovim buffer workflows and terminal multiplexers running AI coding agents. Whether you are using `agy`, `codex`, `opencode`, `hermes`, or custom CLI agent harnesses, Sagani allows you to send code context, visual selections, prompts, and diff review comments directly into active agent panes without leaving your editor.

### Architecture

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
               | Target Agent Harness     |
               | (agy, codex, opencode,   |
               |  hermes in herdr pane)   |
               +--------------------------+
```

---

## Features

- **Harness-Agnostic Switching**: Seamlessly change your target agent harness (`agy`, `codex`, `opencode`, `hermes`, or custom agents) at runtime via interactive menu or command.
- **Multiplexer Topology Discovery**: Automatically detects `herdr` terminal environment details (pane ID, tab ID, workspace ID) and finds ready agent target panes via Tab $\rightarrow$ Workspace $\rightarrow$ CWD $\rightarrow$ Fallback.
- **Visual Selection & Context Dispatch**: Dispatch visual selections (`v`, `V`, `<C-v>`) formatted with file path, line range, filetype, and user instructions directly to the target agent.
- **Structured Diff Review**: Review git diffs (via `diffview.nvim` or Neovim split diffs), calculate hunks using `vim.diff()`, and submit structured Markdown diff feedback blocks with reviewer comments to the active agent.
- **LazyVim & WhichKey Native Integration**: Includes pre-configured LazyVim plugin specs with optional `folke/which-key.nvim` menu grouping (`<leader>a` $\rightarrow$ `"Sagani"`).
- **Headless Test Suite**: Fully covered by a headless Neovim test suite for robust validation across all Lua modules.

---

## Requirements

- **Neovim**: `>= 0.9.0`
- **Terminal Multiplexer**: `herdr` CLI installed in `PATH`
- **AI Agent Harness**: One or more installed agent harnesses (`agy`, `codex`, `opencode`, `hermes`, etc.)
- **(Optional)**: `folke/which-key.nvim` for keymap descriptions and menu grouping

---

## Installation & LazyVim Specification

Place the plugin specification in your LazyVim plugin directory (e.g., `lua/plugins/sagani.lua` or `plugins/sagani.lua`):

```lua
local plugin_dir = vim.fn.expand("~/CreatorSpace/Coder/OpenSource/NeovimPlugins/sagani.nvim")
if vim.fn.isdirectory(plugin_dir) == 0 then
  plugin_dir = "."
end

return {
  -- Optional WhichKey integration for Sagani keymap group
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "Sagani", mode = { "n", "v" } },
      },
    },
  },

  -- sagani.nvim main plugin specification
  {
    "sagani.nvim",
    dir = plugin_dir,
    name = "sagani.nvim",
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
      { "<leader>at", "<cmd>SaganiSend<cr>", desc = "Send Selection to Sagani", mode = "v" },
      { "<leader>an", "<cmd>SaganiSpawnPane<cr>", desc = "Spawn New Sagani Pane", mode = "n" },
      { "<leader>ah", "<cmd>SaganiSelectAgent<cr>", desc = "Select Agent Harness", mode = "n" },
      { "<leader>aa", "<cmd>SaganiSelectAgent<cr>", desc = "Select Agent Harness", mode = "n" },
    },
    opts = {
      target_agent = "agy",
      auto_discover = true,
      startup_delay = 5000,
      auto_spawn = "left", -- Options: "right", "bottom", "down", "left", false, true
    },
    config = function(_, opts)
      require("sagani").setup(opts)
    end,
  },
}
```

---

## Configuration & Setup Options

Configure **sagani.nvim** via `require("sagani").setup(opts)`:

```lua
require("sagani").setup({
  -- Default target AI coding agent harness ("agy", "codex", "opencode", "hermes", etc.)
  target_agent = "agy",

  -- Automatically discover active target agent pane in herdr session
  auto_discover = true,

  -- Direction to automatically spawn agent pane if none exists ("left", "right", "bottom", "down", true, false)
  auto_spawn = "left",

  -- Timeout in milliseconds when waiting for agent CLI readiness
  startup_delay = 5000,

  -- Manual target pane ID override (set to string like "pane-123", or nil to use auto-discovery)
  pane_override = nil,

  -- Notification configuration
  notify = {
    enabled = true,
    title = "sagani.nvim",
  },
})
```

---

## Keymaps & WhichKey Integration

### Keymaps Reference

| Keymap | Modes | User Command | Description |
|---|---|---|---|
| `<leader>as` | Normal | `:SaganiStatus` | Display Herdr session status, topology, and active target agent pane |
| `<leader>as` | Visual | `:SaganiSend` | Send current visual selection with instruction prompt to target agent |
| `<leader>ac` | Normal | `:SaganiSelectTarget` | Set manual Herdr target pane ID override |
| `<leader>ac` | Visual | `:SaganiContext` | Send visual selection code context to target agent |
| `<leader>ad` | Normal / Visual | `:SaganiDiff` | Send diff review comment & Markdown diff block to target agent |
| `<leader>ap` | Normal / Visual | `:SaganiPrompt` | Send custom prompt or input prompt to target agent |
| `<leader>at` | Visual | `:SaganiSend` | Send visual selection to target agent (Visual mode alias for `<leader>as`) |
| `<leader>an` | Normal | `:SaganiSpawnPane` | Spawn a new Herdr pane for the active target agent harness |
| `<leader>ah` | Normal | `:SaganiSelectAgent` | Open interactive picker to select agent harness (`agy`, `codex`, etc.) |
| `<leader>aa` | Normal | `:SaganiSelectAgent` | Alias for selecting target agent harness |

### WhichKey Integration

When `folke/which-key.nvim` is installed, **sagani.nvim** automatically registers the `<leader>a` key prefix under the **"Sagani"** menu group:

```lua
opts = {
  spec = {
    { "<leader>a", group = "Sagani", mode = { "n", "v" } },
  },
}
```

---

## User Commands Reference

| Command | Description |
|---|---|
| `:Sagani` | Base command and interface entrypoint for Sagani plugin status and options. |
| `:SaganiStatus` | Show Herdr session topology (Herdr active/inactive, Pane ID, Tab ID, Workspace ID) and target agent pane state. |
| `:SaganiSend` | Capture visual selection (`v`, `V`, `<C-v>`) and prompt user for instructions, sending formatted Markdown to the agent. |
| `:SaganiContext` | Capture visual selection code context (file path, line range, language) and send to target agent pane without requiring extra prompt text. |
| `:SaganiDiff` | Capture active diff hunk or visual selection diff, prompt for reviewer comment, and dispatch formatted Markdown diff block to agent. |
| `:SaganiHunk` | Target current diff hunk at cursor for diff review commentary and dispatch to agent. |
| `:SaganiSelectAgent [harness]` | Select target AI agent harness interactively (`agy`, `codex`, `opencode`, `hermes`, etc.) or pass directly as argument. |
| `:SaganiSelectHarness [harness]` | Alias for `:SaganiSelectAgent`. |
| `:SaganiSelectTarget` | Prompt interactively to set or clear manual Herdr target pane ID override. |
| `:SaganiSpawnPane` | Spawn a vertical/horizontal Herdr pane and initialize the target agent harness. |
| `:SaganiPrompt [text]` | Dispatch custom prompt text directly to target agent pane, or prompt interactively if argument is empty. |
| `:SaganiToggle` | Toggle target agent pane focus or interactive agent connection state. |

---

## Testing & Verification

**sagani.nvim** includes a headless Neovim test suite covering topology discovery, visual selection formatting, diff calculation, notification fallbacks, and plugin spec integration.

Run the test suite using Neovim in headless mode:

```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```

### Test Suite Modules

- `tests/test_topology.lua` — Tests `HERDR_ENV` detection, JSON parsing, agent discovery, and pane spawning.
- `tests/test_selection.lua` — Tests visual selection extraction across characterwise, linewise, and blockwise modes.
- `tests/test_diff.lua` — Tests hunk detection and diff review comment generation.
- `tests/test_format.lua` — Tests Markdown prompt construction and diff block formatting.
- `tests/test_plugin_spec.lua` — Tests LazyVim plugin spec structure, WhichKey integration, commands, and options setup.

---

## License

MIT License. See project repository for details.
