local M = {
  name = "hermes",
}

function M.build_command(prompt_text, agent_opts)
  return { "hermes", "prompt", prompt_text }
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
