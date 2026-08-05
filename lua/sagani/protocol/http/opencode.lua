local M = {
  name = "opencode",
  _server_proc = nil,
  _server_port = nil,
}

function M.stop_server()
  if M._server_proc then
    pcall(function()
      M._server_proc:kill(9)
    end)
    M._server_proc = nil
  end

  local port = M._server_port or 4096
  M._server_port = nil

  if vim.fn.executable("lsof") == 1 then
    pcall(function()
      local pids = vim.system({ "lsof", "-ti", ":" .. tostring(port) }, { text = true }):wait()
      if pids and pids.code == 0 and pids.stdout and pids.stdout ~= "" then
        for pid in pids.stdout:gmatch("%d+") do
          vim.system({ "kill", "-9", pid }):wait()
        end
      end
    end)
  end

  pcall(function()
    vim.system({ "pkill", "-f", "opencode acp" })
  end)
end

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

  local check_cmd = { "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-m", "1", url .. "/session" }
  vim.system(check_cmd, { text = true }, function(c_obj)
    vim.schedule(function()
      local code_str = vim.trim((c_obj and c_obj.stdout) or "")
      -- Any HTTP status code (200, 400, 404, 405) means the ACP server is already running!
      if c_obj and c_obj.code == 0 and code_str ~= "" and code_str ~= "000" then
        on_ready(true)
        return
      end

      -- Check via lsof if port is already occupied by a running process
      if vim.fn.executable("lsof") == 1 then
        local pids = vim.system({ "lsof", "-ti", ":" .. tostring(port) }, { text = true }):wait()
        if pids and pids.code == 0 and pids.stdout and pids.stdout:find("%d+") then
          on_ready(true)
          return
        end
      end

      if progress_cb then progress_cb("Starting OpenCode ACP background server on port " .. port .. "...") end
      local spawn_cmd = { "opencode", "acp", "--port", tostring(port) }
      pcall(function()
        M._server_proc = vim.system(spawn_cmd)
        M._server_port = port
      end)

      local attempts = 0
      local ready_called = false
      local timer = vim.loop and vim.loop.new_timer() or nil

      local function done(is_ready)
        if ready_called then return end
        ready_called = true
        if timer then
          pcall(function() timer:stop(); timer:close() end)
          timer = nil
        end
        on_ready(is_ready)
      end

      if timer then
        timer:start(300, 300, function()
          attempts = attempts + 1
          vim.system(check_cmd, { text = true }, function(check)
            vim.schedule(function()
              local check_code = vim.trim((check and check.stdout) or "")
              if check and check.code == 0 and check_code ~= "" and check_code ~= "000" then
                done(true)
              elseif attempts >= 20 then
                done(false)
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
      local cli_opencode = require("sagani.protocol.cli.opencode")
      cli_opencode.execute(prompt_text, agent_opts, function(resp, err)
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
