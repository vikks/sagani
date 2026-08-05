local cli = require("sagani.backend.herdr.cli")

local M = {
	name = "herdr",
	capabilities = {
		ask = false, -- Herdr does not support floating popups out-of-the-box -> falls back to native popup
		review = true,
		code = true,
		chat = true,
	},
}

function M.list_agents(runner)
	return cli.list_agents(runner)
end

function M.detect_env(runner)
	local env = cli.detect_env(runner)
	return {
		active = env.in_herdr,
		id = env.pane_id,
		metadata = env,
	}
end

function M.discover_target(opts)
	return cli.discover_target_pane(opts)
end

function M.spawn_pane(opts)
	opts = type(opts) == "table" and opts or {}
	local placement = opts.placement or "right-pane"
	local direction = (placement == "bottom-pane" or placement == "down") and "down" or "right"
	opts.direction = direction
	local ui_opts = opts.ui_opts or {}
	if ui_opts.ratio then
		opts.ratio = ui_opts.ratio
	end
	return cli.spawn_agent_pane(opts)
end

--- Herdr does not support floating popup windows via CLI.
--- Calls to spawn_popup return unsupported error so backend manager falls back to native.
function M.spawn_popup(opts)
	return nil, "backend 'herdr' does not support floating popups"
end

--- Dispatches a prompt to a named agent via the herdr CLI.
--- @param target_id string Agent name (as returned by spawn_popup) or pane_id
--- @param prompt_text string Prompt text
--- @param opts table|nil Options (runner for tests)
--- @return boolean ok, string|nil err
function M.prompt_target(target_id, prompt_text, opts)
	opts = type(opts) == "table" and opts or {}

	if vim.fn.executable("herdr") == 0 and not _G.RUNNING_TEST_SUITE and not opts.runner then
		return false, "'herdr' CLI binary not found in PATH"
	end

	local cmd = { "herdr", "agent", "prompt", target_id, prompt_text }
	local out_text = ""
	local code = 0

	if opts.runner then
		out_text, code = opts.runner(cmd)
	elseif vim.system then
		local res = vim.system(cmd):wait()
		code = res.code
		local stderr = res.stderr or ""
		local stdout = res.stdout or ""
		out_text = (stderr ~= "" and stderr) or stdout
	else
		out_text = vim.fn.system(cmd)
		code = vim.v.shell_error
	end

	if code ~= 0 then
		return false, string.format("exit code %d: %s", code, out_text)
	end

	return true, nil
end

function M.wait_for_ready(target_id, opts)
	opts = type(opts) == "table" and opts or {}
	return cli.wait_for_agent_ready(target_id, opts.timeout_ms or 20000, opts)
end

return M
