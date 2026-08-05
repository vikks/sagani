--- ==============================================================================
--- Module: sagani.protocol.cli.opencode
---
--- Description:
---   OpenCode CLI harness driver for sagani.nvim. Constructs `opencode` CLI subshell command
---   arrays and queries live available models (`opencode models`).
---
--- Responsibilities:
---   - Construct command line arrays for `opencode` execution.
---   - Query live models via `opencode models` CLI.
--- ==============================================================================

local M = {
  name = "opencode",
}

function M.build_command(prompt_text, agent_opts)
  agent_opts = type(agent_opts) == "table" and agent_opts or {}
  local cmd = { "opencode", "run" }

  if agent_opts.model and agent_opts.model ~= "" then
    table.insert(cmd, "-m")
    table.insert(cmd, agent_opts.model)
  end

  if agent_opts.effort and agent_opts.effort ~= "" then
    table.insert(cmd, "--variant")
    table.insert(cmd, agent_opts.effort)
  end

  table.insert(cmd, prompt_text)
  return cmd
end

function M.list_models_async(opts, callback)
  opts = type(opts) == "table" and opts or {}
  if _G.RUNNING_TEST_SUITE and not opts.runner then
    callback({ "google/gemini-2.5-pro", "google/gemini-2.5-flash", "opencode/deepseek-v4-flash-free" })
    return
  end

  local cache = require("sagani.cache")
  local cached = cache.get_cached_models("opencode", opts.cache_ttl)
  if cached then
    callback(cached)
    return
  end

  if opts.runner then
    local models = M.list_models(opts)
    callback(models)
    return
  end

  if vim.fn.executable("opencode") == 0 then
    callback(nil)
    return
  end

  local notify = require("sagani.notify")
  notify.info("Fetching available models from OpenCode CLI...", opts)

  local cmd = { "opencode", "models" }
  vim.system(cmd, { text = true, stdin = "" }, function(obj)
    vim.schedule(function()
      local models = {}
      local out_text = (obj.code == 0) and obj.stdout or nil
      if out_text and out_text ~= "" then
        for line in out_text:gmatch("[^\r\n]+") do
          local trimmed = vim.trim(line)
          if trimmed ~= "" and not trimmed:find("^Available") and not trimmed:find("^Usage") then
            table.insert(models, trimmed)
          end
        end
      end

      if #models > 0 then
        cache.set_cached_models("opencode", models)
        callback(models)
      else
        callback(nil)
      end
    end)
  end)
end

function M.list_models(opts)
  opts = type(opts) == "table" and opts or {}
  local cache = require("sagani.cache")
  local cached = cache.get_cached_models("opencode", opts.cache_ttl)
  if cached then return cached end

  local cmd = { "opencode", "models" }
  local out_text = nil
  if opts.runner then
    local res, code = opts.runner(cmd)
    if code == 0 then out_text = res end
  elseif vim.fn.executable("opencode") == 1 then
    local res = vim.system(cmd, { text = true, stdin = "" }):wait()
    if res and res.code == 0 then out_text = res.stdout end
  end

  local models = {}
  if out_text and out_text ~= "" then
    for line in out_text:gmatch("[^\r\n]+") do
      local trimmed = vim.trim(line)
      if trimmed ~= "" and not trimmed:find("^Available") then
        table.insert(models, trimmed)
      end
    end
  end

  if #models > 0 then
    cache.set_cached_models("opencode", models)
    return models
  end
  return nil
end

function M.execute(prompt_text, agent_opts, callback, opts)
  opts = type(opts) == "table" and opts or {}
  local cmd = M.build_command(prompt_text, agent_opts)

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    callback("### Mock CLI Response (OPENCODE)\n\nHere is the response.", nil)
    return
  end

  if opts.runner then
    local out_text, code = opts.runner(cmd)
    if code == 0 then
      callback(out_text or "No output returned", nil)
    else
      callback(nil, string.format("OpenCode CLI execution failed (code %d): %s", code, out_text or ""))
    end
    return
  end

  vim.system(cmd, { text = true, stdin = "" }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        local out = (obj.stdout and obj.stdout ~= "") and obj.stdout or (obj.stderr or "")
        callback(out, nil)
      else
        callback(nil, string.format("OpenCode CLI request failed: %s", obj.stderr or obj.stdout or ("code " .. obj.code)))
      end
    end)
  end)
end

return M
