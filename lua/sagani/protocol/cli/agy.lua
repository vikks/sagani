local M = {
  name = "agy",
}

function M.build_command(prompt_text, agent_opts)
  agent_opts = type(agent_opts) == "table" and agent_opts or {}
  local cmd = { "agy", "-p", prompt_text, "--output-format", "text" }

  -- Only pass --model if explicitly specified and not generic placeholder strings like "pro" or "flash"
  if agent_opts.model and agent_opts.model ~= "" then
    local m = tostring(agent_opts.model):lower()
    if m ~= "pro" and m ~= "flash" and m ~= "auto" then
      table.insert(cmd, "--model")
      table.insert(cmd, agent_opts.model)
    end
  end

  if agent_opts.effort and (agent_opts.effort == "low" or agent_opts.effort == "medium" or agent_opts.effort == "high") then
    table.insert(cmd, "--effort")
    table.insert(cmd, agent_opts.effort)
  end

  return cmd
end

function M.execute(prompt_text, agent_opts, callback, opts)
  opts = type(opts) == "table" and opts or {}
  local cmd = M.build_command(prompt_text, agent_opts)

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    callback("### Mock CLI Response (AGY)\n\nHere is the response.", nil)
    return
  end

  if opts.runner then
    local out_text, code = opts.runner(cmd)
    if code == 0 then
      callback(out_text or "No output returned", nil)
    else
      callback(nil, string.format("AGY CLI execution failed (code %d): %s", code, out_text or ""))
    end
    return
  end

  if vim.fn.executable("agy") == 0 then
    callback(nil, "CLI executable 'agy' not found in PATH")
    return
  end

  vim.system(cmd, { text = true, stdin = "" }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        local out = (obj.stdout and obj.stdout ~= "") and obj.stdout or (obj.stderr or "")
        callback(out, nil)
      else
        callback(nil, string.format("AGY CLI request failed: %s", obj.stderr or obj.stdout or ("code " .. obj.code)))
      end
    end)
  end)
end

return M
