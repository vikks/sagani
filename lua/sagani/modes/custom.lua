--- ==============================================================================
--- Module: sagani.modes.custom
---
--- Description:
---   Dynamic custom mode strategy builder for sagani.nvim. Builds custom mode
---   strategy objects for user-defined modes (e.g. `audit`, `security`, `doc`).
---
--- Responsibilities:
---   - Build dynamic mode strategy contract for user-defined modes (`build_strategy`).
--- ==============================================================================

local M = {}

--- Builds a dynamic mode strategy object for user-defined custom modes
--- @param mode_name string Mode identifier (e.g. "audit", "security")
--- @param mode_config table|nil Optional mode configuration table from opts.modes
--- @return table Strategy contract object
function M.build_strategy(mode_name, mode_config)
  mode_name = (type(mode_name) == "string" and mode_name ~= "") and mode_name:lower() or "custom"
  mode_config = type(mode_config) == "table" and mode_config or {}

  local title_name = mode_name:sub(1, 1):upper() .. mode_name:sub(2)
  local prefix = (type(mode_config.prompt_prefix) == "string" and mode_config.prompt_prefix ~= "")
    and mode_config.prompt_prefix
    or string.format("%s Mode Active: Perform operations specialized for %s workflow.", title_name, mode_name)

  local icon = (type(mode_config.icon) == "string" and mode_config.icon ~= "") and mode_config.icon or "⚙️"

  return {
    id = mode_name,
    name = title_name .. " Mode",
    icon = icon,
    prompt_prefix = prefix,
    default_instructions = string.format("Perform operations specialized for %s task workflow.", mode_name),
    ui_placement = mode_config.placement or "vsplit",
    decorate_prompt = function(self, prompt)
      prompt = type(prompt) == "string" and prompt or ""
      return string.format("\n\n> %s **%s**\n\n%s", self.icon, self.prompt_prefix, prompt)
    end,
  }
end

return M
