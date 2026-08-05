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

  -- 1. Fast-path: Memory check if Sagani already spawned the server in this session
  if M._server_proc and M._server_port == port then
    on_ready(true)
    return
  end

  -- 2. Fast-path: Check if port is already bound via lsof (instant check)
  if vim.fn.executable("lsof") == 1 then
    local pids = vim.system({ "lsof", "-ti", ":" .. tostring(port) }, { text = true }):wait()
    if pids and pids.code == 0 and pids.stdout and pids.stdout:find("%d+") then
      M._server_port = port
      on_ready(true)
      return
    end
  end

  local url = string.format("http://127.0.0.1:%d", port)

  if vim.fn.executable("curl") == 0 or vim.fn.executable("opencode") == 0 then
    on_ready(false)
    return
  end

  if progress_cb then progress_cb("Checking OpenCode ACP server health on port " .. port .. "...") end

  local check_cmd = { "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-m", "1", url .. "/" }
  vim.system(check_cmd, { text = true }, function(c_obj)
    vim.schedule(function()
      local code_str = vim.trim((c_obj and c_obj.stdout) or "")
      -- Any HTTP status code (200, 400, 404, 405) means the ACP server is already running!
      if c_obj and c_obj.code == 0 and code_str ~= "" and code_str ~= "000" then
        M._server_port = port
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

local function parse_opencode_response(m_obj)
  if not m_obj then
    return nil, "No response object received"
  end

  local stdout = m_obj.stdout or ""
  local stderr = m_obj.stderr or ""
  local code = m_obj.code or 0

  if code ~= 0 then
    local err_msg = (stderr ~= "") and stderr or string.format("curl exited with code %d", code)
    return nil, err_msg
  end

  if stdout == "" then
    return nil, (stderr ~= "") and stderr or "Empty response stdout from OpenCode HTTP server"
  end

  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or type(data) ~= "table" then
    if stdout and vim.trim(stdout) ~= "" then
      return vim.trim(stdout), nil
    end
    return nil, "Invalid JSON response: " .. (stdout:sub(1, 100))
  end

  if data.error or data.err then
    local json_err = type(data.error) == "string" and data.error
      or (type(data.error) == "table" and (data.error.message or data.error.msg))
      or (type(data.err) == "string" and data.err)
      or "OpenCode server returned error response"
    return nil, json_err
  end

  local parts = data.parts or (type(data.result) == "table" and data.result.parts) or (type(data.message) == "table" and data.message.parts)
  if type(parts) == "table" and #parts > 0 then
    local text_parts = {}
    for _, p in ipairs(parts) do
      if type(p) == "table" then
        local t = p.text or p.content or p.value
        if type(t) == "string" and t ~= "" then
          table.insert(text_parts, t)
        end
      elseif type(p) == "string" and p ~= "" then
        table.insert(text_parts, p)
      end
    end
    if #text_parts > 0 then
      return table.concat(text_parts, "\n"), nil
    end
  end

  local direct = data.text
    or data.content
    or data.response
    or (type(data.result) == "table" and (data.result.text or data.result.content or data.result.response))
    or (type(data.message) == "table" and (data.message.text or data.message.content))

  if direct and type(direct) == "string" and direct ~= "" then
    return direct, nil
  end

  return nil, "OpenCode response missing text content"
end

local function extract_session_id(s_data)
  if type(s_data) ~= "table" then return nil end
  if type(s_data.id) == "string" and s_data.id ~= "" then return s_data.id end
  if type(s_data.session_id) == "string" and s_data.session_id ~= "" then return s_data.session_id end
  if type(s_data.sessionId) == "string" and s_data.sessionId ~= "" then return s_data.sessionId end
  if type(s_data.uuid) == "string" and s_data.uuid ~= "" then return s_data.uuid end
  if type(s_data.key) == "string" and s_data.key ~= "" then return s_data.key end
  if type(s_data.session) == "string" and s_data.session ~= "" then return s_data.session end
  if type(s_data.session) == "table" and type(s_data.session.id) == "string" and s_data.session.id ~= "" then return s_data.session.id end
  if type(s_data.result) == "table" then
    local res_id = extract_session_id(s_data.result)
    if res_id then return res_id end
  end
  if type(s_data.data) == "table" then
    local data_id = extract_session_id(s_data.data)
    if data_id then return data_id end
  end
  return nil
end

function M.send_message(url, session_id, prompt_text, callback, progress_cb)
  if progress_cb then progress_cb("Generating response from OpenCode model...") end
  local msg_payload = vim.json.encode({
    parts = { { type = "text", text = prompt_text } },
    prompt = prompt_text,
    text = prompt_text,
  })
  local msg_cmd = {
    "curl", "-s", "-X", "POST", url .. "/session/" .. session_id .. "/message",
    "-H", "Content-Type: application/json",
    "-d", msg_payload,
  }

  vim.system(msg_cmd, { text = true }, function(m_obj)
    vim.schedule(function()
      local text, err = parse_opencode_response(m_obj)
      if text then
        callback(text, nil, session_id)
        return
      end

      -- Fallback secondary endpoint: POST /session/<id>
      local alt_cmd = {
        "curl", "-s", "-X", "POST", url .. "/session/" .. session_id,
        "-H", "Content-Type: application/json",
        "-d", msg_payload,
      }
      vim.system(alt_cmd, { text = true }, function(alt_obj)
        vim.schedule(function()
          local alt_text, alt_err = parse_opencode_response(alt_obj)
          if alt_text then
            callback(alt_text, nil, session_id)
          else
            callback(nil, err or alt_err or "Failed to send message to OpenCode ACP session", session_id)
          end
        end)
      end)
    end)
  end)
end

function M.create_session_and_send(url, prompt_text, callback, progress_cb)
  if progress_cb then progress_cb("Connected to OpenCode ACP server! Creating session...") end

  local create_payload = vim.json.encode({
    parts = { { type = "text", text = prompt_text } },
    prompt = prompt_text,
    text = prompt_text,
  })
  local create_cmd = {
    "curl", "-s", "-X", "POST", url .. "/session",
    "-H", "Content-Type: application/json",
    "-d", create_payload,
  }

  vim.system(create_cmd, { text = true }, function(s_obj)
    vim.schedule(function()
      local stdout = (s_obj and s_obj.stdout) or ""
      local s_ok, s_data = pcall(vim.json.decode, stdout)
      local new_session_id = s_ok and extract_session_id(s_data)

      -- Synthetic session ID fallback if server does not return explicit session ID
      if not new_session_id or new_session_id == "" then
        new_session_id = "sess_opencode_" .. tostring(os.time()) .. "_" .. math.random(1000, 9999)
      end

      local text, _ = parse_opencode_response(s_obj)
      if text and text ~= "" then
        callback(text, nil, new_session_id)
      else
        M.send_message(url, new_session_id, prompt_text, callback, progress_cb)
      end
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
      M.send_message(url, session_id, prompt_text, function(resp, err, s_id)
        if resp then
          callback(resp, nil, s_id or session_id)
        else
          M.create_session_and_send(url, prompt_text, callback, progress_cb)
        end
      end, progress_cb)
      return
    end

    M.create_session_and_send(url, prompt_text, callback, progress_cb)
  end)

  return true
end

return M
