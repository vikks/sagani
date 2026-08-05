--- ==============================================================================
--- Module: sagani.protocol.cli.codex
---
--- Description:
---   Codex CLI harness driver for sagani.nvim. Constructs `codex` CLI subshell command
---   arrays and queries local disk model cache registry (`~/.codex/models_cache.json`).
---
--- Responsibilities:
---   - Construct command line arrays for `codex` execution.
---   - Query available models from `~/.codex/models_cache.json`.
--- ==============================================================================

local M = {
  name = "codex",
}

function M.list_models_async(opts, callback)
  opts = type(opts) == "table" and opts or {}
  if _G.RUNNING_TEST_SUITE and not opts.runner then
    callback({ "gpt-5.6-luna", "o3", "o1", "gpt-4o" })
    return
  end

  local cache = require("sagani.cache")
  local cached = cache.get_cached_models("codex", opts.cache_ttl)
  if cached then
    callback(cached)
    return
  end

  local models = {}
  local codex_cache_file = vim.fn.expand("~/.codex/models_cache.json")
  if vim.fn.filereadable(codex_cache_file) == 1 then
    local content = table.concat(vim.fn.readfile(codex_cache_file), "\n")
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" and type(data.models) == "table" then
      for _, m in ipairs(data.models) do
        if type(m) == "table" and m.slug then
          table.insert(models, m.slug)
        end
      end
    end
  end

  if #models > 0 then
    cache.set_cached_models("codex", models)
    callback(models)
  else
    callback(nil)
  end
end

function M.list_models(opts)
  opts = type(opts) == "table" and opts or {}
  local cache = require("sagani.cache")
  local cached = cache.get_cached_models("codex", opts.cache_ttl)
  if cached then return cached end

  local models = {}
  local codex_cache_file = vim.fn.expand("~/.codex/models_cache.json")
  if vim.fn.filereadable(codex_cache_file) == 1 then
    local content = table.concat(vim.fn.readfile(codex_cache_file), "\n")
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" and type(data.models) == "table" then
      for _, m in ipairs(data.models) do
        if type(m) == "table" and m.slug then
          table.insert(models, m.slug)
        end
      end
    end
  end

  if #models > 0 then
    cache.set_cached_models("codex", models)
    return models
  end

  return nil
end

function M.build_command(prompt_text, agent_opts)
  agent_opts = type(agent_opts) == "table" and agent_opts or {}
  local cmd = { "codex", "exec", prompt_text }
  if agent_opts.model then
    table.insert(cmd, "-m")
    table.insert(cmd, agent_opts.model)
  end
  return cmd
end

function M.execute(prompt_text, agent_opts, callback, opts)
  opts = type(opts) == "table" and opts or {}
  local cmd = M.build_command(prompt_text, agent_opts)

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    callback("### Mock CLI Response (CODEX)\n\nHere is the response.", nil)
    return
  end

  if opts.runner then
    local out_text, code = opts.runner(cmd)
    if code == 0 then
      callback(out_text or "No output returned", nil)
    else
      callback(nil, string.format("Codex CLI execution failed (code %d): %s", code, out_text or ""))
    end
    return
  end

  if vim.fn.executable("codex") == 0 then
    callback(nil, "CLI executable 'codex' not found in PATH")
    return
  end

  vim.system(cmd, { text = true, stdin = "" }, function(obj)
    vim.schedule(function()
      if obj.code == 0 then
        local out = (obj.stdout and obj.stdout ~= "") and obj.stdout or (obj.stderr or "")
        callback(out, nil)
      else
        callback(nil, string.format("Codex CLI request failed: %s", obj.stderr or obj.stdout or ("code " .. obj.code)))
      end
    end)
  end)
end

return M
