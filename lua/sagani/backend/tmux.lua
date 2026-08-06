--- ==============================================================================
--- Module: sagani.backend.tmux
---
--- Description:
---   Tmux multiplexer backend adapter for sagani.nvim. Connects Neovim workflows
---   with Tmux panes (`tmux split-window`), popup windows (`tmux display-popup`),
---   and key sending (`tmux send-keys`).
---
--- Responsibilities:
---   - Implement standard backend adapter interface for Tmux environment.
---   - Delegate Tmux CLI commands to sagani.backend.tmux.cli.
--- ==============================================================================

local cli = require("sagani.backend.tmux.cli")

local M = {
  name = "tmux",
  capabilities = {
    placements = { "popup", "float", "pane" },
    float = true,
    split = false,
    tab = false,
    pane = { "left", "right", "top", "bottom" },
  },
}

function M.detect_env(runner)
  return cli.detect_env(runner)
end

function M.list_agents(runner)
  return cli.list_agents(runner)
end

function M.discover_target(opts)
  return cli.discover_target(opts)
end

function M.spawn_pane(opts)
  return cli.spawn_pane(opts)
end

function M.spawn_popup(opts)
  return cli.spawn_popup(opts)
end

function M.prompt_target(target_id, prompt_text, opts)
  return cli.prompt_target(target_id, prompt_text, opts)
end

function M.wait_for_ready(_, _)
  return true
end

return M
