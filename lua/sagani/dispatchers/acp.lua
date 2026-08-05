--- ==============================================================================
--- Module: sagani.dispatchers.acp
---
--- Description:
---   Handles ACP (Agent Communication Protocol) interactive popup executions.
---   Opens native Markdown floating popups, renders prompt headers, streams
---   asynchronous status updates, and handles ACP prompt responses.
---
--- Responsibilities:
---   - Launch native floating Markdown windows via sagani.ui.markdown_popup.
---   - Stream real-time progress callbacks to popup buffer UI.
---   - Execute agent prompts via protocol.acp driver.
---   - Display completed markdown responses or error alerts.
--- ==============================================================================

local notify = require("sagani.notify")

local M = {}

--- Executes an ACP prompt inside an interactive Markdown floating popup window
--- @param harness string Agent harness identifier
--- @param text string Formatted user prompt text
--- @param agent_opts table Agent execution configuration options
--- @param popup_opts table Popup window styling and task options
function M.execute_acp_popup(harness, text, agent_opts, popup_opts)
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
			notify.info(string.format("Received response from '%s' via ACP", harness), popup_opts)
		else
			markdown_popup.set_response(buf, "❌ Error: " .. (acp_err or "Unknown ACP error"))
			notify.error(
				string.format("ACP request to '%s' failed: %s", harness, acp_err or "Unknown error"),
				popup_opts
			)
		end
	end, popup_opts, progress_cb)
end

return M
