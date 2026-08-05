--- ==============================================================================
--- Module: sagani.state.model
---
--- Description:
---   Target model session state manager for sagani.nvim. Manages active model name
---   override (`_session_model`) for prompt dispatching.
---
--- Responsibilities:
---   - Store active session model override.
---   - Provide set_model setter helper.
--- ==============================================================================

local M = {}

M._session_model = nil

function M.set_model(model_name)
	if type(model_name) == "string" and model_name ~= "" then
		M._session_model = model_name
	else
		M._session_model = nil
	end
	return M._session_model
end

return M
