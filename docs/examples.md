# Examples & Configuration Recipes — sagani.nvim

This document provides ready-to-use configuration recipes for common workflows, developer environments, and multi-model setups.

---

## 📋 Table of Contents

1. [Standalone Neovim (No Terminal Multiplexer)](#1-standalone-neovim-no-terminal-multiplexer)
2. [Herdr Terminal Multiplexer Integration](#2-herdr-terminal-multiplexer-integration)
3. [Tmux Terminal Multiplexer Integration](#3-tmux-terminal-multiplexer-integration)
4. [Zellij Terminal Multiplexer Integration](#4-zellij-terminal-multiplexer-integration)
5. [OpenCode HTTP ACP Background Daemon Workflow](#5-opencode-http-acp-background-daemon-workflow)
6. [Multi-Model Task Delegation (Gemini + Codex + OpenCode)](#6-multi-model-task-delegation-gemini--codex--opencode)
7. [Offline / Local Model Setup (Ollama / LocalAI)](#7-offline--local-model-setup-ollama--localai)

---

## 1. Standalone Neovim (No Terminal Multiplexer)

If you use Neovim directly inside standard terminal emulators (Ghostty, Alacritty, Kitty, WezTerm, iTerm2) without a multiplexer, force `backend = "native"` globally:

```lua
return {
  "vikks/sagani.nvim",
  opts = {
    backend = "native", -- Force all tasks to use native Neovim floats & splits
    window_opts = {
      width = 0.85,
      height = 0.85,
      border = "rounded",
      winblend = 10,
    },
    backends = {
      native = {
        ask = "popup",     -- Floating popup for general questions
        code = "vsplit",    -- Vertical split for coding agents
        review = "vsplit",  -- Vertical split for diff reviews
      },
    },
  },
}
```

---

## 2. Herdr Terminal Multiplexer Integration

Herdr automatically auto-discovers target agent panes across tabs, workspaces, and working directories. Enable `auto_spawn = true` to automatically spawn new Herdr agent panes when none exist:

```lua
return {
  "vikks/sagani.nvim",
  opts = {
    backend = "auto",
    auto_discover = true,
    auto_spawn = true, -- Auto-split right pane in Herdr if agent is not running
    backends = {
      herdr = {
        ask = false,         -- Use native floating popup for ask questions
        code = "right-pane",  -- Split 30% right pane in Herdr for coding
        review = "right-pane",
        ratio = 0.35,        -- 35% right split width
      },
    },
  },
}
```

---

## 3. Tmux Terminal Multiplexer Integration

Use `tmux display-popup` for interactive ask questions while routing code generation to a dedicated right pane split:

```lua
return {
  "vikks/sagani.nvim",
  opts = {
    backend = "tmux",
    backends = {
      tmux = {
        ask = "popup",       -- Spawns tmux display-popup -w 80% -h 80%
        code = "right-pane",  -- Spawns right pane split in current Tmux window
        review = "right-pane",
        width = "80%",
        height = "80%",
        border = "rounded",
      },
    },
  },
}
```

---

## 4. Zellij Terminal Multiplexer Integration

Use Zellij floating action panes for general Q&A and right-side pane splits for coding:

```lua
return {
  "vikks/sagani.nvim",
  opts = {
    backend = "zellij",
    backends = {
      zellij = {
        ask = "floating",    -- Zellij action new-pane -f
        code = "right-pane",  -- Zellij action new-pane -d right
        review = "right-pane",
        direction = "right",
      },
    },
  },
}
```

---

## 5. OpenCode HTTP ACP Background Daemon Workflow

Run OpenCode as an HTTP ACP daemon on port `4096`. Sagani automatically manages process lifecycles, filters out internal reasoning/thought streams, and provides multi-turn sessions:

```lua
return {
  "vikks/sagani.nvim",
  opts = {
    agents = {
      opencode = {
        harness = "opencode",
        cmd = { "opencode" },
        port = 4096,
        name = "Opencode HTTP Daemon",
      },
    },
    tasks = {
      ask = {
        agent = "opencode",
        model = "deepseek-v4-flash-free",
        backend = "native",
      },
      code = {
        agent = "opencode",
        model = "claude-3-5-sonnet",
      },
    },
  },
}
```

---

## 6. Multi-Model Task Delegation (Gemini + Codex + OpenCode)

Delegate fast Q&A to Gemini Flash, deep code reviews to OpenAI Codex o3, and buffer edits to OpenCode DeepSeek:

```lua
return {
  "vikks/sagani.nvim",
  opts = {
    tasks = {
      ask = {
        agent = "agy",
        model = "gemini-2.5-flash",
        effort = "low",
        backend = "native",
        instructions = "Provide concise, direct answers.",
      },
      review = {
        agent = "codex",
        model = "o3-mini",
        effort = "high",
        instructions = "Perform a thorough security and performance code review.",
      },
      code = {
        agent = "opencode",
        model = "deepseek-r1",
        instructions = "Fulfill buffer code modifications accurately.",
      },
    },
  },
}
```

---

## 7. Offline / Local Model Setup (Ollama / LocalAI)

Register custom local CLI agent harnesses running offline models via Ollama or llama.cpp:

```lua
return {
  "vikks/sagani.nvim",
  opts = {
    agents = {
      ollama_coder = {
        agent = "cli",
        cmd = { "ollama", "run", "qwen2.5-coder:32b" },
        name = "Ollama Qwen Coder",
        is_local = true,
      },
    },
    tasks = {
      code = {
        agent = "ollama_coder",
      },
      ask = {
        agent = "ollama_coder",
        backend = "native",
      },
    },
  },
}
```

---

## 8. Pedagogical Learn Mode Workflow

Enable Learn Mode to turn Sagani into an educational programming assistant. Injects educational concepts, syntax breakdowns, and architectural trade-offs into prompt payloads:

```lua
return {
  "vikks/sagani.nvim",
  opts = {
    modes = {
      review = {
        enabled = true,
        auto_open = false,
        mode = "inline",
      },
      learn = {
        enabled = true,        -- Enable educational Learn Mode
        mode = "split",         -- Render explanation in side-by-side split
      },
    },
  },
}
```
Toggle between modes at runtime with `<leader>am` (Mode Switcher Menu), `<leader>aml` (Toggle Learn Mode), or `<leader>ar` (Toggle Review Mode).
