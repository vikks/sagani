local M = {
  name = "opencode",
}

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

      local attempts = 0
      local timer = vim.loop and vim.loop.new_timer() or nil
      if timer then
        timer:start(200, 200, function()
          attempts = attempts + 1
          vim.system(health_cmd, { text = true }, function(check)
            vim.schedule(function()
              if check and check.code == 0 and check.stdout and check.stdout:find("healthy") then
                if timer then pcall(function() timer:stop(); timer:close() end); timer = nil end
                on_ready(true)
              elseif attempts >= 15 then
                if timer then pcall(function() timer:stop(); timer:close() end); timer = nil end
                on_ready(false)
              end
            end)
          end)
        end)
      else
        on_ready(false)
      end
    end)
  end)
end

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
      callback(nil, "OpenCode HTTP server returned empty response parts", session_id)
    end)
  end)
end

function M.execute(prompt_text, agent_opts, callback, progress_cb, session_id)
  if _G.RUNNING_TEST_SUITE then
    return false
  end

  local port = (agent_opts and agent_opts.port) or 4096
  local url = string.format("http://127.0.0.1:%d", port)

  M.ensure_server_async(port, progress_cb, function(ready)
    if not ready then
      local cli_gemini = require("sagani.protocol.cli.gemini")
      cli_gemini.execute(prompt_text, agent_opts, function(resp, err)
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
          callback(nil, "OpenCode HTTP server returned invalid session ID", nil)
          return
        end

        M.send_message(url, new_session_id, prompt_text, callback, progress_cb)
      end)
    end)
  end)

  return true
end

return M
