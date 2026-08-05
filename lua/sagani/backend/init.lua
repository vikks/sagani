--- ==============================================================================
--- Module: sagani.backend
---
--- Description:
---   Backend registry, environment auto-detection, layout placement, and agent
---   option resolver for sagani.nvim. Re-exports submodules under lua/sagani/backend/
---   (registry, task) as a clean facade.
---
--- Responsibilities:
---   - Maintain backend adapter registry (backend.register).
---   - Auto-detect active terminal environment (backend.get_backend).
---   - Resolve flat agent execution options from task configurations.
---   - Resolve backend window placement & UI styling specs.
--- ==============================================================================

local registry = require("sagani.backend.registry")
local task = require("sagani.backend.task")

local M = {}

M.backends = registry.backends
M.register = registry.register
M.get_backend = registry.get_backend

M.resolve_task_agent = task.resolve_task_agent
M.resolve_agent_cmd = task.resolve_agent_cmd
M.resolve_task_ui = task.resolve_task_ui
M.resolve_placement = task.resolve_placement

return M
