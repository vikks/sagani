local M = {}

M._session_effort = nil

function M.set_effort(effort_val)
	if type(effort_val) == "string" and effort_val ~= "" then
		M._session_effort = effort_val
	else
		M._session_effort = nil
	end
	return M._session_effort
end

return M
