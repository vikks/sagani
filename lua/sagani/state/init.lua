local mode = require("sagani.state.mode")
local backend = require("sagani.state.backend")
local agent = require("sagani.state.agent")
local model = require("sagani.state.model")
local effort = require("sagani.state.effort")
local session = require("sagani.state.session")

local M = {
	mode = mode,
	backend = backend,
	agent = agent,
	model = model,
	effort = effort,
	session = session,
}

setmetatable(M, {
	__index = function(_, k)
		if k == "_session_mode" then
			return mode._session_mode
		elseif k == "_session_backend" then
			return backend._session_backend
		elseif k == "_session_agent" then
			return agent._session_agent
		elseif k == "_session_harness" then
			return agent._session_harness
		elseif k == "_session_ask_agent" then
			return agent._session_ask_agent
		elseif k == "_session_model" then
			return model._session_model
		elseif k == "_session_effort" then
			return effort._session_effort
		end
		return nil
	end,

	__newindex = function(_, k, v)
		if k == "_session_mode" then
			mode._session_mode = v
		elseif k == "_session_backend" then
			backend._session_backend = v
		elseif k == "_session_agent" then
			agent._session_agent = v
			agent._session_harness = v
		elseif k == "_session_harness" then
			agent._session_harness = v
			agent._session_agent = v
		elseif k == "_session_ask_agent" then
			agent._session_ask_agent = v
		elseif k == "_session_model" then
			model._session_model = v
		elseif k == "_session_effort" then
			effort._session_effort = v
		else
			rawset(M, k, v)
		end
	end,
})

function M.set_mode(mode_arg, options)
	return mode.set_mode(mode_arg, options)
end

function M.toggle_mode(mode_arg, options)
	return mode.toggle_mode(mode_arg, options)
end

function M.toggle_backend(mode_arg, options)
	return backend.toggle_backend(mode_arg, options)
end

function M.set_backend(backend_name)
	return backend.set_backend(backend_name)
end

function M.reset_session()
	return session.reset_session()
end

return M
