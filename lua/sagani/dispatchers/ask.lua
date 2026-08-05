--- ==============================================================================
--- Module: sagani.dispatchers.ask
---
--- Description:
---   High-level workflow coordinator for asking agents general questions.
---   Integrates buffer context decoration, ACP popup execution, and multiplexer
---   pane spawning.
---
--- Responsibilities:
---   - Interactive prompt collection via vim.ui.input.
---   - Delegate context injection to sagani.dispatchers.context.
---   - Delegate ACP floating popup execution to sagani.dispatchers.acp.
---   - Delegate terminal pane spawning and delivery to sagani.dispatchers.delivery.
--- ==============================================================================

local notify = require("sagani.notify")
local backend = require("sagani.backend")
local context = require("sagani.dispatchers.context")
local acp_dispatcher = require("sagani.dispatchers.acp")

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

		text = context.inject_file_reference(text, 0)

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
			acp_dispatcher.execute_acp_popup(harness, text, agent_opts, popup_opts)
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
