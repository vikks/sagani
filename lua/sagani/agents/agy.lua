--- ==============================================================================
--- Module: sagani.agents.agy
---
--- Description:
---   Agent harness definition and declarative capabilities for Antigravity CLI (agy).
--- ==============================================================================

local M = {}

M.id = "agy"
M.name = "Antigravity CLI"
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

--- Builds CLI command array for agy process execution
--- @param agent_opts table Resolved agent options (model, effort, etc.)
--- @return table Array of command arguments
function M.build_cmd(agent_opts)
  agent_opts = agent_opts or {}
  local cmd = { "agy" }
  if agent_opts.model and agent_opts.model ~= "" then
    table.insert(cmd, "--model")
    table.insert(cmd, agent_opts.model)
  end
  if agent_opts.effort and agent_opts.effort ~= "" then
    table.insert(cmd, "--thinking")
    table.insert(cmd, agent_opts.effort)
  end
  return cmd
end

return M
