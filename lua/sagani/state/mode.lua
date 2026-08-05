local notify = require("sagani.notify")

local M = {}

M._session_mode = nil

--- Sets or explicitly toggles active operating mode ("review", "learn", or custom)
--- @param mode_arg string|nil Target mode identifier
--- @param options table|nil Sagani options table
--- @return string|nil active_mode Active mode identifier or nil
function M.set_mode(mode_arg, options)
	local opts = options or {}
	if type(mode_arg) == "string" and mode_arg ~= "" then
		local m = mode_arg:lower()
		if m == "off" or m == "none" or m == "normal" then
			M._session_mode = nil
			notify.info("Sagani operating mode: OFF (standard operation)", opts)
		else
			M._session_mode = m
			notify.info(string.format("Sagani operating mode set to: %s", m:upper()), opts)
			if not (opts and type(opts.tasks) == "table" and opts.tasks[m] ~= nil) then
				notify.warn(
					string.format(
						"Mode '%s' has no matching task configuration in 'opts.tasks.%s'. Operations will fall back to default task settings.\nTo customize this mode, define:\n  tasks = {\n    %s = { agent = \"<agent>\", instructions = \"...\" }\n  }",
						m,
						m,
						m
					),
					opts
				)
			end
		end
	else
		local current = M._session_mode
		if not current then
			M.set_mode("review", opts)
		elseif current == "review" then
			M.set_mode("learn", opts)
		else
			M.set_mode("off", opts)
		end
	end
	return M._session_mode
end

--- Toggles specific mode on or off
--- @param mode_arg string|nil Target mode string ("review", "learn")
--- @param options table|nil Sagani options table
--- @return string|nil active_mode
function M.toggle_mode(mode_arg, options)
	local opts = options or {}
	if type(mode_arg) == "string" and mode_arg ~= "" then
		local m = mode_arg:lower()
		if M._session_mode == m then
			M._session_mode = nil
			notify.info(string.format("Sagani mode '%s' disabled", m), opts)
		else
			M.set_mode(m, opts)
		end
	else
		return M.set_mode(nil, opts)
	end
	return M._session_mode
end

return M
