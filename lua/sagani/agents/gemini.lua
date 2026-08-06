--- ==============================================================================
--- Module: sagani.agents.gemini
---
--- Description:
---   Agent harness definition and declarative capabilities for Gemini CLI.
--- ==============================================================================

local M = {}

M.id = "gemini"
M.name = "Gemini CLI"
M.default_provider = "google"
M.default_model = "gemini-2.5-flash"

M.capabilities = {
  protocols = { "acp", "cli" },
  default_protocol = "cli",
  streaming = true,
  code_completion = true,
  multi_turn = true,
  files = true,
  media = { "png", "jpeg" },
}

--- Builds CLI command array for gemini process execution
--- @param agent_opts table Resolved agent options (model, effort, etc.)
--- @return table Array of command arguments
function M.build_cmd(agent_opts)
  agent_opts = agent_opts or {}
  local cmd = { "gemini" }
  if agent_opts.model and agent_opts.model ~= "" then
    table.insert(cmd, "--model")
    table.insert(cmd, agent_opts.model)
  end
  return cmd
end

return M
