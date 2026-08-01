local topology = require("herdr-agy.topology")
local notify = require("herdr-agy.notify")
local format = require("herdr-agy.format")
local selection = require("herdr-agy.selection")
local diff = require("herdr-agy.diff")

local M = {}

M.defaults = {
  target_agent = "agy",
  auto_discover = true,
  auto_spawn = false,
  startup_delay = 5000,
  pane_override = nil,
  notify = {
    enabled = true,
    title = "herdr-agy.nvim",
  },
}

M.options = vim.tbl_deep_extend("force", {}, M.defaults)
M.format = format
M.selection = selection
M.diff = diff

function M.setup(user_opts)
  user_opts = type(user_opts) == "table" and user_opts or {}
  M.options = vim.tbl_deep_extend("force", M.defaults, user_opts)

  -- Register User Commands
  vim.api.nvim_create_user_command("HerdrAgyStatus", function()
    local env = topology.detect_env()
    local pane_id, err, _ = topology.discover_target_pane(M.options)
    local msg = string.format(
      "Herdr Session: %s | Pane: %s | Tab: %s | Workspace: %s\nTarget Pane (%s): %s",
      env.in_herdr and "ACTIVE" or "INACTIVE",
      env.pane_id or "N/A",
      env.tab_id or "N/A",
      env.workspace_id or "N/A",
      M.options.target_agent or "agy",
      pane_id or ("NONE (" .. (err or "Unknown") .. ")")
    )
    if pane_id then
      notify.info(msg, M.options)
    else
      notify.warn(msg, M.options)
    end
  end, { desc = "Show Herdr topology and target AGY pane status" })

  vim.api.nvim_create_user_command("HerdrAgySelectTarget", function()
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

  vim.api.nvim_create_user_command("HerdrAgySpawnPane", function()
    local pane_id, err, _ = topology.spawn_agy_pane(M.options)
    if pane_id then
      notify.info(string.format("Spawned new right pane '%s' for '%s'", pane_id, M.options.target_agent), M.options)
    else
      notify.error("Failed to spawn Herdr pane: " .. (err or "Unknown error"), M.options)
    end
  end, { desc = "Spawn vertical right Herdr pane and start AGY" })

  vim.api.nvim_create_user_command("HerdrAgyPrompt", function(cmd_args)
    local prompt_text = cmd_args.args
    if prompt_text == "" then
      vim.ui.input({ prompt = "Prompt for AGY: " }, function(input)
        if input and input ~= "" then
          M.dispatch_prompt(input)
        end
      end)
    else
      M.dispatch_prompt(prompt_text)
    end
  end, { nargs = "*", desc = "Send custom prompt to AGY agent pane" })

  vim.api.nvim_create_user_command("HerdrAgySend", function()
    selection.send_selection_prompt(M.options)
  end, { range = true, desc = "Send visual selection with instruction prompt to AGY" })

  vim.api.nvim_create_user_command("HerdrAgyContext", function()
    selection.send_code_context(M.options)
  end, { range = true, desc = "Send visual selection code context to AGY" })

  vim.api.nvim_create_user_command("HerdrAgyDiff", function()
    diff.send_diff_comment(M.options)
  end, { range = true, desc = "Send diff review comment to AGY" })
end

function M.dispatch_prompt(prompt_text, target_pane, opts)
  opts = type(opts) == "table" and opts or M.options
  if type(prompt_text) ~= "string" or prompt_text == "" then
    local err_msg = "Invalid prompt text: must be a non-empty string"
    notify.error(err_msg, opts)
    return false, err_msg
  end

  if target_pane == "" then
    target_pane = nil
  end

  local pane_override = (type(opts.pane_override) == "string" and opts.pane_override ~= "") and opts.pane_override or (type(opts.pane_override) == "number" and tostring(opts.pane_override) or nil)
  local pane_id = target_pane or pane_override
  local err, meta

  if not pane_id then
    pane_id, err, meta = topology.discover_target_pane(opts)
  end

  if not pane_id then
    notify.error("Cannot dispatch prompt: " .. (err or "Target pane not found"), opts)
    return false, err
  end

  -- If pane was newly spawned, perform 3-stage readiness detection before prompt delivery
  if meta and meta.spawned and not _G.RUNNING_TEST_SUITE then
    notify.info("Waiting for AGY CLI to authenticate & render ready prompt...", opts)
    vim.cmd("redraw")
    topology.wait_for_agy_ready(pane_id, 20000, opts)
  end

  if vim.fn.executable("herdr") == 0 then
    local msg = "'herdr' CLI binary not found in PATH"
    notify.error(msg, opts)
    return false, msg
  end

  local cmd = { "herdr", "agent", "prompt", pane_id, prompt_text }
  local out_text = ""
  local code
  if vim.system then
    local res = vim.system(cmd):wait()
    code = res.code
    local stderr = res.stderr or ""
    local stdout = res.stdout or ""
    if code ~= 0 then
      out_text = (stderr ~= "" and stderr) or stdout
    else
      out_text = stdout
    end
  else
    out_text = vim.fn.system(cmd)
    code = vim.v.shell_error
  end

  if code ~= 0 then
    local msg = string.format("Failed to prompt agent pane '%s' (exit code %d): %s", pane_id, code, out_text)
    notify.error(msg, opts)
    return false, msg
  end

  notify.info(string.format("Prompt dispatched to AGY pane '%s'", pane_id), opts)
  return true, nil
end

return M
