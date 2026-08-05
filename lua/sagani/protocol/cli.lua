--- ==============================================================================
--- Module: sagani.protocol.cli
---
--- Description:
---   CLI protocol driver registry and command builder for sagani.nvim. Maps harness
---   identifiers (`agy`, `codex`, `opencode`, `hermes`, `gemini`) to their respective
---   CLI driver submodules, providing CLI command array construction and dynamic model discovery.
---
--- Responsibilities:
---   - Register CLI driver adapters under protocol/cli/.
---   - Construct shell command arrays for multiplexer pane spawning.
---   - Provide query_models dynamic model discovery API.
--- ==============================================================================

local M = {
  _agents = {},
}

function M.get_agent(harness)
  harness = (harness or "agy"):lower()
  if harness == "antigravity" then harness = "agy" end
  if harness == "gemini-cli" then harness = "gemini" end

  if M._agents[harness] then
    return M._agents[harness]
  end

  local ok, agent_mod = pcall(require, "sagani.protocol.cli." .. harness)
  if ok and agent_mod then
    M._agents[harness] = agent_mod
    return agent_mod
  end

  -- Generic fallback agent
  return {
    name = harness,
    build_command = function(prompt_text, _)
      return { harness, "prompt", prompt_text }
    end,
    execute = function(prompt_text, agent_opts, callback, opts)
      opts = type(opts) == "table" and opts or {}
      local cmd = { harness, "prompt", prompt_text }
      if opts.runner then
        local out_text, code = opts.runner(cmd)
        if code == 0 then callback(out_text or "", nil) else callback(nil, "CLI error " .. code) end
        return
      end
      vim.system(cmd, { text = true, stdin = "" }, function(obj)
        vim.schedule(function()
          if obj.code == 0 then callback(obj.stdout or "", nil) else callback(nil, obj.stderr or "Error") end
        end)
      end)
    end,
  }
end

function M.build_command(harness, prompt_text, agent_opts)
  local agent = M.get_agent(harness)
  return agent.build_command(prompt_text, agent_opts)
end

function M.list_models(harness, opts)
  local agent = M.get_agent(harness)
  if agent and agent.list_models then
    return agent.list_models(opts)
  end
  return nil
end

function M.list_models_async(harness, opts, callback)
  local agent = M.get_agent(harness)
  if agent and agent.list_models_async then
    agent.list_models_async(opts, callback)
  elseif agent and agent.list_models then
    callback(agent.list_models(opts))
  else
    callback(nil)
  end
end

function M.execute(harness, prompt_text, agent_opts, callback, opts)
  local agent = M.get_agent(harness)
  agent.execute(prompt_text, agent_opts, callback, opts)
end

return M
