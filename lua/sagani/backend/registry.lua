--- ==============================================================================
--- Module: sagani.backend.registry
---
--- Description:
---   Backend adapter registry and environment auto-detection engine for sagani.nvim.
---
--- Responsibilities:
---   - Maintain backend adapter registration table (`backends`).
---   - Auto-detect active multiplexer environment (Herdr -> Tmux -> Zellij -> Native).
---   - Resolve active backend adapter, placement, UI styling, and agent execution options.
--- ==============================================================================

local notify = require("sagani.notify")
local task = require("sagani.backend.task")

local M = {
  backends = {},
}

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

--- Resolves the active backend adapter based on options, environment, and task capability
--- @param opts table Sagani configuration options
--- @param task_type string|nil Task identifier ("ask", "review", "code", "chat", or custom)
--- @return table adapter Active backend adapter table
--- @return string backend_name Active backend name
--- @return string|boolean placement Resolved placement specifier
--- @return table ui_opts Resolved UI styling options
--- @return table agent_opts Resolved agent execution options
function M.get_backend(opts, task_type)
  opts = type(opts) == "table" and opts or {}
  local sagani = pcall(require, "sagani") and require("sagani") or {}
  if sagani._session_mode and type(opts.tasks) == "table" and opts.tasks[sagani._session_mode] ~= nil then
    task_type = sagani._session_mode
  else
    task_type = task_type or "chat"
  end

  local session_backend = sagani._session_backend

  local task_val = (type(opts.tasks) == "table") and opts.tasks[task_type] or nil
  local task_backend = (type(task_val) == "table" and type(task_val.backend) == "string" and task_val.backend ~= "") and task_val.backend or nil
  local requested = session_backend or task_backend or opts.backend or "auto"

  local agent_opts = task.resolve_task_agent(opts, task_type)

  -- If user passed a custom adapter table directly
  if type(requested) == "table" then
    local placement = task.resolve_placement(opts, requested.name or "custom", task_type)
    local ui_opts = task.resolve_task_ui(opts, requested.name or "custom")
    return requested, requested.name or "custom", placement, ui_opts, agent_opts
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

    local placement = task.resolve_placement(opts, name, task_type)
    -- Check capability / opt-out
    if placement == false then
      return nil -- Opted out for this task type
    end
    if candidate.capabilities and candidate.capabilities[task_type] == false then
      return nil -- Explicit capability opt-out
    end

    local ui_opts = task.resolve_task_ui(opts, name)
    return candidate, name, placement, ui_opts, agent_opts
  end

  -- If explicit backend string requested (other than "auto")
  if type(requested) == "string" and requested ~= "auto" then
    if M.backends[requested] then
      local placement = task.resolve_placement(opts, requested, task_type)
      local ui_opts = task.resolve_task_ui(opts, requested)
      if placement == false or (M.backends[requested].capabilities and M.backends[requested].capabilities[task_type] == false) then
        -- Task opted out on this backend -> fallback to native
        local native_placement = task.resolve_placement(opts, "native", task_type)
        local native_ui = task.resolve_task_ui(opts, "native")
        return M.backends["native"], "native", native_placement, native_ui, agent_opts
      end
      return M.backends[requested], requested, placement, ui_opts, agent_opts
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
    local adapter, name, placement, ui_opts = try_candidate(bname)
    if adapter then
      return adapter, name, placement, ui_opts, agent_opts
    end
  end

  -- Guaranteed fallback to native backend
  if M.backends["native"] then
    local native_placement = task.resolve_placement(opts, "native", task_type)
    if native_placement == false or native_placement == nil then
      native_placement = (task_type == "ask" and "popup" or "vsplit")
    end
    local native_ui = task.resolve_task_ui(opts, "native")
    return M.backends["native"], "native", native_placement, native_ui, agent_opts
  end

  error("No valid sagani backend adapter found!")
end

return M
