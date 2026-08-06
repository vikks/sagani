--- ==============================================================================
--- Module: sagani.agents.codex
---
--- Description:
---   Agent harness definition and declarative capabilities for Codex CLI.
--- ==============================================================================

local M = {}

M.id = "codex"
M.name = "Codex CLI"
M.default_provider = "openai"
M.default_model = "gpt-4o"

M.capabilities = {
  protocols = { "cli" },
  default_protocol = "cli",
  streaming = false,
  code_completion = true,
  multi_turn = false,
  files = true,
  media = {},
}

--- Builds CLI command array for codex process execution
--- @param agent_opts table Resolved agent options (model, effort, etc.)
--- @return table Array of command arguments
function M.build_cmd(agent_opts)
  agent_opts = agent_opts or {}
  local cmd = { "codex" }
  if agent_opts.model and agent_opts.model ~= "" then
    table.insert(cmd, "--model")
    table.insert(cmd, agent_opts.model)
  end
  return cmd
end

return M
