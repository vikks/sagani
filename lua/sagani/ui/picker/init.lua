--- ==============================================================================
--- Module: sagani.ui.picker
---
--- Description:
---   Interactive selection picker UI for agent harness selection, target pane
---   selection, and operating mode toggles. Re-exports submodules under lua/sagani/ui/picker/
---   (agent, target, mode) as a clean facade.
---
--- Responsibilities:
---   - Re-export agent harness, target pane, and operating mode selection pickers.
--- ==============================================================================

local agent = require("sagani.ui.picker.agent")
local target = require("sagani.ui.picker.target")
local mode = require("sagani.ui.picker.mode")

local M = {}

M.supports_effort = agent.supports_effort
M.prompt_model_and_effort = agent.prompt_model_and_effort
M.select_agent_harness = agent.select_agent_harness

M.select_target_pane = target.select_target_pane

M.select_mode = mode.select_mode

return M
