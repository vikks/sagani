--- ==============================================================================
--- Module: sagani.personas
---
--- Description:
---   Master prompt personas registry for sagani.nvim. Resolves persona strategy
---   modules (tutor, refactor, audit, custom) and provides query APIs.
---
--- Responsibilities:
---   - Register built-in persona strategy modules (`tutor`, `refactor`, `audit`).
---   - Resolve strategy contract object for any given persona (`get_strategy`).
---   - List available persona strategy identifiers (`list_personas`).
--- ==============================================================================

local tutor_mod = require("sagani.personas.tutor")
local refactor_mod = require("sagani.personas.refactor")
local audit_mod = require("sagani.personas.audit")
local custom_mod = require("sagani.personas.custom")

local M = {
  _builtins = {
    tutor = tutor_mod,
    learn = tutor_mod, -- Alias for tutor
    refactor = refactor_mod,
    audit = audit_mod,
    review = audit_mod, -- Alias for audit persona
  },
}

--- Resolves a persona strategy object by persona identifier name
--- @param persona_name string|nil Persona identifier (e.g. "tutor", "refactor", "audit")
--- @param opts table|nil Optional user options table
--- @return table|nil Strategy object or nil
function M.get_strategy(persona_name, opts)
  if type(persona_name) ~= "string" or persona_name == "" or persona_name:lower() == "off" then
    return nil
  end

  local p = persona_name:lower()
  if M._builtins[p] then
    local strat = M._builtins[p]
    if opts and type(opts.personas) == "table" and type(opts.personas[p]) == "table" and opts.personas[p].prompt_prefix then
      local custom_prefix = opts.personas[p].prompt_prefix
      return setmetatable({ prompt_prefix = custom_prefix }, { __index = strat })
    end
    return strat
  end

  -- Dynamic custom persona strategy
  local persona_cfg = (opts and type(opts.personas) == "table" and type(opts.personas[p]) == "table") and opts.personas[p] or nil
  return custom_mod.build_strategy(p, persona_cfg)
end

--- Returns list of available persona strategy identifiers
--- @return table Array of persona names
function M.list_personas()
  return { "tutor", "refactor", "audit" }
end

return M
