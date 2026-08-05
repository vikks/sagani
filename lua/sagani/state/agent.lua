--- ==============================================================================
--- Module: sagani.state.agent
---
--- Description:
---   Agent harness session state manager for sagani.nvim. Holds active session
---   overrides for target agent harness (`_session_agent`, `_session_harness`) and
---   ask agent popup target (`_session_ask_agent`).
---
--- Responsibilities:
---   - Store and retrieve active session agent harness overrides.
--- ==============================================================================

local M = {}

M._session_agent = nil
M._session_harness = nil
M._session_ask_agent = nil

function M.set_agent(agent_name)
	if type(agent_name) == "string" and agent_name ~= "" then
		M._session_agent = agent_name
		M._session_harness = agent_name
	else
		M._session_agent = nil
		M._session_harness = nil
	end
	return M._session_agent
end

return M
