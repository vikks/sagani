local notify = require("sagani.notify")
local diff = require("sagani.diff")
local backend = require("sagani.backend")

local M = {}

--- Asks a general question/prompt to an agent in a Herdr popup or floating window
--- @param prompt_text string|nil User prompt or nil to prompt interactively
--- @param opts table|nil Options table
function M.ask_agent_prompt(prompt_text, opts)
	local sagani = package.loaded["sagani"] or require("sagani")
	opts = vim.tbl_deep_extend("force", sagani.options, type(opts) == "table" and opts or {})
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
			local sagani_mod = package.loaded["sagani"] or require("sagani")
			local dispatch_fn = (sagani_mod and sagani_mod.dispatch_prompt) or M.dispatch_prompt
			local ok, dispatch_err = dispatch_fn(text, agent_target, popup_opts)
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

	local sagani_mod = package.loaded["sagani"] or require("sagani")
	local task_val = opts.tasks and opts.tasks.ask
	local has_config = ask_opts.target_agent
		or sagani_mod._session_harness
		or (task_val and (type(task_val) == "string" or (type(task_val) == "table" and (task_val.agent or task_val.harness))))

	if not has_config and not _G.RUNNING_TEST_SUITE and vim.ui and vim.ui.select then
		notify.info("No active agent harness configured for 'ask'. Please select your target agent harness:", opts)
		if sagani_mod.select_agent_harness then
			sagani_mod.select_agent_harness(nil, opts, function(selected_harness)
				do_ask(selected_harness, prompt_text)
			end)
		end
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
	local sagani = package.loaded["sagani"] or require("sagani")
	opts = type(opts) == "table" and opts or sagani.options
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

	local active_harness = (opts.agent_opts and opts.agent_opts.harness) or sagani._session_harness or "agy"
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
