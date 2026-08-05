--- ==============================================================================
--- Module: sagani.dispatchers.prompt
---
--- Description:
---   High-level prompt dispatch router. Delegates transport delivery and post-dispatch
---   auto-review triggering to sagani.dispatchers.delivery.
---
--- Responsibilities:
---   - Main entry point for M.dispatch_prompt.
---   - Delegate transport discovery, readiness waiting, and prompt delivery to delivery.lua.
--- ==============================================================================

local delivery = require("sagani.dispatchers.delivery")

local M = {}

--- Main prompt dispatch router entry point
--- @param prompt_text string Prompt text
--- @param target_pane string|nil Target pane handle
--- @param opts table|nil Options table
--- @return boolean ok, string|nil err
function M.dispatch_prompt(prompt_text, target_pane, opts)
	return delivery.deliver_prompt(prompt_text, target_pane, opts)
end

return M
