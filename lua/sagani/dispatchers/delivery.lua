--- ==============================================================================
--- Module: sagani.dispatchers.delivery
---
--- Description:
---   Handles core prompt transport delivery to agent panes/popups across backends
---   (Herdr, Tmux, Zellij, Native). Takes baseline diff snapshots, discovers
---   target panes, waits for agent initialization readiness, delivers text, and
---   triggers automated diff review views when enabled.
---
--- Responsibilities:
---   - Baseline snapshot capture prior to agent execution via sagani.diff.
---   - Backend resolution and target pane auto-discovery.
---   - Agent readiness waiting via adapter.wait_for_ready.
---   - Prompt text delivery via adapter.prompt_target.
---   - Automated side-by-side / inline diff review triggering post-execution.
--- ==============================================================================

local notify = require("sagani.notify")
local diff = require("sagani.diff")
local backend = require("sagani.backend")

local M = {}

--- Delivers prompt text to target agent pane via active multiplexer backend adapter
--- @param prompt_text string Prompt text payload
--- @param target_pane string|nil Explicit target pane handle or nil for auto-discovery
--- @param opts table|nil Options table
--- @return boolean ok, string|nil err
function M.deliver_prompt(prompt_text, target_pane, opts)
	local sagani_mod = package.loaded["sagani"] or require("sagani")
	opts = type(opts) == "table" and opts or sagani_mod.options
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

	local active_harness = (opts.agent_opts and opts.agent_opts.harness) or sagani_mod._session_harness or "agy"
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
