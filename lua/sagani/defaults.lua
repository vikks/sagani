local M = {}

M.defaults = {
	window_opts = {
		width = 0.8,
		height = 0.8,
		border = "rounded",
		winblend = 0,
		ratio = 0.3,
	},

	backends = {
		native = {
			ask = "popup",
			review = "vsplit",
			code = "vsplit",
			chat = "vsplit",
			border = "rounded",
			winblend = 0,
			split_direction = "vertical",
		},
		herdr = {
			ask = false,
			review = "right-pane",
			code = "right-pane",
			chat = "right-pane",
			ratio = 0.3,
			auto_discover = true,
			auto_spawn = false,
		},
		tmux = {
			ask = "popup",
			review = "right-pane",
			code = "right-pane",
			chat = "right-pane",
			width = "80%",
			height = "80%",
			border = "rounded",
			split_direction = "right",
			target_pane = nil,
		},
		zellij = {
			ask = "floating",
			review = "right-pane",
			code = "right-pane",
			chat = "right-pane",
			direction = "right",
		},
	},

	providers = {
		google = { api_key_env = "GEMINI_API_KEY", alias = "Google Gemini" },
		openai = { api_key_env = "OPENAI_API_KEY", alias = "OpenAI" },
		anthropic = { api_key_env = "ANTHROPIC_API_KEY", alias = "Anthropic" },
	},

	agents = {
		agy = {
			cmd = { "agy" },
			name = "Antigravity CLI",
		},
		codex = {
			cmd = { "codex" },
			name = "Codex CLI",
		},
		opencode = {
			cmd = { "opencode" },
			name = "Opencode Agent",
			port = 4096,
		},
		hermes = {
			cmd = { "hermes" },
			name = "Hermes Agent",
		},
		gemini = {
			cmd = { "gemini" },
			name = "Gemini CLI",
		},
	},

	tasks = {
		chat = "agy",
		ask = {
			agent = "agy",
			backend = "native",
			instructions = "Answer the user's question concisely and accurately.",
		},
		review = {
			agent = "codex",
			instructions = "Review the provided code changes and offer actionable feedback.",
		},
		code = {
			agent = "opencode",
			instructions = "Fulfill the user's coding request directly in the buffer.",
		},
	},

	auto_discover = true,
	auto_spawn = false,
	pane_override = nil,
	default_keymaps = true,
	which_key = true,
	notify = {
		enabled = true,
		title = "sagani.nvim",
	},

	modes = {
		review = {
			enabled = true,
			auto_open = false,
			mode = "inline",
		},
		learn = {
			enabled = false,
			auto_open = false,
			mode = "split",
			prompt_prefix = "Learning Mode Active: Provide a clear educational breakdown of the core concepts, syntax, architectural decisions, and trade-offs.",
		},
	},
}

--- Ensures backward compatibility for legacy opts.ask_agent and opts.review property access
function M.ensure_compat_getters(opts)
	if type(opts) ~= "table" then
		return opts
	end

	local raw_review = rawget(opts, "review")
	if type(raw_review) == "table" then
		if raw_review.enabled == nil then
			raw_review.enabled = true
		end
		if raw_review.auto_open == nil then
			raw_review.auto_open = false
		end
		if raw_review.mode == nil then
			raw_review.mode = "inline"
		end
	end

	setmetatable(opts, {
		__index = function(t, k)
			if k == "ask_agent" then
				local ask_task = type(t.tasks) == "table" and t.tasks.ask or {}
				local agent_name = (type(ask_task) == "string" and ask_task)
					or (type(ask_task) == "table" and ask_task.agent)
				return {
					target_agent = agent_name,
					popup = true,
				}
			elseif k == "review" then
				local review_task = type(t.tasks) == "table" and t.tasks.review or {}
				return {
					enabled = true,
					auto_open = false,
					mode = "inline",
					agent = (type(review_task) == "string" and review_task)
						or (type(review_task) == "table" and review_task.agent)
						or "codex",
				}
			end
			return nil
		end,
	})

	return opts
end

return M
