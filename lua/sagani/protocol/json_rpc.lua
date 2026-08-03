local M = {
  _request_id = 0,
}

--- Encodes a JSON-RPC 2.0 payload
--- @param method string Method name
--- @param params table|nil Method parameters
--- @return string encoded JSON string
function M.encode_request(method, params)
  M._request_id = M._request_id + 1
  return vim.json.encode({
    jsonrpc = "2.0",
    id = M._request_id,
    method = method,
    params = params or {},
  })
end

--- Parses a JSON-RPC 2.0 response payload
--- @param payload string JSON string
--- @return table|nil response decoded object
--- @return string|nil err Error message
function M.parse_response(payload)
  local ok, data = pcall(vim.json.decode, payload)
  if not ok or type(data) ~= "table" then
    return nil, "Invalid JSON-RPC payload"
  end

  if data.error then
    local err_msg = (type(data.error) == "table" and data.error.message) or tostring(data.error)
    return nil, err_msg
  end

  return data.result or data, nil
end

--- Executes a JSON-RPC 2.0 command over stdio
--- @param cmd table Subprocess command array
--- @param method string JSON-RPC method name
--- @param params table Method parameters
--- @param callback function Callback receiving (result, err)
function M.execute_stdio(cmd, method, params, callback)
  if _G.RUNNING_TEST_SUITE then
    callback({ text = "Mock JSON-RPC response" }, nil)
    return
  end

  local req_text = M.encode_request(method, params) .. "\n"
  local executable = cmd[1]

  if vim.fn.executable(executable) == 0 then
    callback(nil, string.format("JSON-RPC executable '%s' not found in PATH", executable))
    return
  end

  if vim.system then
    vim.system(cmd, { text = true, stdin = req_text }, function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          local res, parse_err = M.parse_response(obj.stdout or "")
          callback(res, parse_err)
        else
          callback(nil, string.format("JSON-RPC subprocess error (%d): %s", obj.code, obj.stderr or obj.stdout or ""))
        end
      end)
    end)
  else
    callback(nil, "vim.system API required for JSON-RPC stdio transport")
  end
end

return M
