--- ==============================================================================
--- Module: sagani.ui.picker.mode
---
--- Description:
---   Sagani operating mode selection menu UI for sagani.nvim.
---
--- Responsibilities:
---   - Present interactive operating mode selection menu (`select_mode`).
--- ==============================================================================

local M = {}

--- Interactively selects active Sagani operating mode (review, learn, or user-defined modes)
--- @param opts table Configuration options
function M.select_mode(opts)
  local sagani = require("sagani")
  opts = type(opts) == "table" and opts or sagani.options

  local mode_set = { review = true, learn = true }
  if type(opts.tasks) == "table" then
    for t_name, _ in pairs(opts.tasks) do
      if type(t_name) == "string" then
        mode_set[t_name] = true
      end
    end
  end

  local modes = {}
  for m_name, _ in pairs(mode_set) do
    table.insert(modes, m_name)
  end
  table.sort(modes)
  table.insert(modes, "off")

  local active = sagani._session_mode or "off"

  if not _G.RUNNING_TEST_SUITE and vim.ui and vim.ui.select then
    vim.ui.select(modes, {
      prompt = string.format("Select Sagani Operating Mode (Current: %s):", active:upper()),
      format_item = function(item)
        if item == sagani._session_mode then
          return item:upper() .. " (active)"
        elseif item == "off" and not sagani._session_mode then
          return "OFF (standard operation)"
        end
        return item:upper()
      end,
    }, function(choice)
      if choice then
        sagani.set_mode(choice)
      end
    end)
  end
end

return M
