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
	local display_name = (agent_opts and agent_opts.alias) or harness:upper()
	local main_win, main_buf = markdown_popup.open_attached_layout(
		string.format("Sagani Agent (%s)", display_name),
		harness,
		popup_opts
	)
	markdown_popup.set_session(main_buf, harness, nil, agent_opts, popup_opts)

	if text and text ~= "" then
		text = require("sagani.dispatchers.context").inject_file_reference(text, 0)
		markdown_popup.send_followup(main_buf, text)
	end
end

return M
