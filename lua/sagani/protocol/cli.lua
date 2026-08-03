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

function M.execute(harness, prompt_text, agent_opts, callback, opts)
  local agent = M.get_agent(harness)
  agent.execute(prompt_text, agent_opts, callback, opts)
end

return M
