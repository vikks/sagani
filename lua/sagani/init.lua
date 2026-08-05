local notify = require("sagani.notify")
local format = require("sagani.format")
local selection = require("sagani.selection")
local diff = require("sagani.diff")
local backend = require("sagani.backend")
local keymaps = require("sagani.keymaps")
local commands = require("sagani.commands")
local watchers = require("sagani.watchers")
local picker = require("sagani.ui.picker")

-- Register Built-in Backend Providers
backend.register("native", require("sagani.backend.native"))
backend.register("herdr", require("sagani.backend.herdr"))
backend.register("tmux", require("sagani.backend.tmux"))
backend.register("zellij", require("sagani.backend.zellij"))

local M = {}

M.defaults = {
	window_opts = {
		width = 0.8,
		height = 0.8,
		border = "rounded",
		winblend = 0,
		ratio = 0.3,
	},

	--- capabilities and layout stuff
	backends = {
		native = {
			ask = "popup",
			review = "vsplit",
			code = "vsplit",
			chat = "vsplit",
			border = "rounded",
			winblend = 0,
			split_direction = "vertical",
		},
		herdr = {
			ask = false,
			review = "right-pane",
			code = "right-pane",
			chat = "right-pane",
			ratio = 0.3,
			auto_discover = true,
			auto_spawn = false,
		},
		tmux = {
			ask = "popup",
			review = "right-pane",
			code = "right-pane",
			chat = "right-pane",
			width = "80%",
			height = "80%",
			border = "rounded",
			split_direction = "right",
			target_pane = nil,
		},
		zellij = {
			ask = "floating",
			review = "right-pane",
			code = "right-pane",
			chat = "right-pane",
			direction = "right",
		},
	},

	providers = {
		google = { api_key_env = "GEMINI_API_KEY", alias = "Google Gemini" },
		openai = { api_key_env = "OPENAI_API_KEY", alias = "OpenAI" },
		anthropic = { api_key_env = "ANTHROPIC_API_KEY", alias = "Anthropic" },
	},

	-- Agent Definitions Registry (Logical Agent ID -> Actual Execution Command)
	agents = {
		agy = {
			cmd = { "agy" },
			name = "Antigravity CLI",
		},
		codex = {
			cmd = { "codex" },
			name = "Codex CLI",
		},
		opencode = {
			cmd = { "opencode" },
			name = "Opencode Agent",
			port = 4096,
		},
		hermes = {
			cmd = { "hermes" },
			name = "Hermes Agent",
		},
		gemini = {
			cmd = { "gemini" },
			name = "Gemini CLI",
		},
	},

	-- Configuration for agents grouped by tasks (built-in or custom user tasks)
	tasks = {
		chat = "agy",
		ask = {
			agent = "agy",
			backend = "native",
			instructions = "Answer the user's question concisely and accurately.",
		},
		review = {
			agent = "codex",
			instructions = "Review the provided code changes and offer actionable feedback.",
		},
		code = {
			agent = "opencode",
			instructions = "Fulfill the user's coding request directly in the buffer.",
		},
	},
	auto_discover = true,
	auto_spawn = false,
	pane_override = nil,
	default_keymaps = true,
	which_key = true,
	notify = {
		enabled = true,
		title = "sagani.nvim",
	},
}

--- Ensures backward compatibility for legacy opts.ask_agent and opts.review property access
local function ensure_compat_getters(opts)
	if type(opts) ~= "table" then
		return opts
	end

	-- If raw review table exists, backfill default values if missing
	local raw_review = rawget(opts, "review")
	if type(raw_review) == "table" then
		if raw_review.enabled == nil then
			raw_review.enabled = true
		end
		if raw_review.auto_open == nil then
			raw_review.auto_open = false
		end
		if raw_review.mode == nil then
			raw_review.mode = "inline"
		end
	end

	setmetatable(opts, {
		__index = function(t, k)
			if k == "ask_agent" then
				local ask_task = type(t.tasks) == "table" and t.tasks.ask or {}
				local agent_name = (type(ask_task) == "string" and ask_task)
					or (type(ask_task) == "table" and ask_task.agent)
				return {
					target_agent = agent_name,
					popup = true,
				}
			elseif k == "review" then
				local review_task = type(t.tasks) == "table" and t.tasks.review or {}
				return {
					enabled = true,
					auto_open = false,
					mode = "inline",
					agent = (type(review_task) == "string" and review_task)
						or (type(review_task) == "table" and review_task.agent)
						or "codex",
				}
			end
			return nil
		end,
	})

	return opts
end

M.options = ensure_compat_getters(vim.tbl_deep_extend("force", {}, M.defaults))
M._session_ask_agent = nil
M._session_agent = nil
M._session_harness = nil
M._session_model = nil
M._session_effort = nil
M._session_backend = nil

M.format = format
M.selection = selection
M.diff = diff

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
	M.options = ensure_compat_getters(vim.tbl_deep_extend("force", M.defaults, user_opts))
	M._session_agent = nil
	M._session_harness = nil
	M._session_model = nil
	M._session_effort = nil
	M._session_backend = nil

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
	opts = vim.tbl_deep_extend("force", M.options, type(opts) == "table" and opts or {})
	local ask_opts = type(opts.ask_agent) == "table" and opts.ask_agent or {}

	local function do_ask(agent_name, text)
		if not agent_name or agent_name == "" then
			notify.warn("No target agent selected for general questions", opts)
			return
		end

		if not text or text == "" then
			vim.ui.input({ prompt = string.format("Ask Agent (%s): ", agent_name:upper()) }, function(input)
				if input and input ~= "" then
					do_ask(agent_name, input)
				end
			end)
			return
		end

		local full_name = vim.api.nvim_buf_get_name(0)
		if full_name and full_name ~= "" and not text:find("@%[") then
			local abs_path = vim.fn.fnamemodify(full_name, ":p")
			if abs_path and abs_path ~= "" then
				text = string.format("%s @[%s]", text, abs_path)
			end
		end

		local adapter, backend_name, placement, ui_opts, agent_opts = backend.get_backend(opts, "ask")
		local harness = (type(agent_name) == "string" and agent_name ~= "") and agent_name
			or (agent_opts and agent_opts.harness)
			or "agy"
		agent_opts.harness = harness
		local popup_opts = vim.tbl_deep_extend("force", opts, {
			adapter = adapter,
			backend_name = backend_name,
			task_type = "ask",
			placement = placement,
			ui_opts = ui_opts,
			agent_opts = agent_opts,
		})

		if agent_opts and agent_opts.protocol == "acp" then
			local markdown_popup = require("sagani.ui.markdown_popup")
			local acp = require("sagani.protocol.acp")

			local display_name = (agent_opts and agent_opts.alias) or harness:upper()
			local win, buf = markdown_popup.open(string.format("Sagani Agent (%s)", display_name), popup_opts)
			markdown_popup.set_prompt_header(buf, text, display_name)
			pcall(vim.cmd, "redraw")

			local progress_cb = function(status_msg)
				vim.schedule(function()
					markdown_popup.update_status(buf, status_msg)
					pcall(vim.cmd, "redraw")
				end)
			end

			acp.execute_prompt(harness, text, agent_opts, function(resp, acp_err, session_id)
				markdown_popup.set_session(buf, harness, session_id, agent_opts, popup_opts)
				if resp then
					markdown_popup.set_response(buf, resp)
					notify.info(string.format("Received response from '%s' via ACP", harness), opts)
				else
					markdown_popup.set_response(buf, "❌ Error: " .. (acp_err or "Unknown ACP error"))
					notify.error(
						string.format("ACP request to '%s' failed: %s", harness, acp_err or "Unknown error"),
						opts
					)
				end
			end, opts, progress_cb)
			return
		end

		local agent_target, err, meta
		if placement == "popup" or placement == "floating" then
			agent_target, err, meta = adapter.spawn_popup(popup_opts)
		else
			agent_target, err, meta = adapter.spawn_pane(popup_opts)
		end

		if agent_target then
			local display_pane = (meta and meta.pane_id) or agent_target
			local ok, dispatch_err = M.dispatch_prompt(text, agent_target, popup_opts)
			if ok then
				notify.info(
					string.format("Asked '%s' agent in %s pane '%s'", agent_name, backend_name, display_pane),
					opts
				)
			else
				notify.error(
					string.format(
						"Failed to prompt '%s' in %s pane '%s': %s",
						agent_name,
						backend_name,
						display_pane,
						dispatch_err or "Unknown error"
					),
					opts
				)
			end
		else
			notify.error(string.format("Failed to spawn %s agent pane: %s", backend_name, err or "Unknown error"), opts)
		end
	end

	local task_val = opts.tasks and opts.tasks.ask
	local has_config = ask_opts.target_agent
		or M._session_harness
		or (task_val and (type(task_val) == "string" or (type(task_val) == "table" and (task_val.agent or task_val.harness))))

	if not has_config and not _G.RUNNING_TEST_SUITE and vim.ui and vim.ui.select then
		notify.info("No active agent harness configured for 'ask'. Please select your target agent harness:", opts)
		M.select_agent_harness(nil, opts, function(selected_harness)
			do_ask(selected_harness, prompt_text)
		end)
		return
	end

	local task_agent = backend.resolve_task_agent(opts, "ask")
	local configured_agent = ask_opts.target_agent or (task_agent and task_agent.harness)
	local agent_name = (type(configured_agent) == "string" and configured_agent ~= "") and configured_agent or "agy"
	do_ask(agent_name, prompt_text)
end

--- Main prompt dispatch router entry point
--- @param prompt_text string Prompt text
--- @param target_pane string|nil Target pane handle
--- @param opts table|nil Options table
--- @return boolean ok, string|nil err
function M.dispatch_prompt(prompt_text, target_pane, opts)
	opts = type(opts) == "table" and opts or M.options
	if type(prompt_text) ~= "string" or prompt_text == "" then
		local err_msg = "Invalid prompt text: must be a non-empty string"
		notify.error(err_msg, opts)
		return false, err_msg
	end

	local cur_buf = vim.api.nvim_get_current_buf()
	if cur_buf and vim.api.nvim_buf_is_valid(cur_buf) then
		diff.take_snapshot(cur_buf)
	end

	if target_pane == "" then
		target_pane = nil
	end

	local adapter = opts.adapter
	local backend_name = opts.backend_name
	if not adapter then
		local task_type = opts.task_type or "chat"
		adapter, backend_name = backend.get_backend(opts, task_type)
	end

	local pane_override = (type(opts.pane_override) == "string" and opts.pane_override ~= "") and opts.pane_override
		or (type(opts.pane_override) == "number" and tostring(opts.pane_override) or nil)
	local pane_id = target_pane or pane_override
	local err, meta

	if not pane_id then
		pane_id, err, meta = adapter.discover_target(opts)
	end

	if not pane_id then
		notify.error(
			string.format("Cannot dispatch prompt (%s): %s", backend_name, err or "Target pane not found"),
			opts
		)
		return false, err
	end

	if meta and meta.spawned then
		notify.info(string.format("Agent initializing... Prompt queued for automatic delivery to %s", pane_id), opts)
		if type(adapter.wait_for_ready) == "function" then
			adapter.wait_for_ready(pane_id, opts)
		end
	end

	local ok, send_err = adapter.prompt_target(pane_id, prompt_text, opts)
	if not ok then
		local msg = string.format("Failed to prompt agent pane '%s' (%s)", pane_id, send_err or "Unknown error")
		notify.error(msg, opts)
		return false, msg
	end

	local active_harness = (opts.agent_opts and opts.agent_opts.harness) or M._session_harness or "agy"
	notify.info(string.format("Prompt dispatched to %s via %s backend", active_harness:upper(), backend_name), opts)

	vim.schedule(function()
		pcall(vim.cmd, "checktime")
		local review_opts = type(opts.review) == "table" and opts.review or {}
		local enabled = (type(opts.review) == "boolean" and opts.review) or (review_opts.enabled ~= false)
		local auto_open = (type(review_opts) == "table") and review_opts.auto_open or false

		if enabled and auto_open then
			local hunks = diff.get_hunks(cur_buf)
			if #hunks > 0 then
				diff.open_review(cur_buf, opts)
			end
		end
	end)

	return true, nil
end

return M
