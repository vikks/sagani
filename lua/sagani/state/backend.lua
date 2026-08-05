--- ==============================================================================
--- Module: sagani.state.backend
---
--- Description:
---   Backend session state and switching manager for sagani.nvim. Manages active session
---   backend override (`_session_backend`) and provides set_backend and toggle_backend.
---
--- Responsibilities:
---   - Store active session backend override.
---   - Provide set_backend and toggle_backend interactive switching.
--- ==============================================================================

local notify = require("sagani.notify")

local M = {}

M._session_backend = nil

--- Toggles or explicitly sets active backend mode ("auto" vs "native" or custom)
--- @param mode_arg string|nil Optional backend mode string ("auto", "native", "herdr", "tmux", "zellij")
--- @param options table|nil Sagani options table
--- @return string active_backend Active backend mode
function M.toggle_backend(mode_arg, options)
	local opts = options or {}
	if mode_arg and mode_arg ~= "" then
		M._session_backend = mode_arg:lower()
	else
		local current = M._session_backend or opts.backend or "auto"
		if current == "auto" then
			M._session_backend = "native"
		else
			M._session_backend = "auto"
		end
	end

	local active_mode = (M._session_backend or "auto"):upper()
	notify.info(string.format("Sagani backend mode set to: %s", active_mode), opts)
	return M._session_backend
end

function M.set_backend(backend_name)
	if type(backend_name) == "string" and backend_name ~= "" then
		M._session_backend = backend_name:lower()
	else
		M._session_backend = nil
	end
	return M._session_backend
end

return M
