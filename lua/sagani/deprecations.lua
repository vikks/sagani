--- ==============================================================================
--- Module: sagani.deprecations
---
--- Description:
---   Deprecation tracking and warning notification system for sagani.nvim.
---   Inspects user configuration options for legacy keys (target_agent, ask_agent,
---   ports, harness properties) and issues deduplicated single-session warnings.
---
--- Responsibilities:
---   - Inspect user_opts for deprecated configuration keys.
---   - Issue deduplicated warning notifications via notify.warn.
--- ==============================================================================

local notify = require("sagani.notify")

local M = {}

M._deprecation_warned = {}

function M.notify_deprecation(key, msg, opts)
	if not M._deprecation_warned[key] then
		M._deprecation_warned[key] = true
		notify.warn("[sagani.nvim] Deprecation Warning: " .. msg, opts)
	end
end

function M.check_deprecations(user_opts)
	if type(user_opts) ~= "table" then
		return
	end

	if rawget(user_opts, "target_agent") ~= nil then
		M.notify_deprecation(
			"target_agent",
			"'target_agent' is deprecated. Configure 'opts.tasks.chat = \"<agent>\"' instead.",
			user_opts
		)
	end

	if rawget(user_opts, "ask_agent") ~= nil then
		M.notify_deprecation(
			"ask_agent",
			"'opts.ask_agent' is deprecated. Configure 'opts.tasks.ask = { agent = \"<agent>\" }' instead.",
			user_opts
		)
	end

	if rawget(user_opts, "ports") ~= nil then
		M.notify_deprecation(
			"ports",
			"'opts.ports' is deprecated. Move port options directly under 'opts.agents.<agent_id>.port'.",
			user_opts
		)
	end

	if type(user_opts.tasks) == "table" then
		for t_name, t_val in pairs(user_opts.tasks) do
			if type(t_val) == "table" and rawget(t_val, "harness") ~= nil then
				M.notify_deprecation(
					"task_harness_" .. t_name,
					string.format("Specifying 'harness' in opts.tasks.%s is deprecated. Use 'agent' instead.", t_name),
					user_opts
				)
			end
		end
	end

	if type(user_opts.agents) == "table" then
		for a_name, a_val in pairs(user_opts.agents) do
			if type(a_val) == "table" and rawget(a_val, "harness") ~= nil then
				M.notify_deprecation(
					"agent_harness_" .. a_name,
					string.format("Specifying 'harness' in opts.agents.%s is deprecated. Use 'agent' or omit it.", a_name),
					user_opts
				)
			end
		end
	end
end

return M
