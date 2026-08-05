--- ==============================================================================
--- Module: sagani.dispatchers.init
---
--- Description:
---   Master facade module for the sagani.dispatchers package. Aggregates all
---   dispatcher submodules (context, acp, delivery, ask, prompt) and exposes
---   the core ask_agent_prompt and dispatch_prompt APIs.
---
--- Submodules:
---   - context:  Buffer context & path reference (@[abs_path]) decorator.
---   - acp:      ACP protocol floating popup session runner.
---   - delivery: Transport delivery, readiness waiting, & auto-review trigger runner.
---   - ask:      General question workflow coordinator.
---   - prompt:   Main prompt dispatch router.
--- ==============================================================================

local context = require("sagani.dispatchers.context")
local acp = require("sagani.dispatchers.acp")
local delivery = require("sagani.dispatchers.delivery")
local ask = require("sagani.dispatchers.ask")
local prompt = require("sagani.dispatchers.prompt")

local M = {
	context = context,
	acp = acp,
	delivery = delivery,
	ask = ask,
	prompt = prompt,
}

--- Asks a general question/prompt to an agent in a Herdr popup or floating window
--- @param prompt_text string|nil User prompt or nil to prompt interactively
--- @param opts table|nil Options table
function M.ask_agent_prompt(prompt_text, opts)
	return ask.ask_agent_prompt(prompt_text, opts)
end

--- Main prompt dispatch router entry point
--- @param prompt_text string Prompt text
--- @param target_pane string|nil Target pane handle
--- @param opts table|nil Options table
--- @return boolean ok, string|nil err
function M.dispatch_prompt(prompt_text, target_pane, opts)
	return prompt.dispatch_prompt(prompt_text, target_pane, opts)
end

return M
