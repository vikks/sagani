local ask = require("sagani.dispatchers.ask")
local prompt = require("sagani.dispatchers.prompt")

local M = {
	ask = ask,
	prompt = prompt,
}

function M.ask_agent_prompt(prompt_text, opts)
	return ask.ask_agent_prompt(prompt_text, opts)
end

function M.dispatch_prompt(prompt_text, target_pane, opts)
	return prompt.dispatch_prompt(prompt_text, target_pane, opts)
end

return M
