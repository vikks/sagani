local notify = require("sagani.notify")

local M = {}

--- Formats command array for ACP request execution based on agent harness
--- @param harness string Agent harness name ("agy", "codex", "opencode", "hermes")
--- @param prompt_text string Prompt text
--- @param agent_opts table|nil Options (model, effort, provider)
--- @return table cmd Subprocess command array
--- Formats command array for ACP request execution based on agent harness
--- @param harness string Agent harness name ("agy", "codex", "opencode", "hermes")
--- @param prompt_text string Prompt text
--- @param agent_opts table|nil Options (model, effort, provider)
--- @return table cmd Subprocess command array
function M.build_acp_command(harness, prompt_text, agent_opts)
  harness = (harness or "agy"):lower()
  agent_opts = type(agent_opts) == "table" and agent_opts or {}

  local cmd = {}
  if harness == "agy" or harness == "antigravity" then
    cmd = { "agy", "prompt", prompt_text, "--non-interactive" }
    if agent_opts.model then
      table.insert(cmd, "--model")
      table.insert(cmd, agent_opts.model)
    end
  elseif harness == "codex" then
    cmd = { "codex", "exec", prompt_text }
  elseif harness == "opencode" then
    cmd = { "opencode", "run", prompt_text }
  elseif harness == "hermes" then
    cmd = { "hermes", "prompt", prompt_text }
  else
    cmd = { harness, "prompt", prompt_text }
  end

  return cmd
end

--- Checks if OpenCode ACP server is healthy, and auto-spawns it in background if missing
--- @param port number Port number (default 4096)
--- @param progress_cb function|nil Progress update callback
--- @param on_ready function Callback receiving boolean ready
function M.ensure_opencode_server_async(port, progress_cb, on_ready)
  if _G.RUNNING_TEST_SUITE then
    on_ready(false)
    return
  end

  port = port or 4096
  local url = string.format("http://127.0.0.1:%d", port)

  if vim.fn.executable("curl") == 0 or vim.fn.executable("opencode") == 0 then
    on_ready(false)
    return
  end

  if progress_cb then progress_cb("Checking OpenCode ACP server health on port " .. port .. "...") end

  local health_cmd = { "curl", "-s", "-m", "1", url .. "/global/health" }
  vim.system(health_cmd, { text = true }, function(h_obj)
    vim.schedule(function()
      if h_obj.code == 0 and h_obj.stdout and h_obj.stdout:find("healthy") then
        on_ready(true)
        return
      end

      if progress_cb then progress_cb("Starting OpenCode ACP background server on port " .. port .. "...") end
      local spawn_cmd = { "opencode", "acp", "--port", tostring(port) }
      pcall(function() vim.system(spawn_cmd, { detach = true }) end)

      -- Poll health asynchronously
      local attempts = 0
      local timer = vim.loop and vim.loop.new_timer() or nil
      if timer then
        timer:start(200, 200, function()
          attempts = attempts + 1
          local check = vim.system(health_cmd, { text = true }):wait()
          if check and check.code == 0 and check.stdout and check.stdout:find("healthy") then
            timer:stop()
            timer:close()
            vim.schedule(function() on_ready(true) end)
          elseif attempts >= 15 then
            timer:stop()
            timer:close()
            vim.schedule(function() on_ready(false) end)
          end
        end)
      else
        on_ready(false)
      end
    end)
  end)
end

--- Attempts execution via running OpenCode ACP HTTP server (default port 4096)
--- @param prompt_text string Prompt text
--- @param agent_opts table Agent execution options
--- @param callback function Callback receiving (response_text, err)
--- @param progress_cb function|nil Progress update callback
--- @return boolean attempted True if HTTP request was handled
function M.try_opencode_http_acp(prompt_text, agent_opts, callback, progress_cb)
  if _G.RUNNING_TEST_SUITE then
    return false
  end

  local port = (agent_opts and agent_opts.port) or 4096
  local url = string.format("http://127.0.0.1:%d", port)

  M.ensure_opencode_server_async(port, progress_cb, function(ready)
    if not ready then
      -- Fallback to CLI run command if HTTP server unavailable
      local cmd = M.build_acp_command("opencode", prompt_text, agent_opts)
      vim.system(cmd, { text = true, stdin = "" }, function(obj)
        vim.schedule(function()
          if obj.code == 0 then
            local out = (obj.stdout and obj.stdout ~= "") and obj.stdout or (obj.stderr or "")
            callback(out, nil)
          else
            callback(nil, string.format("ACP execution failed: %s", obj.stderr or obj.stdout or "Unknown error"))
          end
        end)
      end)
      return
    end

    if progress_cb then progress_cb("Connected to OpenCode ACP server! Generating response...") end

    local create_payload = vim.json.encode({ prompt = prompt_text })
    local create_cmd = {
      "curl", "-s", "-X", "POST", url .. "/session",
      "-H", "Content-Type: application/json",
      "-d", create_payload,
    }

    vim.system(create_cmd, { text = true }, function(s_obj)
      vim.schedule(function()
        local s_ok, s_data = pcall(vim.json.decode, s_obj.stdout or "")
        local session_id = s_ok and type(s_data) == "table" and s_data.id

        if not session_id then
          callback(nil, "OpenCode ACP server returned invalid session ID")
          return
        end

        local msg_payload = vim.json.encode({ parts = { { type = "text", text = prompt_text } } })
        local msg_cmd = {
          "curl", "-s", "-X", "POST", url .. "/session/" .. session_id .. "/message",
          "-H", "Content-Type: application/json",
          "-d", msg_payload,
        }

        vim.system(msg_cmd, { text = true }, function(m_obj)
          vim.schedule(function()
            local m_ok, m_data = pcall(vim.json.decode, m_obj.stdout or "")
            if m_ok and type(m_data) == "table" and type(m_data.parts) == "table" then
              local text_parts = {}
              for _, p in ipairs(m_data.parts) do
                if type(p) == "table" and p.type == "text" and type(p.text) == "string" and p.text ~= "" then
                  table.insert(text_parts, p.text)
                end
              end
              if #text_parts > 0 then
                callback(table.concat(text_parts, "\n"), nil)
                return
              end
            end
            callback(nil, "OpenCode ACP server returned empty response parts")
          end)
        end)
      end)
    end)
  end)

  return true
end

--- Executes a prompt via ACP request-response subprocess or HTTP server asynchronously
--- @param harness string Agent harness name
--- @param prompt_text string Prompt text
--- @param agent_opts table Agent execution options
--- @param callback function Callback receiving (response_text, err)
--- @param opts table|nil Options (runner for tests)
--- @param progress_cb function|nil Progress update callback
function M.execute_prompt(harness, prompt_text, agent_opts, callback, opts, progress_cb)
  opts = type(opts) == "table" and opts or {}
  harness = (harness or "agy"):lower()

  if harness == "opencode" and not opts.runner then
    local handled = M.try_opencode_http_acp(prompt_text, agent_opts, callback, progress_cb)
    if handled then
      return
    end
  end

  local cmd = M.build_acp_command(harness, prompt_text, agent_opts)
  local executable = cmd[1]

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    local mock_resp = string.format("### Mock ACP Response (%s)\n\nHere is the answer to your prompt:\n```lua\nlocal x = 42\n```", harness:upper())
    callback(mock_resp, nil)
    return
  end

  if opts.runner then
    local out_text, code = opts.runner(cmd)
    if code == 0 then
      callback(out_text or "No output returned", nil)
    else
      callback(nil, string.format("ACP execution failed (code %d): %s", code, out_text or ""))
    end
    return
  end

  if vim.fn.executable(executable) == 0 then
    callback(nil, string.format("ACP executable '%s' not found in PATH", executable))
    return
  end

  if vim.system then
    vim.system(cmd, { text = true, stdin = "" }, function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          local out = (obj.stdout and obj.stdout ~= "") and obj.stdout or (obj.stderr or "")
          callback(out, nil)
        else
          local err_msg = (obj.stderr and obj.stderr ~= "") and obj.stderr or obj.stdout or ("Exit code " .. tostring(obj.code))
          callback(nil, string.format("ACP request failed (%s): %s", executable, err_msg))
        end
      end)
    end)
  else
    local out = vim.fn.system(cmd)
    local code = vim.v.shell_error
    if code == 0 then
      callback(out, nil)
    else
      callback(nil, string.format("ACP request failed (%s): %s", executable, out))
    end
  end
end

return M
