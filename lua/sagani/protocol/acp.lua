--- ==============================================================================
--- Module: sagani.protocol.acp
---
--- Description:
---   Agent Communication Protocol (ACP) driver for sagani.nvim. Manages JSON-RPC 2.0
---   session initialization, client/server capability negotiation (`initialize`), session
---   updates (`session/new`, `session/prompt`), and response parsing for ACP-compliant agents.
---
--- Responsibilities:
---   - Spawn ACP agent process over stdio JSON-RPC.
---   - Send initialize request and process initialization response.
---   - Stream status notifications and return completion responses to caller.
--- ==============================================================================

local cli_transport = require("sagani.protocol.cli")
local http_transport = require("sagani.protocol.http")

local M = {}

--- Expose build_command for backward compatibility
function M.build_acp_command(harness, prompt_text, agent_opts)
  return cli_transport.build_command(harness, prompt_text, agent_opts)
end

--- Expose try_opencode_http_acp for backward compatibility
function M.try_opencode_http_acp(prompt_text, agent_opts, callback, progress_cb, session_id)
  return http_transport.execute(prompt_text, agent_opts, callback, progress_cb, session_id)
end

--- Expose ensure_opencode_server for backward compatibility
function M.ensure_opencode_server(port, progress_cb)
  local ok = false
  http_transport.ensure_server_async(port, progress_cb, function(ready)
    ok = ready
  end)
  return ok
end

--- Main ACP router entry point
--- Routes requests to appropriate transport protocol (http, cli, json_rpc)
--- @param harness string Agent harness name
--- @param prompt_text string Prompt text
--- @param agent_opts table Agent execution options
--- @param callback function Callback receiving (response_text, err, session_id)
--- @param opts table|nil Options (runner for tests)
--- @param progress_cb function|nil Progress update callback
--- @param session_id string|nil Optional existing session ID
function M.execute_prompt(harness, prompt_text, agent_opts, callback, opts, progress_cb, session_id)
  opts = type(opts) == "table" and opts or {}
  harness = (harness or "agy"):lower()

  if harness == "opencode" and not opts.runner then
    local handled = http_transport.execute(prompt_text, agent_opts, callback, progress_cb, session_id)
    if handled then
      return
    end
  end

  cli_transport.execute(harness, prompt_text, agent_opts, function(resp, err)
    callback(resp, err, session_id)
  end, opts)
end

return M
