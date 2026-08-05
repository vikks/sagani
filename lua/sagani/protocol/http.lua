--- ==============================================================================
--- Module: sagani.protocol.http
---
--- Description:
---   HTTP REST protocol driver registry for sagani.nvim. Maps agent harnesses to
---   HTTP REST API adapters (e.g. OpenCode server API) for sending prompts over HTTP endpoints.
---
--- Responsibilities:
---   - Register HTTP protocol adapters per harness.
---   - Provide get_agent lookup for HTTP drivers.
--- ==============================================================================

local M = {
  _agents = {},
}

function M.get_agent(harness)
  harness = (harness or "opencode"):lower()
  if M._agents[harness] then
    return M._agents[harness]
  end

  local ok, agent_mod = pcall(require, "sagani.protocol.http." .. harness)
  if ok and agent_mod then
    M._agents[harness] = agent_mod
    return agent_mod
  end

  return nil
end

function M.ensure_server_async(port, progress_cb, on_ready)
  local agent = M.get_agent("opencode")
  if agent and agent.ensure_server_async then
    agent.ensure_server_async(port, progress_cb, on_ready)
  else
    on_ready(false)
  end
end

function M.execute(prompt_text, agent_opts, callback, progress_cb, session_id)
  local agent = M.get_agent("opencode")
  if agent and agent.execute then
    return agent.execute(prompt_text, agent_opts, callback, progress_cb, session_id)
  end
  return false
end

return M
