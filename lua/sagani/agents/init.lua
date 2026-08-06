--- ==============================================================================
--- Module: sagani.agents
---
--- Description:
---   Registry facade for agent harness definitions and declarative capabilities.
---
--- Responsibilities:
---   - Register and retrieve built-in agent harness modules (agy, codex, opencode, etc.).
---   - Expose agent lookup and capability introspection API.
---   - Resolve executable CLI command arrays for agents.
--- ==============================================================================

local M = {}

M._agents = {}

--- Registers an agent harness module
--- @param agent_id string Agent identifier
--- @param module table Agent harness module
function M.register(agent_id, module)
  M._agents[agent_id] = module
end

--- Retrieves an agent harness module by ID
--- @param agent_id string Agent identifier
--- @return table|nil Agent harness module
function M.get(agent_id)
  if not agent_id then
    return nil
  end
  if M._agents[agent_id] then
    return M._agents[agent_id]
  end

  -- Lazy load built-in agents
  local ok, mod = pcall(require, "sagani.agents." .. agent_id)
  if ok and type(mod) == "table" then
    M.register(agent_id, mod)
    return mod
  end

  return nil
end

--- Lists all registered/available agent IDs
--- @return table List of agent identifiers
function M.list_agent_ids()
  local ids = { "agy", "codex", "opencode", "hermes", "gemini" }
  for id, _ in pairs(M._agents) do
    if not vim.tbl_contains(ids, id) then
      table.insert(ids, id)
    end
  end
  return ids
end

--- Auto-registers built-in agent modules
local function init_defaults()
  local builtins = { "agy", "codex", "opencode", "hermes", "gemini" }
  for _, id in ipairs(builtins) do
    local ok, mod = pcall(require, "sagani.agents." .. id)
    if ok then
      M.register(id, mod)
    end
  end
end

init_defaults()

return M
