--- ==============================================================================
--- Module: sagani.personas.custom
---
--- Description:
---   Dynamic custom persona strategy builder for sagani.nvim. Builds custom persona
---   strategy objects for user-defined personas (e.g. `doc`, `security`, `test`).
---
--- Responsibilities:
---   - Build dynamic persona strategy contract for user-defined personas (`build_strategy`).
--- ==============================================================================

local M = {}

--- Builds a dynamic persona strategy object for user-defined custom personas
--- @param persona_name string Persona identifier (e.g. "security", "test")
--- @param persona_config table|nil Optional persona configuration table from opts.personas
--- @return table Strategy contract object
function M.build_strategy(persona_name, persona_config)
  persona_name = (type(persona_name) == "string" and persona_name ~= "") and persona_name:lower() or "custom"
  persona_config = type(persona_config) == "table" and persona_config or {}

  local title_name = persona_name:sub(1, 1):upper() .. persona_name:sub(2)
  local prefix = (type(persona_config.prompt_prefix) == "string" and persona_config.prompt_prefix ~= "")
    and persona_config.prompt_prefix
    or string.format("%s Persona Active: Perform operations specialized for %s workflow.", title_name, persona_name)

  local icon = (type(persona_config.icon) == "string" and persona_config.icon ~= "") and persona_config.icon or "⚙️"

  return {
    id = persona_name,
    name = title_name .. " Persona",
    icon = icon,
    prompt_prefix = prefix,
    default_instructions = string.format("Perform operations specialized for %s workflow.", persona_name),
    decorate_prompt = function(self, prompt)
      prompt = type(prompt) == "string" and prompt or ""
      return string.format("\n\n> %s **%s**\n\n%s", self.icon, self.prompt_prefix, prompt)
    end,
  }
end

return M
