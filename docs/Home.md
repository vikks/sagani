# Welcome to the sagani.nvim Wiki 🔮

[![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?style=flat-square&logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%20%2F%20JIT-2C2D72?style=flat-square&logo=lua&logoColor=white)](https://www.lua.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](https://github.com/vikks/sagani/blob/main/LICENSE)

**sagani.nvim** is a harness-agnostic, decoupled AI coding agent integration plugin for [Neovim](https://neovim.io) (tailored for [LazyVim](https://www.lazyvim.org/)). It bridges your buffer workflows directly with terminal multiplexers ([`herdr`](https://github.com/herdr/herdr), `tmux`, `zellij`, or native Neovim splits/floats) and AI agent harnesses (`agy`, `codex`, `opencode`, `hermes`, `gemini`, etc.).

---

## 📖 Wiki Navigation

Explore the comprehensive documentation pages:

- ⚙️ **[[Configuration Guide|configuration]]** — Complete `opts` schema reference (`tasks`, `backends`, `agents`, `providers`, `window_opts`, `review`, `notify`).
- 💡 **[[Examples & Recipes|examples]]** — Ready-to-use configuration blueprints for Herdr, Tmux, Zellij, OpenCode ACP, and local Ollama models.
- 🏛️ **[[System Architecture|architecture]]** — 4-layer decoupled architecture, ASCII layer diagrams, and backend adapter contracts.
- 📜 **[[Keymaps & Commands Reference|keymaps-commands]]** — Exhaustive list of user commands, keybindings, and floating popup modes.
- 🛠️ **[[Developer & Contributor Guide|contributing]]** — Zero-dependency headless unit test runner and contribution protocols.

---

## 🚀 Quick Start

Add to your `lazy.nvim` spec (`plugins/sagani.lua`):

```lua
return {
  "vikks/sagani.nvim",
  opts = {}, -- Uses defaults out of the box!
}
```

---

## ⌨️ Essential Keymaps (`<leader>a`)

| Keymap | Mode | Command | Description |
|---|---|---|---|
| `<leader>aa` | Normal / Visual | `:SaganiAskAgent` | Ask general question in floating popup or pane |
| `<leader>ab` | Normal | `:SaganiToggleBackend` | Toggle active backend transport between `auto` & `native` |
| `<leader>as` | Normal / Visual | `:SaganiStatus` / `:SaganiSend` | Show status / Send visual selection to agent |
| `<leader>ac` | Normal / Visual | `:SaganiSelectTarget` / `:SaganiContext` | Set target pane / Send code context to agent |
| `<leader>ad` | Normal / Visual | `:SaganiDiff` | Send diff review comment to agent |
| `<leader>ah` | Normal | `:SaganiSelectAgent` | Select target agent harness & model interactively |
| `<leader>ar` | Normal | `:SaganiReview` | Toggle side-by-side edit review diff view |
| `<leader>ay` / `<leader>ax` | Normal | `:SaganiAccept` / `:SaganiReject` | Accept or reject agent edit hunk / file changes |
