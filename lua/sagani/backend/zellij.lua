--- ==============================================================================
--- Module: sagani.backend.zellij
---
--- Description:
---   Zellij multiplexer backend adapter for sagani.nvim. Connects Neovim workflows
---   with Zellij terminal multiplexer panes (`zellij action new-pane`) and character
---   writing (`zellij action write-chars`).
---
--- Responsibilities:
---   - Implement standard backend adapter interface for Zellij environment.
---   - Delegate Zellij action commands to sagani.backend.zellij.cli.
--- ==============================================================================

local cli = require("sagani.backend.zellij.cli")

local M = {
  name = "zellij",
  capabilities = {
    placements = { "floating", "pane" },
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
