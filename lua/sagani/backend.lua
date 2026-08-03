local notify = require("sagani.notify")

local M = {}

--- Registry of available backends
M.backends = {}

--- Registers a backend adapter
--- @param name string Backend name (e.g. "native", "herdr", "tmux", "zellij")
--- @param adapter table Backend adapter implementation table
function M.register(name, adapter)
  if type(name) ~= "string" or name == "" then
    error("Backend name must be a non-empty string")
  end
  if type(adapter) ~= "table" then
    error("Backend adapter must be a table")
  end
  M.backends[name] = adapter
end

--- Resolves placement for a given backend name and task type
--- @param opts table Configuration options
--- @param bname string Backend identifier ("herdr", "tmux", "zellij", "native")
--- @param task_type string|nil Task identifier ("ask", "review", "code", "chat", or custom)
--- @return string|boolean placement Placement specifier or false for opt-out
function M.resolve_placement(opts, bname, task_type)
  task_type = task_type or "chat"
  
  -- 1. Backend-specific override
  if opts and opts.backends and opts.backends[bname] and opts.backends[bname][task_type] ~= nil then
    return opts.backends[bname][task_type]
  end

  -- 2. Shared tasks default
  if opts and opts.tasks and opts.tasks[task_type] ~= nil then
    return opts.tasks[task_type]
  end

  -- 3. Hardcoded fallback
  if task_type == "ask" then
    return false
  end

  return "right-pane"
end

--- Resolves the active backend adapter based on options, environment, and task capability
--- @param opts table Sagani configuration options
--- @param task_type string|nil Task identifier ("ask", "review", "code", "chat", or custom)
--- @return table adapter Active backend adapter table
--- @return string backend_name Active backend name
--- @return string|boolean placement Resolved placement specifier
function M.get_backend(opts, task_type)
  opts = type(opts) == "table" and opts or {}
  task_type = task_type or "chat"
  local requested = opts.backend or "auto"

  -- If user passed a custom adapter table directly
  if type(requested) == "table" then
    local placement = M.resolve_placement(opts, requested.name or "custom", task_type)
    return requested, requested.name or "custom", placement
  end

  -- Helper to evaluate candidate adapter
  local function try_candidate(name)
    local candidate = M.backends[name]
    if not candidate then
      return nil
    end

    local env = candidate.detect_env(opts.runner)
    if not env or not env.active then
      return nil
    end

    local placement = M.resolve_placement(opts, name, task_type)
    -- Check capability / opt-out
    if placement == false then
      return nil -- Opted out for this task type
    end
    if candidate.capabilities and candidate.capabilities[task_type] == false then
      return nil -- Explicit capability opt-out
    end

    return candidate, name, placement
  end

  -- If explicit backend string requested (other than "auto")
  if type(requested) == "string" and requested ~= "auto" then
    if M.backends[requested] then
      local placement = M.resolve_placement(opts, requested, task_type)
      if placement == false or (M.backends[requested].capabilities and M.backends[requested].capabilities[task_type] == false) then
        -- Task opted out on this backend -> fallback to native
        local native_placement = M.resolve_placement(opts, "native", task_type)
        return M.backends["native"], "native", native_placement
      end
      return M.backends[requested], requested, placement
    else
      notify.warn(
        string.format("Requested backend '%s' not found, falling back to auto-detection", requested),
        opts
      )
    end
  end

  -- Auto-detection hierarchy: Herdr -> Tmux -> Zellij -> Native
  local order = { "herdr", "tmux", "zellij" }
  for _, bname in ipairs(order) do
    local adapter, name, placement = try_candidate(bname)
    if adapter then
      return adapter, name, placement
    end
  end

  -- Guaranteed fallback to native backend
  if M.backends["native"] then
    local native_placement = M.resolve_placement(opts, "native", task_type)
    if native_placement == false or native_placement == nil then
      native_placement = (task_type == "ask" and "popup" or "vsplit")
    end
    return M.backends["native"], "native", native_placement
  end

  error("No valid sagani backend adapter found!")
end

return M
