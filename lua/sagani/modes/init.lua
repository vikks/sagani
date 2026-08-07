--- ==============================================================================
--- Module: sagani.modes
---
--- Description:
---   Master operational Neovim modes strategy package for sagani.nvim. Controls
---   how Neovim renders and behaves (edit_review, learn, off).
---
--- Submodules:
---   - edit_review: Interactive buffer edit diff review mode (inline/split accept/reject).
---   - learn: Pedagogical learning mode (educational split/popup UI).
--- ==============================================================================

local edit_review = require("sagani.modes.edit_review")
local learn = require("sagani.modes.learn")
local state_mode = require("sagani.state.mode")

local M = {
  edit_review = edit_review,
  learn = learn,

  set_mode = state_mode.set_mode,
  toggle_mode = state_mode.toggle_mode,
}

--- Resolves operational mode strategy module by name
--- @param mode_name string|nil Mode identifier ("edit_review", "learn", "review")
--- @return table|nil Operational mode strategy table
function M.get_mode(mode_name)
  if type(mode_name) ~= "string" or mode_name == "" or mode_name:lower() == "off" then
    return nil
  end

  local m = mode_name:lower()
  if m == "edit_review" or m == "review" then
    return edit_review
  elseif m == "learn" then
    return learn
  end

  return nil
end

--- Returns list of supported operational Neovim mode identifiers
--- @return table Array of operational mode names
function M.list_modes()
  return { "edit_review", "learn" }
end

return M
