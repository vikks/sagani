--- ==============================================================================
--- Module: sagani.resolver
---
--- Description:
---   Single-pass deterministic resolution pipeline compiler for sagani.nvim.
---   Transforms raw user requests, task configurations, session state, and backend
---   environment into a 100% resolved, immutable ExecutionPlan table.
---
--- Responsibilities:
---   - Resolve active agent harness and declarative agent capabilities.
---   - Resolve active backend transport and backend geometry capabilities.
---   - Resolve UI geometry and window styling parameters.
---   - Return a frozen ExecutionPlan struct with zero runtime ambiguity.
--- ==============================================================================

local backend_registry = require("sagani.backend.registry")
local task_resolver = require("sagani.backend.task")
local agents_registry = require("sagani.agents")

local M = {}

--- Builds an immutable ExecutionPlan for a task dispatch request
--- @param task_type string Task type ("ask", "chat", "code", "review", "learn", etc.)
--- @param raw_prompt string|nil Raw prompt or visual selection input
--- @param opts table Resolved plugin options table
--- @param session_state table|nil Active session state overrides
--- @param env_overrides table|nil Environment overrides for testing
--- @return table ExecutionPlan immutable table
function M.build_plan(task_type, raw_prompt, opts, session_state, env_overrides)
  opts = opts or require("sagani.defaults").defaults
  session_state = session_state or {}
  task_type = task_type or "ask"
  raw_prompt = raw_prompt or ""

  -- 1. Resolve Target Agent ID
  local sagani_mod = pcall(require, "sagani") and require("sagani") or {}
  local task_config = opts.tasks and opts.tasks[task_type]
  local task_agent_id = nil
  if type(task_config) == "string" then
    task_agent_id = task_config
  elseif type(task_config) == "table" then
    task_agent_id = task_config.agent or task_config.harness
  end

  local session_harness = session_state._session_harness or sagani_mod._session_harness
  local target_override = opts.target_agent or (type(opts.ask_agent) == "table" and opts.ask_agent.target_agent)
  local agent_id = session_harness or target_override or task_agent_id or "agy"
  local agent_mod = agents_registry.get(agent_id) or agents_registry.get("agy")

  -- 2. Resolve Agent Execution Parameters & Capabilities
  local agent_opts = task_resolver.resolve_task_agent(opts, task_type)
  agent_opts.harness = agent_id
  agent_opts.agent = agent_id

  local protocol = session_state._session_protocol or agent_opts.protocol or (agent_mod and agent_mod.capabilities and agent_mod.capabilities.default_protocol) or "cli"
  local cmd = (agent_mod and agent_mod.build_cmd) and agent_mod.build_cmd(agent_opts) or { agent_id }

  local agent_plan = {
    id = agent_id,
    name = (agent_mod and agent_mod.name) or agent_id,
    cmd = cmd,
    provider = agent_opts.provider or (agent_mod and agent_mod.default_provider) or "google",
    model = session_state._session_model or agent_opts.model or (agent_mod and agent_mod.default_model) or "gemini-2.5-flash",
    effort = session_state._session_effort or agent_opts.effort or "medium",
    protocol = protocol,
    port = agent_opts.port or (agent_mod and agent_mod.default_port) or 4096,
    timeout = agent_opts.timeout or 30000,
    capabilities = (agent_mod and agent_mod.capabilities) or {},
  }

  -- 3. Resolve Backend Adapter & Placement Capabilities
  local adapter, backend_name, placement, ui_opts, resolved_agent_opts = backend_registry.get_backend(opts, task_type)
  local backend_caps = adapter and adapter.capabilities or {}

  -- Capability Matcher: If placement is "popup" but backend float capability is false, redirect to native
  local final_backend_name = backend_name
  local final_adapter = adapter
  local final_placement = placement

  if placement == "popup" and backend_caps.float == false then
    local native_adapter = backend_registry.backends["native"]
    if native_adapter then
      final_backend_name = "native"
      final_adapter = native_adapter
      backend_caps = native_adapter.capabilities or {}
    end
  end

  local backend_plan = {
    name = final_backend_name,
    adapter = final_adapter,
    placement = final_placement,
    capabilities = backend_caps,
  }

  -- 4. Resolve UI Geometry
  local ui_plan = {
    placement = final_placement,
    split_direction = (final_placement == "vsplit" or final_placement == "right-pane") and "vertical" or "horizontal",
    width = ui_opts and ui_opts.width or 0.8,
    height = ui_opts and ui_opts.height or 0.8,
    border = ui_opts and ui_opts.border or "rounded",
    winblend = ui_opts and ui_opts.winblend or 0,
  }

  -- 5. Build Final ExecutionPlan Struct
  local plan = {
    task_type = task_type,
    agent = agent_plan,
    backend = backend_plan,
    ui = ui_plan,
    payload = {
      raw_prompt = raw_prompt,
      formatted_prompt = raw_prompt,
      bufnr = vim.api.nvim_get_current_buf(),
    },
  }

  return plan
end

return M
