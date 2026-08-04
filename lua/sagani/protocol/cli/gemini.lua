local M = {
  name = "gemini",
}

function M.list_models_async(opts, callback)
  opts = type(opts) == "table" and opts or {}
  local models = { "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-lite" }
  callback(models)
end

function M.list_models(_)
  return { "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-lite" }
end

function M.build_command(prompt_text, agent_opts)
  agent_opts = type(agent_opts) == "table" and agent_opts or {}
  local cmd = { "gemini", "-p", prompt_text, "-o", "text" }

  local raw_model = agent_opts.model
  if raw_model and type(raw_model) == "string" and raw_model ~= "" then
    if not raw_model:find("%s") and not raw_model:find("%(") and not raw_model:find("Thinking") then
      table.insert(cmd, "-m")
      table.insert(cmd, raw_model)
    end
  end

  return cmd
end

function M.execute(prompt_text, agent_opts, callback, opts)
  opts = type(opts) == "table" and opts or {}
  local cmd = M.build_command(prompt_text, agent_opts)

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    callback("### Mock CLI Response (GEMINI)\n\nHere is the response.", nil)
    return
  end

  if opts.runner then
    local out_text, code = opts.runner(cmd)
    if code == 0 then
      callback(out_text or "No output returned", nil)
    else
      callback(nil, string.format("Gemini CLI execution failed (code %d): %s", code, out_text or ""))
    end
    return
  end

  if vim.fn.executable("gemini") == 0 then
    callback(nil, "CLI executable 'gemini' not found in PATH")
    return
  end

  vim.system(cmd, { text = true, stdin = "" }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        local out = (obj.stdout and obj.stdout ~= "") and obj.stdout or (obj.stderr or "")
        callback(out, nil)
      else
        callback(nil, string.format("Gemini CLI request failed: %s", obj.stderr or obj.stdout or ("code " .. obj.code)))
      end
    end)
  end)
end

return M
