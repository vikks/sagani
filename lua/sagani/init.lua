local notify = require("sagani.notify")
local format = require("sagani.format")
local selection = require("sagani.selection")
local diff = require("sagani.diff")
local backend = require("sagani.backend")

-- Register Built-in Backend Providers
backend.register("native", require("sagani.backend.native"))
backend.register("herdr", require("sagani.backend.herdr"))
backend.register("tmux", require("sagani.backend.tmux"))
backend.register("zellij", require("sagani.backend.zellij"))

local native_vim_system = vim.system

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
	ports = {
		opencode = 4096,
		gemini = 4097,
	},
	tasks = {
		ask = "agy",
		review = "codex",
		code = "opencode",
		chat = "agy",
	},
	auto_discover = true,
	auto_spawn = false,
	pane_override = nil,
	default_keymaps = true,
	which_key = true,
	ask_agent = {
		popup = true,
	},
	review = {
		enabled = true,
		auto_open = false,
		mode = "inline",
	},
	notify = {
		enabled = true,
		title = "sagani.nvim",
	},
}

M.options = vim.tbl_deep_extend("force", {}, M.defaults)
M._session_ask_agent = nil
M.format = format
M.selection = selection
M.diff = diff

function M.setup(user_opts)
	user_opts = type(user_opts) == "table" and user_opts or {}
	M.options = vim.tbl_deep_extend("force", M.defaults, user_opts)
	M._session_harness = nil
	M._session_model = nil
	M._session_effort = nil

	-- Register Default Keymaps
	if M.options.default_keymaps then
		local set = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
		end
		set("n", "<leader>as", "<cmd>SaganiStatus<cr>", "Sagani Status")
		set("v", "<leader>as", "<cmd>SaganiSend<cr>", "Send Selection to Sagani")
		set("n", "<leader>ac", "<cmd>SaganiSelectTarget<cr>", "Select Sagani Target Pane")
		set("v", "<leader>ac", "<cmd>SaganiContext<cr>", "Send Context to Sagani")
		set({ "n", "v" }, "<leader>ad", "<cmd>SaganiDiff<cr>", "Send Diff Comment to Sagani")
		set({ "n", "v" }, "<leader>ap", "<cmd>SaganiPrompt<cr>", "Send Prompt to Sagani")
		set("v", "<leader>at", "<cmd>SaganiSend<cr>", "Send Selection to Sagani")
		set("n", "<leader>an", "<cmd>SaganiSpawnPane<cr>", "Spawn New Sagani Pane")
		set("n", "<leader>ah", "<cmd>SaganiSelectAgent<cr>", "Select Agent Harness")
		set({ "n", "v" }, "<leader>aa", "<cmd>SaganiAskAgent<cr>", "Ask Agent (Herdr Popup)")
		set("n", "<leader>ar", "<cmd>SaganiReview<cr>", "Review Agent Edits Diff")
		set("n", "<leader>ay", "<cmd>SaganiAccept<cr>", "Accept Edit Hunk/File")
		set("n", "<leader>ax", "<cmd>SaganiReject<cr>", "Reject Edit Hunk/File")
		set("n", "<leader>a]", "<cmd>SaganiNextHunk<cr>", "Next Agent Edit Hunk")
		set("n", "<leader>a[", "<cmd>SaganiPrevHunk<cr>", "Previous Agent Edit Hunk")
	end

	-- Register WhichKey Menu Group
	if M.options.which_key then
		local ok, wk = pcall(require, "which-key")
		if ok then
			if type(wk.add) == "function" then
				pcall(wk.add, {
					{ "<leader>a", group = "Sagani", mode = { "n", "v" } },
				})
			elseif type(wk.register) == "function" then
				pcall(wk.register, {
					["<leader>a"] = { name = "+Sagani" },
				}, { mode = { "n", "v" } })
			end
		end
	end

	-- Register User Commands
	vim.api.nvim_create_user_command("SaganiStatus", function()
		local adapter, backend_name = backend.get_backend(M.options)
		local env_info = adapter.detect_env and adapter.detect_env(M.options.runner) or {}
		local env = env_info.metadata or env_info
		local status_opts = vim.tbl_deep_extend("force", M.options, { auto_spawn = false })
		local pane_id, err, _ = adapter.discover_target(status_opts)
		local task_agent = backend.resolve_task_agent(M.options, "chat")
		local harness = (task_agent and task_agent.harness) or "agy"
		local msg = string.format(
			"Backend: %s | Pane: %s | Tab: %s | Workspace: %s\nTarget Pane (%s): %s",
			backend_name:upper(),
			env.pane_id or "N/A",
			env.tab_id or "N/A",
			env.workspace_id or "N/A",
			harness,
			pane_id or ("NONE (" .. (err or "Unknown") .. ")")
		)
		if pane_id then
			notify.info(msg, M.options)
		else
			notify.warn(msg, M.options)
		end
	end, { desc = "Show backend status and target AGY pane status" })

	vim.api.nvim_create_user_command("SaganiSelectTarget", function()
		vim.ui.input({ prompt = "Enter target Herdr pane ID (or empty to clear override): " }, function(input)
			if input and input ~= "" then
				M.options.pane_override = input
				notify.info("Target pane override set to: " .. input, M.options)
			else
				M.options.pane_override = nil
				notify.info("Target pane override cleared. Reverted to auto-discovery.", M.options)
			end
		end)
	end, { desc = "Set manual target pane ID override" })

	vim.api.nvim_create_user_command("SaganiSelectAgent", function(cmd_args)
		M.select_agent_harness(cmd_args.args, M.options)
	end, { nargs = "?", desc = "Select target agent harness (agy, codex, opencode, hermes, etc.)" })

	vim.api.nvim_create_user_command("SaganiAskAgent", function(cmd_args)
		M.ask_agent_prompt(cmd_args.args)
	end, { nargs = "*", range = true, desc = "Ask general question to agent in Herdr popup" })

	vim.api.nvim_create_user_command("SaganiSelectHarness", function(cmd_args)
		M.select_agent_harness(cmd_args.args, M.options)
	end, { nargs = "?", desc = "Alias for SaganiSelectAgent" })

	vim.api.nvim_create_user_command("SaganiSpawnPane", function()
		local adapter, backend_name, placement, ui_opts, agent_opts = backend.get_backend(M.options, "chat")
		local harness = (agent_opts and agent_opts.harness) or "agy"
		local opts = vim.tbl_deep_extend(
			"force",
			M.options,
			{ placement = placement, ui_opts = ui_opts, agent_opts = agent_opts }
		)
		local pane_id, err, _ = adapter.spawn_pane(opts)
		if pane_id then
			notify.info(
				string.format("Spawned new pane '%s' for '%s' via %s backend", pane_id, harness, backend_name),
				M.options
			)
		else
			notify.error(
				string.format("Failed to spawn pane via %s: %s", backend_name, err or "Unknown error"),
				M.options
			)
		end
	end, { desc = "Spawn new agent terminal pane" })

	vim.api.nvim_create_user_command("SaganiPrompt", function(cmd_args)
		local prompt_text = cmd_args.args
		local function dispatch(text)
			if text and text ~= "" then
				local full_name = vim.api.nvim_buf_get_name(0)
				if full_name and full_name ~= "" and not text:find("@%[") then
					local abs_path = vim.fn.fnamemodify(full_name, ":p")
					if abs_path and abs_path ~= "" then
						text = string.format("%s @[%s]", text, abs_path)
					end
				end
				M.dispatch_prompt(text)
			end
		end

		if prompt_text == "" then
			local task_agent = backend.resolve_task_agent(M.options, "chat")
			local agent_name = ((task_agent and task_agent.harness) or "agy"):upper()
			vim.ui.input({ prompt = string.format("Prompt for %s: ", agent_name) }, function(input)
				dispatch(input)
			end)
		else
			dispatch(prompt_text)
		end
	end, { nargs = "*", desc = "Send custom prompt to target agent pane" })

	vim.api.nvim_create_user_command("SaganiSend", function()
		selection.send_selection_prompt(M.options)
	end, { range = true, desc = "Send visual selection with instruction prompt to target agent" })

	vim.api.nvim_create_user_command("SaganiContext", function()
		selection.send_code_context(M.options)
	end, { range = true, desc = "Send visual selection code context to target agent" })

	vim.api.nvim_create_user_command("SaganiDiff", function()
		diff.send_diff_comment(M.options)
	end, { range = true, desc = "Send diff review comment to target agent" })

	vim.api.nvim_create_user_command("SaganiReview", function(cmd_args)
		diff.toggle_review(nil, M.options, cmd_args.args)
	end, { nargs = "?", desc = "Toggle agent edit review diff view (inline or split)" })

	vim.api.nvim_create_user_command("SaganiReviewToggle", function()
		diff.toggle_review(nil, M.options)
	end, { desc = "Alias for SaganiReview" })

	vim.api.nvim_create_user_command("SaganiAccept", function(cmd_args)
		diff.accept_change(cmd_args.args, nil, M.options)
	end, { nargs = "?", desc = "Accept agent edit change (hunk under cursor or all)" })

	vim.api.nvim_create_user_command("SaganiAcceptHunk", function()
		diff.accept_change("hunk", nil, M.options)
	end, { desc = "Accept agent edit hunk under cursor position" })

	vim.api.nvim_create_user_command("SaganiAcceptAll", function()
		diff.accept_change("all", nil, M.options)
	end, { desc = "Accept all agent edit changes in buffer" })

	vim.api.nvim_create_user_command("SaganiReject", function(cmd_args)
		diff.reject_change(cmd_args.args, nil, M.options)
	end, { nargs = "?", desc = "Reject agent edit change (revert hunk under cursor or all)" })

	vim.api.nvim_create_user_command("SaganiRejectHunk", function()
		diff.reject_change("hunk", nil, M.options)
	end, { desc = "Reject agent edit hunk under cursor position" })

	vim.api.nvim_create_user_command("SaganiRejectAll", function()
		diff.reject_change("all", nil, M.options)
	end, { desc = "Reject all agent edit changes in buffer" })

	vim.api.nvim_create_user_command("SaganiNextHunk", function()
		diff.next_hunk(nil, M.options)
	end, { desc = "Jump cursor to next agent edit hunk" })

	vim.api.nvim_create_user_command("SaganiPrevHunk", function()
		diff.prev_hunk(nil, M.options)
	end, { desc = "Jump cursor to previous agent edit hunk" })

	vim.api.nvim_create_user_command("SaganiReload", function()
		local saved_opts = vim.tbl_deep_extend("force", {}, M.options)
		for k in pairs(package.loaded) do
			if k:match("^sagani") then
				package.loaded[k] = nil
			end
		end
		require("sagani").setup(saved_opts)
		notify.info("Flushed all sagani.* modules and reloaded configuration", M.options)
	end, { desc = "Hot-reload all sagani modules" })

	vim.api.nvim_create_user_command("SaganiClearCache", function()
		require("sagani.cache").clear_cache()
		notify.info("Cleared Sagani persistent model cache", M.options)
	end, { desc = "Clear persistent model cache" })

	-- Register File Change Watcher for Agent Edits
	local group = vim.api.nvim_create_augroup("SaganiReviewWatcher", { clear = true })
	vim.api.nvim_create_autocmd({ "FileChangedShellPost", "BufReadPost" }, {
		group = group,
		callback = function(ev)
			local opts = M.options
			local review_opts = type(opts.review) == "table" and opts.review or {}
			local enabled = (type(opts.review) == "boolean" and opts.review) or (review_opts.enabled ~= false)
			local auto_open = (type(review_opts) == "table") and review_opts.auto_open or false

			if enabled and auto_open then
				local bufnr = ev.buf
				if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
					vim.schedule(function()
						local hunks = diff.get_hunks(bufnr)
						if #hunks > 0 then
							diff.open_review(bufnr, opts)
						end
					end)
				end
			end
		end,
	})

	-- Register Auto-Cleanup Watcher for Background ACP Servers on Vim Exit
	local cleanup_group = vim.api.nvim_create_augroup("SaganiCleanupWatcher", { clear = true })
	vim.api.nvim_create_autocmd({ "VimLeavePre", "VimLeave", "ExitPre" }, {
		group = cleanup_group,
		callback = function()
			pcall(function()
				require("sagani.protocol.http.opencode").stop_server()
			end)
		end,
	})
end

local function supports_effort(harness_name, selected_model)
	harness_name = (harness_name or ""):lower()
	selected_model = (selected_model or ""):lower()

	if
		selected_model:find("thinking")
		or selected_model:find("reasoning")
		or selected_model:find("o1")
		or selected_model:find("o3")
		or selected_model:find("luna")
		or selected_model:find("claude%-3%-7")
		or selected_model:find("deepseek")
	then
		return true
	end

	if harness_name == "agy" or harness_name == "antigravity" then
		if
			selected_model == ""
			or selected_model == "[use default model]"
			or selected_model:find("gemini 3")
			or selected_model:find("flash")
			or selected_model:find("pro")
		then
			return true
		end
	end

	if harness_name == "codex" then
		if selected_model:find("o1") or selected_model:find("o3") or selected_model:find("luna") then
			return true
		end
	end

	if harness_name == "opencode" then
		if
			selected_model:find("deepseek")
			or selected_model:find("gemini%-3")
			or selected_model:find("pickle")
			or selected_model:find("free")
		then
			return true
		end
	end

	return false
end

function M.prompt_model_and_effort(harness, opts, on_complete)
	opts = type(opts) == "table" and opts or M.options
	harness = (harness or "agy"):lower()
	M._session_harness = harness

	local cli_transport = require("sagani.protocol.cli")
	local efforts = { "low", "medium", "high" }

	cli_transport.list_models_async(harness, opts, function(models)
		models = models or {}

		local function finish()
			local m_str = M._session_model or "Default"
			local e_str = M._session_effort or "Default"
			notify.info(
				string.format("Active Agent: '%s' | Model: %s | Effort: %s", harness:upper(), m_str, e_str),
				opts
			)
			if on_complete then
				on_complete(harness)
			end
		end

		local function pick_effort()
			local model_name = M._session_model or ""
			if not supports_effort(harness, model_name) then
				M._session_effort = nil
				finish()
				return
			end

			if not _G.RUNNING_TEST_SUITE and #efforts > 0 and vim.ui and vim.ui.select then
				local e_choices = { "[Use Default Effort]" }
				for _, e in ipairs(efforts) do
					table.insert(e_choices, e)
				end
				vim.ui.select(e_choices, {
					prompt = string.format("Select Reasoning Effort for %s:", harness:upper()),
				}, function(e_choice)
					if e_choice and e_choice ~= "[Use Default Effort]" then
						M._session_effort = e_choice
					else
						M._session_effort = nil
					end
					finish()
				end)
			else
				finish()
			end
		end

		local function pick_model()
			if not _G.RUNNING_TEST_SUITE and #models > 0 and vim.ui and vim.ui.select then
				local m_choices = { "[Use Default Model]" }
				for _, m in ipairs(models) do
					table.insert(m_choices, m)
				end
				vim.ui.select(m_choices, {
					prompt = string.format("Select Model for %s:", harness:upper()),
				}, function(m_choice)
					if m_choice and m_choice ~= "[Use Default Model]" then
						M._session_model = m_choice
					else
						M._session_model = nil
					end
					pick_effort()
				end)
			else
				pick_effort()
			end
		end

		pick_model()
	end)
end

function M.select_agent_harness(arg, opts, on_complete)
	opts = type(opts) == "table" and opts or M.options
	if type(arg) == "string" and arg ~= "" then
		local harness = vim.trim(arg):lower()
		M.prompt_model_and_effort(harness, opts, on_complete)
		return harness
	end

	local choices = { "agy", "codex", "opencode", "hermes", "gemini" }
	local seen = {}
	for _, c in ipairs(choices) do
		seen[c] = true
	end

	local adapter, _ = backend.get_backend(opts)
	local agents = adapter.list_agents and adapter.list_agents(opts.runner) or nil
	if type(agents) == "table" then
		for _, a in ipairs(agents) do
			if type(a) == "table" and type(a.agent) == "string" and a.agent ~= "" then
				local agent_kind = a.agent:lower()
				if not seen[agent_kind] then
					table.insert(choices, agent_kind)
					seen[agent_kind] = true
				end
			end
		end
	end

	table.insert(choices, "Other...")

	local active_h = M._session_harness or "none"
	if not _G.RUNNING_TEST_SUITE and vim.ui and vim.ui.select then
		vim.ui.select(choices, {
			prompt = string.format("Select Agent Harness (Active Session: %s):", active_h),
			format_item = function(item)
				if item == M._session_harness then
					return item .. " (active)"
				end
				return item
			end,
		}, function(choice)
			if not choice then
				return
			end
			if choice == "Other..." then
				vim.ui.input({ prompt = "Enter custom agent harness name: " }, function(input)
					if input and input ~= "" then
						local custom_agent = vim.trim(input):lower()
						M.prompt_model_and_effort(custom_agent, opts, on_complete)
					end
				end)
			else
				M.prompt_model_and_effort(choice, opts, on_complete)
			end
		end)
	end

	return M._session_harness
end

--- Asks a general question/prompt to an agent in a Herdr popup.
--- Resolves target agent via opts.ask_agent.target_agent -> session cache -> runtime input prompt.
--- @param prompt_text string|nil User prompt or nil to prompt interactively.
--- @param opts table|nil Options table.
function M.ask_agent_prompt(prompt_text, opts)
	opts = vim.tbl_deep_extend("force", M.options, type(opts) == "table" and opts or {})
	local ask_opts = type(opts.ask_agent) == "table" and opts.ask_agent or {}

	local function do_ask(agent_name, text)
		if not agent_name or agent_name == "" then
			notify.warn("No target agent selected for general questions", opts)
			return
		end

		if not text or text == "" then
			vim.ui.input({ prompt = string.format("Ask Agent (%s): ", agent_name:upper()) }, function(input)
				if input and input ~= "" then
					do_ask(agent_name, input)
				end
			end)
			return
		end

		-- Include file mention @[abs_path] if available and not already in prompt
		local full_name = vim.api.nvim_buf_get_name(0)
		if full_name and full_name ~= "" and not text:find("@%[") then
			local abs_path = vim.fn.fnamemodify(full_name, ":p")
			if abs_path and abs_path ~= "" then
				text = string.format("%s @[%s]", text, abs_path)
			end
		end

		local adapter, backend_name, placement, ui_opts, agent_opts = backend.get_backend(opts, "ask")
		local harness = (type(agent_name) == "string" and agent_name ~= "") and agent_name
			or (agent_opts and agent_opts.harness)
			or "agy"
		agent_opts.harness = harness
		local popup_opts = vim.tbl_deep_extend("force", opts, {
			adapter = adapter,
			backend_name = backend_name,
			task_type = "ask",
			placement = placement,
			ui_opts = ui_opts,
			agent_opts = agent_opts,
		})

		if agent_opts and agent_opts.protocol == "acp" then
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
					notify.info(string.format("Received response from '%s' via ACP", harness), opts)
				else
					markdown_popup.set_response(buf, "❌ Error: " .. (acp_err or "Unknown ACP error"))
					notify.error(
						string.format("ACP request to '%s' failed: %s", harness, acp_err or "Unknown error"),
						opts
					)
				end
			end, opts, progress_cb)
			return
		end

		local agent_target, err, meta
		if placement == "popup" or placement == "floating" then
			agent_target, err, meta = adapter.spawn_popup(popup_opts)
		else
			agent_target, err, meta = adapter.spawn_pane(popup_opts)
		end

		if agent_target then
			local display_pane = (meta and meta.pane_id) or agent_target
			local ok, dispatch_err = M.dispatch_prompt(text, agent_target, popup_opts)
			if ok then
				notify.info(
					string.format("Asked '%s' agent in %s pane '%s'", agent_name, backend_name, display_pane),
					opts
				)
			else
				notify.error(
					string.format(
						"Failed to prompt '%s' in %s pane '%s': %s",
						agent_name,
						backend_name,
						display_pane,
						dispatch_err or "Unknown error"
					),
					opts
				)
			end
		else
			notify.error(string.format("Failed to spawn %s agent pane: %s", backend_name, err or "Unknown error"), opts)
		end
	end

	local task_val = opts.tasks and opts.tasks.ask
	local has_config = ask_opts.target_agent
		or M._session_harness
		or (task_val and (type(task_val) == "string" or (type(task_val) == "table" and task_val.harness)))

	if not has_config and not _G.RUNNING_TEST_SUITE and vim.ui and vim.ui.select then
		notify.info("No active agent harness configured for 'ask'. Please select your target agent harness:", opts)
		M.select_agent_harness(nil, opts, function(selected_harness)
			do_ask(selected_harness, prompt_text)
		end)
		return
	end

	local task_agent = backend.resolve_task_agent(opts, "ask")
	local configured_agent = ask_opts.target_agent or (task_agent and task_agent.harness)
	local agent_name = (type(configured_agent) == "string" and configured_agent ~= "") and configured_agent or "agy"
	do_ask(agent_name, prompt_text)
end

function M.dispatch_prompt(prompt_text, target_pane, opts)
	opts = type(opts) == "table" and opts or M.options
	if type(prompt_text) ~= "string" or prompt_text == "" then
		local err_msg = "Invalid prompt text: must be a non-empty string"
		notify.error(err_msg, opts)
		return false, err_msg
	end

	-- Pre-capture baseline snapshot of current buffer before agent touches files
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

	local active_harness = (opts.agent_opts and opts.agent_opts.harness) or M._session_harness or "agy"
	notify.info(
		string.format("Prompt dispatched to %s via %s backend", active_harness:upper(), backend_name),
		opts
	)

	-- Post-dispatch check for file edits and auto-open review split
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
