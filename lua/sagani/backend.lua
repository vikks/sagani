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

--- Resolves agent execution options for a given task type
--- @param opts table Configuration options
--- @param task_type string|nil Task identifier
--- @return table agent_opts Resolved agent options { harness, provider, model, effort, timeout }
function M.resolve_task_agent(opts, task_type)
  opts = type(opts) == "table" and opts or {}
  task_type = task_type or "chat"
  local task_val = opts.tasks and opts.tasks[task_type]

  local sagani = pcall(require, "sagani") and require("sagani") or {}
  local session_model = sagani._session_model
  local session_effort = sagani._session_effort

  local harness = opts.target_agent
  if type(task_val) == "string" and task_val ~= "" then
    harness = harness or task_val
  elseif type(task_val) == "table" then
    harness = harness or task_val.harness
  end
  harness = (harness or "agy"):lower()

  local h_prov_map = {
    agy = "google",
    antigravity = "google",
    gemini = "google",
    ["gemini-cli"] = "google",
    codex = "openai",
    hermes = "openai",
    opencode = "google",
  }

  local provider = (type(task_val) == "table" and task_val.provider) or h_prov_map[harness] or "google"

  local model = session_model or (type(task_val) == "table" and task_val.model)
  local effort = session_effort or (type(task_val) == "table" and task_val.effort)
  local timeout = type(task_val) == "table" and task_val.timeout
  local protocol = type(task_val) == "table" and task_val.protocol

  return {
    harness = harness,
    provider = provider,
    model = model,
    effort = effort,
    timeout = timeout,
    protocol = protocol,
  }
end

--- Resolves UI & window styling options for a given backend
--- @param opts table Configuration options
--- @param bname string Backend identifier
--- @return table ui_opts Resolved UI options { width, height, border, winblend, ratio }
function M.resolve_task_ui(opts, bname)
  opts = type(opts) == "table" and opts or {}
  local shared = opts.window_opts or {}
  local backend_cfg = (opts.backends and opts.backends[bname]) or {}

  return {
    width = backend_cfg.width or shared.width or 0.8,
    height = backend_cfg.height or shared.height or 0.8,
    border = backend_cfg.border or shared.border or "rounded",
    winblend = backend_cfg.winblend or shared.winblend or 0,
    ratio = backend_cfg.ratio or shared.ratio or 0.3,
  }
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

  -- 2. Hardcoded fallback
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
--- @return table ui_opts Resolved UI styling options
--- @return table agent_opts Resolved agent execution options
function M.get_backend(opts, task_type)
  opts = type(opts) == "table" and opts or {}
  task_type = task_type or "chat"
  local requested = opts.backend or "auto"

  local agent_opts = M.resolve_task_agent(opts, task_type)

  -- If user passed a custom adapter table directly
  if type(requested) == "table" then
    local placement = M.resolve_placement(opts, requested.name or "custom", task_type)
    local ui_opts = M.resolve_task_ui(opts, requested.name or "custom")
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

    local placement = M.resolve_placement(opts, name, task_type)
    -- Check capability / opt-out
    if placement == false then
      return nil -- Opted out for this task type
    end
    if candidate.capabilities and candidate.capabilities[task_type] == false then
      return nil -- Explicit capability opt-out
    end

    local ui_opts = M.resolve_task_ui(opts, name)
    return candidate, name, placement, ui_opts, agent_opts
  end

  -- If explicit backend string requested (other than "auto")
  if type(requested) == "string" and requested ~= "auto" then
    if M.backends[requested] then
      local placement = M.resolve_placement(opts, requested, task_type)
      local ui_opts = M.resolve_task_ui(opts, requested)
      if placement == false or (M.backends[requested].capabilities and M.backends[requested].capabilities[task_type] == false) then
        -- Task opted out on this backend -> fallback to native
        local native_placement = M.resolve_placement(opts, "native", task_type)
        local native_ui = M.resolve_task_ui(opts, "native")
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
    local native_placement = M.resolve_placement(opts, "native", task_type)
    if native_placement == false or native_placement == nil then
      native_placement = (task_type == "ask" and "popup" or "vsplit")
    end
    local native_ui = M.resolve_task_ui(opts, "native")
    return M.backends["native"], "native", native_placement, native_ui, agent_opts
  end

  error("No valid sagani backend adapter found!")
end

return M
