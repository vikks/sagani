# Configuration Guide — sagani.nvim

This document details all configuration options available in **sagani.nvim**.

---

## ⚙️ Complete Options Schema

Configure `sagani.nvim` via `opts` in Lazy.nvim or `require("sagani").setup(opts)`:

```lua
require("sagani").setup({
  -- 1. Global Window & Visual UI Styling Defaults
  window_opts = {
    width = 0.8,         -- Floating popup width (80% or integer columns)
    height = 0.8,        -- Floating popup height (80% or integer lines)
    border = "rounded",  -- Border style: "rounded", "single", "double", "solid", "shadow", "none"
    winblend = 0,        -- Floating window transparency (0-100)
    ratio = 0.3,         -- Pane split size ratio (30% split size)
  },

  -- 2. Backend Placements & Overrides (WHERE tasks get placed per multiplexer)
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
      ask = false,         -- Opts out of Herdr for 'ask' ➡️ falls back to native float!
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

  -- 3. Provider Configurations (LLM API credentials & display aliases)
  providers = {
    google = { api_key_env = "GEMINI_API_KEY", alias = "Google Gemini" },
    openai = { api_key_env = "OPENAI_API_KEY", alias = "OpenAI" },
    anthropic = { api_key_env = "ANTHROPIC_API_KEY", alias = "Anthropic" },
  },

  -- 4. Agent Registry (Logical Agent ID -> Harness Driver & Execution Command)
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

  -- 5. Task Configurations (WHAT agent harness runs & WHICH backend transport to use)
  tasks = {
    chat = "agy",
    ask = {
      agent = "agy",
      backend = "native", -- Always opens general questions in native Neovim floating popups
      instructions = "Answer the user's question concisely and accurately.",
    },
    review = {
      agent = "codex",    -- Omitted backend defaults to "auto"
      instructions = "Review the provided code changes and offer actionable feedback.",
    },
    code = {
      agent = "opencode", -- Omitted backend defaults to "auto"
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

## 🎯 Domain Breakdown

1. **`tasks` (WHAT runs)**: Controls agent assignment (`agent`), task instructions (`instructions`), and backend transport routing (`backend = "native"` / `"herdr"` / `"tmux"` / `"zellij"` / `"auto"`).
2. **`backends` (WHERE & HOW it renders)**: Controls UI placement specifiers (`ask = "popup"`, `review = "right-pane"`) and backend-specific visual overrides (`ratio`, `winblend`, `border`).
3. **`agents` (CLI Execution Registry)**: Controls binary commands (`cmd`), protocol drivers (`harness`), and background daemon ports (`port`).
4. **`providers` (API Credentials)**: Controls environment variable names (`api_key_env`) and human-readable aliases (`alias`).
