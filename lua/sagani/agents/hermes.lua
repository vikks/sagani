--- ==============================================================================
--- Module: sagani.agents.hermes
---
--- Description:
---   Agent harness definition and declarative capabilities for Hermes Agent.
--- ==============================================================================

local M = {}

M.id = "hermes"
M.name = "Hermes Agent"
M.default_provider = "openai"
M.default_model = "hermes-3-llama-3.1"

M.capabilities = {
  protocols = { "cli" },
  default_protocol = "cli",
  streaming = true,
  code_completion = true,
  multi_turn = true,
  files = true,
  media = {},
}

--- Builds CLI command array for hermes process execution
--- @param agent_opts table Resolved agent options (model, effort, etc.)
--- @return table Array of command arguments
function M.build_cmd(agent_opts)
  agent_opts = agent_opts or {}
  local cmd = { "hermes" }
  if agent_opts.model and agent_opts.model ~= "" then
    table.insert(cmd, "--model")
    table.insert(cmd, agent_opts.model)
  end
  return cmd
end

return M
