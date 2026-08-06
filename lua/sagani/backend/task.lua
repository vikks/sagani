--- ==============================================================================
--- Module: sagani.backend.task
---
--- Description:
---   Task configuration resolver for sagani.nvim. Maps task types (ask, review,
---   code, chat) to flat agent options, execution commands, placement specs, and
---   UI styling options.
---
--- Responsibilities:
---   - Hierarchical agent options resolution (`resolve_task_agent`).
---   - CLI executable command string resolution (`resolve_agent_cmd`).
---   - UI & window styling options resolution (`resolve_task_ui`).
---   - Backend layout placement specifier resolution (`resolve_placement`).
--- ==============================================================================

local notify = require("sagani.notify")

local M = {}

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
    or (sagani._session_harness and sagani._session_harness ~= "" and sagani._session_harness:upper())
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

return M
