--- ==============================================================================
--- Module: plugins.sagani
---
--- Description:
---   LazyVim / lazy.nvim plugin specification for sagani.nvim. Configures plugin
---   loading, lazy setup initialization, keymap registration, and optional
---   WhichKey menu group bindings (<leader>a).
---
--- Responsibilities:
---   - Expose lazy.nvim plugin specification table.
---   - Configure WhichKey menu group integration for "<leader>a" (Sagani).
---   - Invoke sagani.setup(opts) on plugin load.
--- ==============================================================================

local plugin_dir = vim.fn.expand("~/CreatorSpace/Coder/OpenSource/NeovimPlugins/sagani.nvim")
if vim.fn.isdirectory(plugin_dir) == 0 then
	plugin_dir = "."
end

return {
	-- Optional WhichKey integration for Sagani keymap group
	{
		"folke/which-key.nvim",
		optional = true,
		opts = {
			spec = {
				{ "<leader>a", group = "Sagani", mode = { "n", "v" } },
			},
		},
	},

	-- sagani.nvim main plugin specification
	{
		"sagani.nvim",
		dir = plugin_dir,
		name = "sagani.nvim",
		cmd = {
			"SaganiStatus",
			"SaganiSelectTarget",
			"SaganiSelectAgent",
			"SaganiAskAgent",
			"SaganiSelectHarness",
			"SaganiSpawnPane",
			"SaganiPrompt",
			"SaganiSend",
			"SaganiContext",
			"SaganiDiff",
			"SaganiReview",
			"SaganiReviewToggle",
			"SaganiAccept",
			"SaganiAcceptHunk",
			"SaganiAcceptAll",
			"SaganiReject",
			"SaganiRejectHunk",
			"SaganiRejectAll",
			"SaganiNextHunk",
			"SaganiPrevHunk",
			"SaganiReload",
		},
		keys = {
			{ "<leader>as", "<cmd>SaganiStatus<cr>", desc = "Sagani Status" },
			{ "<leader>as", "<cmd>SaganiSend<cr>", desc = "Send Selection to Sagani", mode = "v" },
			{ "<leader>ac", "<cmd>SaganiSelectTarget<cr>", desc = "Select Sagani Target Pane" },
			{ "<leader>ac", "<cmd>SaganiContext<cr>", desc = "Send Context to Sagani", mode = "v" },
			{ "<leader>ad", "<cmd>SaganiDiff<cr>", desc = "Send Diff Comment to Sagani", mode = { "n", "v" } },
			{ "<leader>ap", "<cmd>SaganiPrompt<cr>", desc = "Send Prompt to Sagani", mode = { "n", "v" } },
			{ "<leader>at", "<cmd>SaganiSend<cr>", desc = "Send Selection to Sagani", mode = "v" },
			{ "<leader>an", "<cmd>SaganiSpawnPane<cr>", desc = "Spawn New Sagani Pane", mode = "n" },
			{ "<leader>ah", "<cmd>SaganiSelectAgent<cr>", desc = "Select Agent Harness", mode = "n" },
			{ "<leader>aa", "<cmd>SaganiAskAgent<cr>", desc = "Ask Agent (Herdr Popup)", mode = { "n", "v" } },
			{ "<leader>ar", "<cmd>SaganiReview<cr>", desc = "Review Agent Edits Diff", mode = "n" },
			{ "<leader>ay", "<cmd>SaganiAccept<cr>", desc = "Accept Edit Hunk/File", mode = "n" },
			{ "<leader>ax", "<cmd>SaganiReject<cr>", desc = "Reject Edit Hunk/File", mode = "n" },
			{ "<leader>a]", "<cmd>SaganiNextHunk<cr>", desc = "Next Agent Edit Hunk", mode = "n" },
			{ "<leader>a[", "<cmd>SaganiPrevHunk<cr>", desc = "Previous Agent Edit Hunk", mode = "n" },
		},
		opts = {
			agents = {
				agy = { harness = "agy", cmd = { "agy" }, name = "Antigravity CLI" },
				codex = { harness = "codex", cmd = { "codex" }, name = "Codex CLI" },
				opencode = { harness = "opencode", cmd = { "opencode" }, name = "Opencode Agent", port = 4096 },
				hermes = { harness = "hermes", cmd = { "hermes" }, name = "Hermes Agent" },
				gemini = { harness = "gemini", cmd = { "gemini" }, name = "Gemini CLI" },
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
			startup_delay = 5000,
			auto_spawn = false,
		},
		config = function(_, opts)
			require("sagani").setup(opts)
		end,
	},
}
