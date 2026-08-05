--- ==============================================================================
--- Module: sagani.state.session
---
--- Description:
---   Session state lifecycle manager for sagani.nvim. Handles setup re-initialization
---   resets (`reset_session`) and full session state purges (`clear_all`).
---
--- Responsibilities:
---   - Reset active operating mode, backend, agent, model, and effort session fields.
---   - Provide clear_all helper for complete state cleanup.
--- ==============================================================================

local mode_state = require("sagani.state.mode")
local backend_state = require("sagani.state.backend")
local agent_state = require("sagani.state.agent")
local model_state = require("sagani.state.model")
local effort_state = require("sagani.state.effort")

local M = {}

function M.reset_session()
	mode_state._session_mode = nil
	backend_state._session_backend = nil
	agent_state._session_agent = nil
	agent_state._session_harness = nil
	model_state._session_model = nil
	effort_state._session_effort = nil
end

function M.clear_all()
	M.reset_session()
	agent_state._session_ask_agent = nil
end

return M
