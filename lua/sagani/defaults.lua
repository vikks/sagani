--- ==============================================================================
--- Module: sagani.defaults
---
--- Description:
---   Master default configuration repository and backward compatibility getter manager
---   for sagani.nvim. Defines default options for backends, task bindings, agent CLI
---   commands, UI layouts, and operating modes.
---
--- Responsibilities:
---   - Expose default M.defaults options table.
---   - Provide ensure_compat_getters metatable helper for legacy option access.
--- ==============================================================================

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

return M
