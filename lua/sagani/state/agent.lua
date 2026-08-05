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
