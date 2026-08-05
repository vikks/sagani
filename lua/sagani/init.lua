local notify = require("sagani.notify")
local format = require("sagani.format")
local selection = require("sagani.selection")
local diff = require("sagani.diff")
local backend = require("sagani.backend")
local keymaps = require("sagani.keymaps")
local commands = require("sagani.commands")
local watchers = require("sagani.watchers")
local picker = require("sagani.ui.picker")
local defaults = require("sagani.defaults")
local deprecations = require("sagani.deprecations")
local dispatchers = require("sagani.dispatchers")

-- Register Built-in Backend Providers
backend.register("native", require("sagani.backend.native"))
backend.register("herdr", require("sagani.backend.herdr"))
backend.register("tmux", require("sagani.backend.tmux"))
backend.register("zellij", require("sagani.backend.zellij"))

local M = {}

M.defaults = defaults.defaults
M.options = defaults.ensure_compat_getters(vim.tbl_deep_extend("force", {}, M.defaults))

M._session_ask_agent = nil
M._session_agent = nil
M._session_harness = nil
M._session_model = nil
M._session_effort = nil
M._session_backend = nil
M._session_mode = nil

M.format = format
M.selection = selection
M.diff = diff

setmetatable(M, {
	__index = function(_, k)
		if k == "_deprecation_warned" then
			return deprecations._deprecation_warned
		end
		return nil
	end,
	__newindex = function(_, k, v)
		if k == "_deprecation_warned" then
			deprecations._deprecation_warned = v
		else
			rawset(M, k, v)
		end
	end,
})

function M.notify_deprecation(key, msg, opts)
	return deprecations.notify_deprecation(key, msg, opts)
end

--- Sets or explicitly toggles active operating mode ("review", "learn", or custom)
--- @param mode_arg string|nil Target mode identifier
--- @return string|nil active_mode Active mode identifier or nil
function M.set_mode(mode_arg)
	if type(mode_arg) == "string" and mode_arg ~= "" then
		local m = mode_arg:lower()
		if m == "off" or m == "none" or m == "normal" then
			M._session_mode = nil
			notify.info("Sagani operating mode: OFF (standard operation)", M.options)
		else
			M._session_mode = m
			notify.info(string.format("Sagani operating mode set to: %s", m:upper()), M.options)
			if not (M.options and type(M.options.tasks) == "table" and M.options.tasks[m] ~= nil) then
				notify.warn(
					string.format(
						"Mode '%s' has no matching task configuration in 'opts.tasks.%s'. Operations will fall back to default task settings.\nTo customize this mode, define:\n  tasks = {\n    %s = { agent = \"<agent>\", instructions = \"...\" }\n  }",
						m,
						m,
						m
					),
					M.options
				)
			end
		end
	else
		local current = M._session_mode
		if not current then
			M.set_mode("review")
		elseif current == "review" then
			M.set_mode("learn")
		else
			M.set_mode("off")
		end
	end
	return M._session_mode
end

--- Toggles specific mode on or off
--- @param mode_arg string|nil Target mode string ("review", "learn")
--- @return string|nil active_mode
function M.toggle_mode(mode_arg)
	if type(mode_arg) == "string" and mode_arg ~= "" then
		local m = mode_arg:lower()
		if M._session_mode == m then
			M._session_mode = nil
			notify.info(string.format("Sagani mode '%s' disabled", m), M.options)
		else
			M.set_mode(m)
		end
	else
		return M.set_mode(nil)
	end
	return M._session_mode
end

--- Toggles or explicitly sets active backend mode ("auto" vs "native" or custom)
--- @param mode_arg string|nil Optional backend mode string ("auto", "native", "herdr", "tmux", "zellij")
--- @return string active_backend Active backend mode
function M.toggle_backend(mode_arg)
	if mode_arg and mode_arg ~= "" then
		M._session_backend = mode_arg:lower()
	else
		local current = M._session_backend or M.options.backend or "auto"
		if current == "auto" then
			M._session_backend = "native"
		else
			M._session_backend = "auto"
		end
	end

	local active_mode = (M._session_backend or "auto"):upper()
	notify.info(string.format("Sagani backend mode set to: %s", active_mode), M.options)
	return M._session_backend
end

--- Setup function called by LazyVim plugin spec or user init.lua
--- @param user_opts table|nil User configuration options
function M.setup(user_opts)
	user_opts = type(user_opts) == "table" and user_opts or {}
	deprecations.check_deprecations(user_opts)
	M.options = defaults.ensure_compat_getters(vim.tbl_deep_extend("force", M.defaults, user_opts))
	M._session_agent = nil
	M._session_harness = nil
	M._session_model = nil
	M._session_effort = nil
	M._session_backend = nil
	M._session_mode = nil

	keymaps.setup_keymaps(M.options)
	commands.register_commands(M.options)
	watchers.setup_watchers(M.options)
end

--- Delegates agent selection UI to picker submodule
function M.select_agent(arg, opts, on_complete)
	return picker.select_agent_harness(arg, opts or M.options, on_complete)
end

--- Alias for select_agent for backward compatibility
function M.select_agent_harness(arg, opts, on_complete)
	return M.select_agent(arg, opts, on_complete)
end

--- Asks a general question/prompt to an agent in a Herdr popup or floating window
--- @param prompt_text string|nil User prompt or nil to prompt interactively
--- @param opts table|nil Options table
function M.ask_agent_prompt(prompt_text, opts)
	return dispatchers.ask_agent_prompt(prompt_text, opts)
end

--- Main prompt dispatch router entry point
--- @param prompt_text string Prompt text
--- @param target_pane string|nil Target pane handle
--- @param opts table|nil Options table
--- @return boolean ok, string|nil err
function M.dispatch_prompt(prompt_text, target_pane, opts)
	return dispatchers.dispatch_prompt(prompt_text, target_pane, opts)
end

return M
