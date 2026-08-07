--- ==============================================================================
--- Module: sagani.state.persona
---
--- Description:
---   Session state manager for active prompt personas in sagani.nvim. Manages
---   `_session_persona` override state and provides set_persona and toggle_persona helpers.
---
--- Responsibilities:
---   - Store active session prompt persona override (`_session_persona`).
---   - Provide set_persona and toggle_persona state setters.
--- ==============================================================================

local notify = require("sagani.notify")

local M = {}

M._session_persona = nil

--- Sets or explicitly toggles active prompt persona ("tutor", "refactor", "audit", or custom)
--- @param persona_arg string|nil Target persona identifier
--- @param options table|nil Sagani options table
--- @return string|nil active_persona Active persona identifier or nil
function M.set_persona(persona_arg, options)
  local opts = options or {}
  if type(persona_arg) == "string" and persona_arg ~= "" then
    local p = persona_arg:lower()
    if p == "off" or p == "none" or p == "normal" then
      M._session_persona = nil
      notify.info("Sagani prompt persona: OFF (standard operation)", opts)
    else
      M._session_persona = p
      notify.info(string.format("Sagani prompt persona set to: %s", p:upper()), opts)
    end
  else
    local current = M._session_persona
    if not current then
      M.set_persona("tutor", opts)
    elseif current == "tutor" then
      M.set_persona("refactor", opts)
    elseif current == "refactor" then
      M.set_persona("audit", opts)
    else
      M.set_persona("off", opts)
    end
  end
  return M._session_persona
end

--- Toggles specific prompt persona on or off
--- @param persona_arg string|nil Target persona string
--- @param options table|nil Sagani options table
--- @return string|nil active_persona
function M.toggle_persona(persona_arg, options)
  local opts = options or {}
  if type(persona_arg) == "string" and persona_arg ~= "" then
    local p = persona_arg:lower()
    if M._session_persona == p then
      M._session_persona = nil
      notify.info(string.format("Sagani persona '%s' disabled", p), opts)
    else
      M.set_persona(p, opts)
    end
  else
    return M.set_persona(nil, opts)
  end
  return M._session_persona
end

return M
