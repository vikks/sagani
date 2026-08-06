# sagani.nvim 🔮

[![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?style=for-the-badge&logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%20%2F%20JIT-2C2D72?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org)
[![Tests](https://img.shields.io/badge/Tests-559%20Passed-success?style=for-the-badge&logo=github)](tests/run_tests.lua)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

**sagani.nvim** is a harness-agnostic, decoupled AI coding agent integration plugin for [Neovim](https://neovim.io) (tailored for [LazyVim](https://www.lazyvim.org/)). It bridges your buffer workflows directly with terminal multiplexers ([`herdr`](https://github.com/herdr/herdr), `tmux`, `zellij`, or native Neovim splits/floats) and AI agent harnesses (`agy`, `codex`, `opencode`, `hermes`, `gemini`, etc.).

---

## ✨ Features

- 🖥️ **Multi-Backend Transport Routing**: Auto-detects terminal environment order (**Herdr → Tmux → Zellij → Native**) or toggle on the fly (`<leader>ab`).
- 📌 **Floating Popup & Single-Keypress Pin Mode**: Ask general questions (`<leader>aa`), then press `p` to instantly promote floats to splits (`[h]`, `[l]`, `[k]`, `[j]`) or tabs (`[t]`).
- 🤖 **100% Dynamic Model Discovery**: Queries models live from agent CLIs and ACP daemons with intelligent reasoning effort filtering (`low`, `medium`, `high`).
- 🔍 **Interactive Edit Review & Hunk Acceptance**: Review agent edits side-by-side (`:SaganiReview`), navigate hunks (`]c` / `[c`), and accept (`<leader>ay`) or reject (`<leader>ax`) changes.
- 📐 **Visual Context & Diff Formatting**: Format characterwise, linewise, or blockwise visual selections with syntax highlighting and file range metadata (`@[abs_path#L10-L20]`).

---

## 🚀 Quick Start

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "vikks/sagani.nvim",
  opts = {}, -- Uses defaults: ask in native float, code/review in active multiplexer
}
```

---

## ⌨️ Essential Keymaps (`<leader>a`)

| Keymap | Mode | Command | Description |
|---|---|---|---|
| `<leader>aa` | Normal / Visual | `:SaganiAskAgent` | Ask general question in floating popup or pane |
| `<leader>ab` | Normal | `:SaganiToggleBackend` | Toggle active backend transport between `auto` & `native` |
| `<leader>as` | Normal / Visual | `:SaganiStatus` / `:SaganiSend` | Show status / Send visual selection to agent |
| `<leader>ac` | Normal / Visual | `:SaganiSelectTarget` / `:SaganiContext` | Select target pane interactively / Send code context to agent |
| `<leader>ad` | Normal / Visual | `:SaganiDiff` | Send diff review comment to agent |
| `<leader>ah` | Normal | `:SaganiSelectAgent` | Select target agent harness & model interactively |
| `<leader>ar` | Normal | `:SaganiReview` | Toggle side-by-side edit review diff view |
| `<leader>ay` / `<leader>ax` | Normal | `:SaganiAccept` / `:SaganiReject` | Accept or reject agent edit hunk / file changes |

---

## 📚 Documentation & Guides

For detailed configuration schemas, system architecture blueprints, and developer guides, explore the `docs/` folder:

- ⚙️ **[Configuration Guide](docs/configuration.md)** — Detailed `opts` schema (`tasks`, `backends`, `agents`, `providers`, `window_opts`).
- 💡 **[Examples & Recipes](docs/examples.md)** — Ready-to-use configuration recipes for Herdr, Tmux, Zellij, OpenCode ACP, and local Ollama.
- 🏛️ **[System Architecture](docs/architecture.md)** — 4-layer decoupled architecture and backend adapter contracts.
- 📜 **[Keymaps & Commands Reference](docs/keymaps-commands.md)** — Complete list of user commands and popup keybindings.
- 🛠️ **[Developer & Contributor Guide](docs/contributing.md)** — Headless test suite runner and open-source PR workflows.

---

## 📄 License

[MIT](LICENSE) © 2026
