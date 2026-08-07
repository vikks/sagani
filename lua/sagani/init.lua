--- ==============================================================================
--- Module: sagani.init
---
--- Description:
---   Lean facade entry point and setup interface for sagani.nvim. Initializes default
---   configuration options, registers user commands, binds keymaps, sets up autocmd
---   watchers, registers built-in backend adapters, and delegates prompt execution
---   and session state handling to dedicated submodules.
---
--- Responsibilities:
---   - Primary M.setup(user_opts) entry point for user initialization.
---   - Register built-in backend adapters (native, herdr, tmux, zellij).
---   - Delegate prompt dispatching to sagani.dispatchers package.
---   - Delegate session state & operating modes to sagani.state package.
--- ==============================================================================

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
local dispatchers = require("sagani.dispatchers")
local state = require("sagani.state")

-- Register Built-in Backend Providers
backend.register("native", require("sagani.backend.native"))
backend.register("herdr", require("sagani.backend.herdr"))
backend.register("tmux", require("sagani.backend.tmux"))
backend.register("zellij", require("sagani.backend.zellij"))

local M = {}

M.defaults = defaults.defaults
M.options = vim.tbl_deep_extend("force", {}, M.defaults)
M.format = format
M.selection = selection
M.diff = diff
M.state = state

setmetatable(M, {
	__index = function(_, k)
		if k == "_session_mode" then
			return state.mode._session_mode
		elseif k == "_session_backend" then
			return state.backend._session_backend
		elseif k == "_session_agent" then
			return state.agent._session_agent
		elseif k == "_session_harness" then
			return state.agent._session_harness
		elseif k == "_session_ask_agent" then
			return state.agent._session_ask_agent
		elseif k == "_session_model" then
			return state.model._session_model
		elseif k == "_session_effort" then
			return state.effort._session_effort
		end
		return nil
	end,

	__newindex = function(_, k, v)
		if k == "_session_mode" then
			state.mode._session_mode = v
		elseif k == "_session_backend" then
			state.backend._session_backend = v
		elseif k == "_session_agent" then
			state.agent._session_agent = v
			state.agent._session_harness = v
		elseif k == "_session_harness" then
			state.agent._session_harness = v
			state.agent._session_agent = v
		elseif k == "_session_ask_agent" then
			state.agent._session_ask_agent = v
		elseif k == "_session_model" then
			state.model._session_model = v
		elseif k == "_session_effort" then
			state.effort._session_effort = v
		else
			rawset(M, k, v)
		end
	end,
})

function M.set_mode(mode_arg)
	return state.set_mode(mode_arg, M.options)
end

function M.toggle_mode(mode_arg)
	return state.toggle_mode(mode_arg, M.options)
end

function M.toggle_backend(mode_arg)
	return state.toggle_backend(mode_arg, M.options)
end

function M.setup(user_opts)
	user_opts = type(user_opts) == "table" and user_opts or {}
	require("sagani.config.validator").validate(user_opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, user_opts)
	state.reset_session()

	keymaps.setup_keymaps(M.options)
	commands.register_commands(M.options)
	watchers.setup_watchers(M.options)
end

function M.select_agent(arg, opts, on_complete)
	return picker.select_agent_harness(arg, opts or M.options, on_complete)
end

function M.select_agent_harness(arg, opts, on_complete)
	return M.select_agent(arg, opts, on_complete)
end

function M.select_target_pane(opts, on_complete)
	return picker.select_target_pane(opts or M.options, on_complete)
end

function M.ask_agent_prompt(prompt_text, opts)
	return dispatchers.ask_agent_prompt(prompt_text, opts)
end

function M.dispatch_prompt(prompt_text, target_pane, opts)
	return dispatchers.dispatch_prompt(prompt_text, target_pane, opts)
end

return M
