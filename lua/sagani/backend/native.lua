--- ==============================================================================
--- Module: sagani.backend.native
---
--- Description:
---   Native Neovim backend adapter for sagani.nvim. Runs AI coding agents directly
---   inside Neovim split windows or centered floating popup windows without requiring
---   an external terminal multiplexer.
---
--- Responsibilities:
---   - Implement standard backend adapter interface (detect_env, discover_target, spawn_pane, spawn_popup, prompt_target).
---   - Delegate window creation and terminal job execution to sagani.backend.native.window.
--- ==============================================================================

local window = require("sagani.backend.native.window")

local M = {
  name = "native",
  capabilities = {
    ask = true,
    review = true,
    code = true,
    chat = true,
  },
}

function M.detect_env(runner)
  return window.detect_env(runner)
end

function M.list_agents(runner)
  return window.list_agents(runner)
end

function M.discover_target(opts)
  return window.discover_target(opts)
end

function M.spawn_pane(opts)
  return window.spawn_pane(opts)
end

function M.spawn_popup(opts)
  return window.spawn_popup(opts)
end

function M.prompt_target(target_id, prompt_text, opts)
  return window.prompt_target(target_id, prompt_text, opts)
end

function M.wait_for_ready(target_id, opts)
  return window.wait_for_ready(target_id, opts)
end

function M.reset_popup(agent)
  return window.reset_popup(agent)
end

return M
