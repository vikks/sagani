--- ==============================================================================
--- Module: sagani.backend
---
--- Description:
---   Backend registry, environment auto-detection, layout placement, and agent
---   option resolver for sagani.nvim. Manages terminal multiplexer auto-detection
---   hierarchy (Herdr -> Tmux -> Zellij -> Native), maps task types to agent
---   execution options (opts.tasks), and resolves window placement specifications.
---
--- Responsibilities:
---   - Maintain backend adapter registry (backend.register).
---   - Auto-detect active terminal environment (backend.get_backend).
---   - Resolve flat agent execution options from task configurations.
---   - Resolve backend window placement & UI styling specs.
--- ==============================================================================

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
--- Performs hierarchical resolution: Session Override -> Inline Agent Table -> opts.agents Registry -> Harness String Fallback
--- @param opts table Configuration options
--- @param task_type string|nil Task identifier
--- @return table agent_opts Resolved agent options { agent_id, harness, provider, model, effort, alias, timeout, protocol, port, cmd, instructions, is_local }
function M.resolve_task_agent(opts, task_type)
  opts = type(opts) == "table" and opts or {}
  local sagani = pcall(require, "sagani") and require("sagani") or {}
  if sagani._session_mode and type(opts.tasks) == "table" and opts.tasks[sagani._session_mode] ~= nil then
    task_type = sagani._session_mode
  else
    task_type = task_type or "chat"
  end

  local task_val = opts.tasks and opts.tasks[task_type]

  local session_agent = sagani._session_agent or sagani._session_harness
  local session_model = sagani._session_model
  local session_effort = sagani._session_effort

  -- 1. Determine raw agent ID reference and task instructions
  local raw_agent_ref = nil
  local task_instructions = nil

  if type(task_val) == "string" and task_val ~= "" then
    raw_agent_ref = task_val
  elseif type(task_val) == "table" then
    raw_agent_ref = task_val.agent or task_val.harness
    if rawget(task_val, "harness") ~= nil then
      pcall(function()
        require("sagani").notify_deprecation(
          "task_harness_" .. tostring(task_type),
          string.format("Specifying 'harness' in opts.tasks.%s is deprecated. Use 'agent' instead.", tostring(task_type)),
          opts
        )
      end)
    end
    task_instructions = task_val.instructions or task_val.prompt_template
  end

  local agent_id = session_agent or (type(raw_agent_ref) == "string" and raw_agent_ref) or "agy"

  -- 2. Check for inline agent table or registry lookup in opts.agents
  local inline_agent = (type(raw_agent_ref) == "table") and raw_agent_ref or nil
  local registered_agent = (opts.agents and type(opts.agents[agent_id]) == "table") and opts.agents[agent_id] or nil
  local agent_cfg = inline_agent or registered_agent or {}

  -- 3. Resolve agent protocol driver name
  local harness = session_agent
    or agent_cfg.agent
    or agent_cfg.harness
    or (type(raw_agent_ref) == "string" and raw_agent_ref)
    or agent_id
    or "agy"
  harness = harness:lower()

  local h_prov_map = {
    agy = "google",
    antigravity = "google",
    gemini = "google",
    ["gemini-cli"] = "google",
    codex = "openai",
    hermes = "openai",
    opencode = "google",
  }

  local provider = agent_cfg.provider or (type(task_val) == "table" and task_val.provider) or h_prov_map[harness] or "google"
  local model = session_model or agent_cfg.model or (type(task_val) == "table" and task_val.model)
  local effort = session_effort or agent_cfg.effort or (type(task_val) == "table" and task_val.effort)

  local alias = (session_model and session_model ~= "") and session_model
    or (session_harness and session_harness ~= "" and session_harness:upper())
    or agent_cfg.name
    or agent_cfg.alias
    or (type(task_val) == "table" and task_val.alias)
    or harness:upper()

  local timeout = agent_cfg.timeout or (type(task_val) == "table" and task_val.timeout)
  local protocol = agent_cfg.protocol or (type(task_val) == "table" and task_val.protocol)
  local registered_harness_agent = (opts.agents and type(opts.agents[harness]) == "table") and opts.agents[harness] or nil
  local port = agent_cfg.port
    or (registered_harness_agent and registered_harness_agent.port)
    or (type(task_val) == "table" and task_val.port)
    or 4096

  local raw_cmd = agent_cfg.cmd or (type(task_val) == "table" and task_val.cmd) or { harness }
  local cmd = {}
  if type(raw_cmd) == "string" then
    cmd = { raw_cmd }
  elseif type(raw_cmd) == "table" then
    for _, arg in ipairs(raw_cmd) do
      table.insert(cmd, arg)
    end
  else
    cmd = { harness }
  end

  local instructions = task_instructions or agent_cfg.instructions
  local is_local = agent_cfg["local"] or agent_cfg.is_local or (type(task_val) == "table" and (task_val["local"] or task_val.is_local)) or false

  return {
    agent_id = agent_id,
    agent = harness,
    harness = harness,
    provider = provider,
    model = model,
    effort = effort,
    alias = alias,
    timeout = timeout,
    protocol = protocol,
    port = port,
    cmd = cmd,
    instructions = instructions,
    is_local = is_local,
  }
end

--- Resolves executable CLI command string for spawning agent terminal processes
--- @param agent_opts table Resolved agent options from backend.resolve_task_agent
--- @return string agent_cmd Executable command line string
function M.resolve_agent_cmd(agent_opts)
  if type(agent_opts) == "table" and agent_opts.cmd then
    if type(agent_opts.cmd) == "table" and #agent_opts.cmd > 0 then
      return table.concat(agent_opts.cmd, " ")
    elseif type(agent_opts.cmd) == "string" and agent_opts.cmd ~= "" then
      return agent_opts.cmd
    end
  end

  local harness = (type(agent_opts) == "table" and agent_opts.harness) or "agy"
  return harness
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
  local sagani = pcall(require, "sagani") and require("sagani") or {}
  if sagani._session_mode and opts and opts.backends and opts.backends[bname] and opts.backends[bname][sagani._session_mode] ~= nil then
    return opts.backends[bname][sagani._session_mode]
  end

  task_type = task_type or "chat"
  
  -- 1. Backend-specific task placement (exact task_type match under opts.backends[bname])
  if opts and opts.backends and opts.backends[bname] and opts.backends[bname][task_type] ~= nil then
    return opts.backends[bname][task_type]
  end

  -- 2. Fallback to default chat placement under opts.backends[bname]
  if opts and opts.backends and opts.backends[bname] and opts.backends[bname].chat ~= nil then
    return opts.backends[bname].chat
  end

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
