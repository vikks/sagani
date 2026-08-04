local M = {
  name = "gemini",
}

function M.list_models_async(opts, callback)
  opts = type(opts) == "table" and opts or {}
  if _G.RUNNING_TEST_SUITE and not opts.runner then
    callback({ "gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.5-flash-lite" })
    return
  end

  local cache = require("sagani.cache")
  local cached = cache.get_cached_models("gemini", opts.cache_ttl)
  if cached then
    callback(cached)
    return
  end

  local api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
  if api_key and api_key ~= "" and vim.fn.executable("curl") == 1 then
    local url = "https://generativelanguage.googleapis.com/v1beta/models?key=" .. api_key
    vim.system({ "curl", "-s", "-m", "3", url }, { text = true }, function(obj)
      vim.schedule(function()
        local models = {}
        if obj.code == 0 and obj.stdout then
          local ok, data = pcall(vim.json.decode, obj.stdout)
          if ok and type(data) == "table" and type(data.models) == "table" then
            for _, m in ipairs(data.models) do
              if type(m) == "table" and type(m.name) == "string" then
                local clean_name = m.name:gsub("^models/", "")
                if clean_name:find("^gemini") then
                  table.insert(models, clean_name)
                end
              end
            end
          end
        end

        if #models > 0 then
          cache.set_cached_models("gemini", models)
          callback(models)
        else
          callback(nil)
        end
      end)
    end)
    return
  end

  callback(nil)
end

function M.list_models(opts)
  opts = type(opts) == "table" and opts or {}
  local cache = require("sagani.cache")
  return cache.get_cached_models("gemini", opts.cache_ttl)
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
