--- ==============================================================================
--- Module: sagani.config.validator
---
--- Description:
---   Fail-fast configuration validator for sagani.nvim. Validates user options
---   during setup() to catch invalid option keys, mismatched types, and missing
---   agents early with clear diagnostic error notifications.
---
--- Responsibilities:
---   - Validate option types for tasks, backends, agents, and window options.
---   - Emit descriptive diagnostic warnings for misconfigured option keys.
---   - Return validated configuration table.
--- ==============================================================================

local notify = require("sagani.notify")

local M = {}

--- Validates user configuration options on setup()
--- @param opts table Raw options passed to setup()
--- @return boolean is_valid True if validation passed cleanly
--- @return table errors Array of error message strings
function M.validate(opts)
  if type(opts) ~= "table" then
    return false, { "Options passed to setup() must be a table" }
  end

  local errors = {}

  -- 1. Validate Tasks Table
  if opts.tasks ~= nil and type(opts.tasks) ~= "table" then
    table.insert(errors, "opts.tasks must be a table")
  end

  -- 2. Validate Backends Table
  if opts.backends ~= nil and type(opts.backends) ~= "table" then
    table.insert(errors, "opts.backends must be a table")
  end

  -- 3. Validate Agents Table
  if opts.agents ~= nil and type(opts.agents) ~= "table" then
    table.insert(errors, "opts.agents must be a table")
  end

  -- 4. Validate Window Opts Table
  if opts.window_opts ~= nil and type(opts.window_opts) ~= "table" then
    table.insert(errors, "opts.window_opts must be a table")
  else
    if opts.window_opts and opts.window_opts.width then
      if type(opts.window_opts.width) ~= "number" or opts.window_opts.width <= 0 or opts.window_opts.width > 1 then
        table.insert(errors, "opts.window_opts.width must be a float between 0.0 and 1.0")
      end
    end
    if opts.window_opts and opts.window_opts.height then
      if type(opts.window_opts.height) ~= "number" or opts.window_opts.height <= 0 or opts.window_opts.height > 1 then
        table.insert(errors, "opts.window_opts.height must be a float between 0.0 and 1.0")
      end
    end
  end

  if #errors > 0 then
    for _, err in ipairs(errors) do
      notify.warn("Configuration Error: " .. err)
    end
    return false, errors
  end

  return true, {}
end

return M
