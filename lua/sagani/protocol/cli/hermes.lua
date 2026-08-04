local M = {
  name = "hermes",
}

function M.list_models_async(opts, callback)
  opts = type(opts) == "table" and opts or {}
  local models = { "hermes-3-llama-3.1-405b", "hermes-3-llama-3.1-70b" }
  callback(models)
end

function M.list_models(_)
  return { "hermes-3-llama-3.1-405b", "hermes-3-llama-3.1-70b" }
end

function M.build_command(prompt_text, agent_opts)
  agent_opts = type(agent_opts) == "table" and agent_opts or {}
  local cmd = { "hermes", "prompt" }
  if agent_opts.model and agent_opts.model ~= "" then
    table.insert(cmd, "-m")
    table.insert(cmd, agent_opts.model)
  end
  table.insert(cmd, prompt_text)
  return cmd
end

function M.execute(prompt_text, agent_opts, callback, opts)
  opts = type(opts) == "table" and opts or {}
  local cmd = M.build_command(prompt_text, agent_opts)

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    callback("### Mock CLI Response (HERMES)\n\nHere is the response.", nil)
    return
  end

  if opts.runner then
    local out_text, code = opts.runner(cmd)
    if code == 0 then
      callback(out_text or "No output returned", nil)
    else
      callback(nil, string.format("Hermes CLI execution failed (code %d): %s", code, out_text or ""))
    end
    return
  end

  if vim.fn.executable("hermes") == 0 then
    callback(nil, "CLI executable 'hermes' not found in PATH")
    return
  end

  vim.system(cmd, { text = true, stdin = "" }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        local out = (obj.stdout and obj.stdout ~= "") and obj.stdout or (obj.stderr or "")
        callback(out, nil)
      else
        callback(nil, string.format("Hermes CLI request failed: %s", obj.stderr or obj.stdout or ("code " .. obj.code)))
      end
    end)
  end)
end

return M
