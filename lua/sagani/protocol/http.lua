local M = {}

--- Checks if OpenCode ACP server is healthy, and auto-spawns it asynchronously in background if missing
--- @param port number Port number (default 4096)
--- @param progress_cb function|nil Progress update callback
--- @param on_ready function Callback receiving boolean ready
function M.ensure_server_async(port, progress_cb, on_ready)
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

--- Sends a message asynchronously to an active HTTP session ID
--- @param url string Base server URL
--- @param session_id string Session ID
--- @param prompt_text string Prompt text
--- @param callback function Callback receiving (response_text, err, session_id)
--- @param progress_cb function|nil Progress update callback
function M.send_message(url, session_id, prompt_text, callback, progress_cb)
  if progress_cb then progress_cb("Generating response from OpenCode model...") end
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
          callback(table.concat(text_parts, "\n"), nil, session_id)
          return
        end
      end
      callback(nil, "HTTP ACP server returned empty response parts", session_id)
    end)
  end)
end

--- Executes a prompt via HTTP REST transport asynchronously
--- @param prompt_text string Prompt text
--- @param agent_opts table Agent execution options
--- @param callback function Callback receiving (response_text, err, session_id)
--- @param progress_cb function|nil Progress update callback
--- @param session_id string|nil Optional existing session ID for follow-up queries
--- @return boolean attempted True if HTTP request was handled
function M.execute(prompt_text, agent_opts, callback, progress_cb, session_id)
  if _G.RUNNING_TEST_SUITE then
    return false
  end

  local port = (agent_opts and agent_opts.port) or 4096
  local url = string.format("http://127.0.0.1:%d", port)

  M.ensure_server_async(port, progress_cb, function(ready)
    if not ready then
      local cli_transport = require("sagani.protocol.cli")
      cli_transport.execute("opencode", prompt_text, agent_opts, function(resp, err)
        callback(resp, err, nil)
      end)
      return
    end

    if session_id and session_id ~= "" then
      M.send_message(url, session_id, prompt_text, callback, progress_cb)
      return
    end

    if progress_cb then progress_cb("Connected to OpenCode ACP server! Creating session...") end

    local create_payload = vim.json.encode({ prompt = prompt_text })
    local create_cmd = {
      "curl", "-s", "-X", "POST", url .. "/session",
      "-H", "Content-Type: application/json",
      "-d", create_payload,
    }

    vim.system(create_cmd, { text = true }, function(s_obj)
      vim.schedule(function()
        local s_ok, s_data = pcall(vim.json.decode, s_obj.stdout or "")
        local new_session_id = s_ok and type(s_data) == "table" and s_data.id

        if not new_session_id then
          callback(nil, "HTTP ACP server returned invalid session ID", nil)
          return
        end

        M.send_message(url, new_session_id, prompt_text, callback, progress_cb)
      end)
    end)
  end)

  return true
end

return M
