# Configuration Guide — sagani.nvim

This document provides an exhaustive reference for all configuration options supported by **sagani.nvim**.

---

## ⚙️ Full Configuration Reference

Configure `sagani.nvim` via `opts` in Lazy.nvim or `require("sagani").setup(opts)`:

```lua
require("sagani").setup({
  -- 1. Global Transport & Behavior Settings
  backend = "auto",            -- Global default backend ("auto", "native", "herdr", "tmux", "zellij")
  auto_discover = true,        -- Auto-discover target agent panes in Herdr/Tmux/Zellij
  auto_spawn = false,          -- Auto-spawn new agent pane if none is active
  pane_override = nil,         -- Manual target pane ID override (e.g. "p1" or nil)
  default_keymaps = true,      -- Register default <leader>a... keybindings
  which_key = true,            -- Auto-register folke/which-key.nvim menu group

  -- 2. Global Window & UI Styling Defaults (HOW windows look)
  window_opts = {
    width = 0.8,               -- Floating popup width (80% editor width or columns)
    height = 0.8,              -- Floating popup height (80% editor height or lines)
    border = "rounded",        -- Border style: "rounded", "single", "double", "solid", "shadow", "none"
    winblend = 0,              -- Floating window transparency (0-100)
    ratio = 0.3,               -- Pane split ratio (30% split size)
  },

  -- 3. Backend Placements & Overrides (WHERE tasks get placed per multiplexer)
  backends = {
    native = {
      ask = "popup",           -- Native creates a Neovim floating popup for 'ask'
      review = "vsplit",       -- Native creates a vertical split for 'review'
      code = "vsplit",
      chat = "vsplit",
      border = "rounded",
      winblend = 0,
      split_direction = "vertical", -- "vertical" or "horizontal"
    },
    herdr = {
      ask = false,             -- Opts out of Herdr for 'ask' ➡️ falls back to native float!
      review = "right-pane",
      code = "right-pane",
      chat = "right-pane",
      ratio = 0.3,             -- Herdr pane split ratio (--ratio 0.3)
      auto_discover = true,
      auto_spawn = false,
    },
    tmux = {
      ask = "popup",           -- Spawns tmux display-popup for questions
      review = "right-pane",   -- Spawns right pane split in Tmux
      code = "right-pane",
      chat = "right-pane",
      width = "80%",           -- tmux display-popup -w 80%
      height = "80%",          -- tmux display-popup -h 80%
      border = "rounded",      -- tmux display-popup -b rounded
      split_direction = "right",
      target_pane = nil,
    },
    zellij = {
      ask = "floating",        -- Zellij floating pane for questions
      review = "right-pane",   -- Zellij right pane split for review
      code = "right-pane",
      chat = "right-pane",
      direction = "right",
    },
  },

  -- 4. Provider Configurations (LLM API credentials & display aliases)
  providers = {
    google = { api_key_env = "GEMINI_API_KEY", alias = "Google Gemini" },
    openai = { api_key_env = "OPENAI_API_KEY", alias = "OpenAI" },
    anthropic = { api_key_env = "ANTHROPIC_API_KEY", alias = "Anthropic" },
  },

  -- 5. Agent Registry (Logical Agent ID -> Harness Driver & Execution Command)
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
      port = 4096,              -- Background ACP HTTP daemon port
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

  -- 6. Task Configurations (WHAT agent harness runs & WHICH backend transport to use)
  tasks = {
    chat = "agy",
    ask = {
      agent = "agy",
      backend = "native",      -- Always opens general questions in native Neovim floating popups
      instructions = "Answer the user's question concisely and accurately.",
    },
    review = {
      agent = "codex",          -- Omitted backend defaults to "auto"
      instructions = "Review the provided code changes and offer actionable feedback.",
    },
    code = {
      agent = "opencode",       -- Omitted backend defaults to "auto"
      instructions = "Fulfill the user's coding request directly in the buffer.",
    },
  },

  -- 7. Operating Modes Settings (Review & Learn)
  modes = {
    review = {
      enabled = true,            -- Enable interactive edit review & accept/reject workflow
      auto_open = false,         -- Automatically open review view when agent modifies buffer on disk
      mode = "inline",           -- Review display style: "inline" (virtual text) or "split" (side-by-side)
    },
    learn = {
      enabled = false,           -- Enable pedagogical AI assistant explanations
      auto_open = false,         -- Automatically open explanation view when agent responds
      mode = "split",            -- Explanation display style: "split" (side-by-side) or "popup"
    },
  },

  -- 8. Notification Settings
  notify = {
    enabled = true,            -- Enable Neovim notifications
    title = "sagani.nvim",     -- Title header for notifications
  },
})
```

---

## 🗂️ Domain Configuration Matrix

| Table | Concern Domain | Key Responsibilities |
|---|---|---|
| `opts.tasks` | **Task Intent & Transport Routing** | Binds task types (`ask`, `code`, `review`, custom) to specific agents (`agent`) and transport backends (`backend = "native"` / `"auto"`). |
| `opts.backends` | **UI Placement & Window Layout** | Controls WHERE windows render (`ask = "popup"`, `review = "vsplit"`) and backend-specific visual styling (`ratio`, `winblend`, `border`). |
| `opts.agents` | **Executable Execution Registry** | Controls CLI binaries (`cmd`), protocol drivers (`harness`), daemon ports (`port`), and timeout settings (`timeout`). |
| `opts.modes` | **Operating Modes** | Configures Review Mode (`review`) for edit inspection diffs, and Learn Mode (`learn`) for pedagogical explanations. |
| `opts.providers` | **LLM API Credentials** | Controls environment variable names (`api_key_env`) and human-readable aliases (`alias`). |
| `opts.window_opts` | **Global UI Geometry Defaults** | Default fallback width, height, border, and transparency across all backends. |
