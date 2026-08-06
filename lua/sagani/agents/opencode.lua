--- ==============================================================================
--- Module: sagani.agents.opencode
---
--- Description:
---   Agent harness definition and declarative capabilities for Opencode Agent.
--- ==============================================================================

local M = {}

M.id = "opencode"
M.name = "Opencode Agent"
M.default_provider = "google"
M.default_model = "deepseek-v4-flash-free"
M.default_port = 4096

M.capabilities = {
  protocols = { "acp", "http", "cli" },
  default_protocol = "acp",
  streaming = true,
  code_completion = true,
  multi_turn = true,
  files = true,
  media = { "png", "jpeg", "mp4" },
}

--- Builds CLI command array for opencode process execution
--- @param agent_opts table Resolved agent options (model, effort, etc.)
--- @return table Array of command arguments
function M.build_cmd(agent_opts)
  agent_opts = agent_opts or {}
  local port = agent_opts.port or M.default_port
  return { "opencode", "acp", "--port", tostring(port) }
end

return M
