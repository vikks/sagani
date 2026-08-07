--- ==============================================================================
--- Module: sagani.modes
---
--- Description:
---   Master operating modes strategy registry for sagani.nvim. Resolves strategy
---   modules (learn, review, refactor, custom) and provides strategy query APIs.
---
--- Responsibilities:
---   - Register built-in mode strategy modules (`learn`, `review`, `refactor`).
---   - Resolve strategy contract object for any given mode (`get_strategy`).
---   - List available mode strategy identifiers (`list_modes`).
--- ==============================================================================

local learn_mod = require("sagani.modes.learn")
local review_mod = require("sagani.modes.review")
local refactor_mod = require("sagani.modes.refactor")
local custom_mod = require("sagani.modes.custom")

local M = {
  _builtins = {
    learn = learn_mod,
    review = review_mod,
    refactor = refactor_mod,
  },
}

--- Resolves a mode strategy object by mode identifier name
--- @param mode_name string|nil Mode identifier (e.g. "learn", "review", "refactor", "audit")
--- @param opts table|nil Optional user options table
--- @return table|nil Strategy object or nil
function M.get_strategy(mode_name, opts)
  if type(mode_name) ~= "string" or mode_name == "" or mode_name:lower() == "off" then
    return nil
  end

  local m = mode_name:lower()
  if M._builtins[m] then
    local strat = M._builtins[m]
    -- Allow user options to override prompt_prefix
    if opts and type(opts.modes) == "table" and type(opts.modes[m]) == "table" and opts.modes[m].prompt_prefix then
      local custom_prefix = opts.modes[m].prompt_prefix
      return setmetatable({ prompt_prefix = custom_prefix }, { __index = strat })
    end
    return strat
  end

  -- Dynamic custom mode strategy
  local mode_cfg = (opts and type(opts.modes) == "table" and type(opts.modes[m]) == "table") and opts.modes[m] or nil
  return custom_mod.build_strategy(m, mode_cfg)
end

--- Returns list of available mode strategy identifiers
--- @return table Array of mode names
function M.list_modes()
  return { "learn", "review", "refactor" }
end

return M
