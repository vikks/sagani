local notify = require("sagani.notify")
local backend = require("sagani.backend")

local M = {}

--- Asks a general question/prompt to an agent in a Herdr popup or floating window
--- @param prompt_text string|nil User prompt or nil to prompt interactively
--- @param opts table|nil Options table
function M.ask_agent_prompt(prompt_text, opts)
	local sagani_mod = package.loaded["sagani"] or require("sagani")
	opts = vim.tbl_deep_extend("force", sagani_mod.options, type(opts) == "table" and opts or {})
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
			local active_sagani = package.loaded["sagani"] or require("sagani")
			local prompt_dispatcher = require("sagani.dispatchers.prompt")
			local dispatch_fn = (active_sagani and active_sagani.dispatch_prompt) or prompt_dispatcher.dispatch_prompt
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

return M
