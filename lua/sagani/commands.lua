local notify = require("sagani.notify")
local selection = require("sagani.selection")
local diff = require("sagani.diff")
local backend = require("sagani.backend")

local M = {}

--- Registers all Neovim user commands for sagani.nvim
--- @param opts table Configuration options
function M.register_commands(opts)
  opts = type(opts) == "table" and opts or {}

  vim.api.nvim_create_user_command("SaganiStatus", function()
    local sagani = require("sagani")
    local options = sagani.options or opts
    local adapter, backend_name = backend.get_backend(options)
    local env_info = adapter.detect_env and adapter.detect_env(options.runner) or {}
    local env = env_info.metadata or env_info
    local status_opts = vim.tbl_deep_extend("force", options, { auto_spawn = false })
    local pane_id, err, _ = adapter.discover_target(status_opts)
    local task_agent = backend.resolve_task_agent(options, "chat")
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
      notify.info(msg, options)
    else
      notify.warn(msg, options)
    end
  end, { desc = "Show backend status and target AGY pane status" })

  vim.api.nvim_create_user_command("SaganiSelectTarget", function()
    local sagani = require("sagani")
    local options = sagani.options or opts
    vim.ui.input({ prompt = "Enter target Herdr pane ID (or empty to clear override): " }, function(input)
      if input and input ~= "" then
        options.pane_override = input
        notify.info("Target pane override set to: " .. input, options)
      else
        options.pane_override = nil
        notify.info("Target pane override cleared. Reverted to auto-discovery.", options)
      end
    end)
  end, { desc = "Set manual target pane ID override" })

  vim.api.nvim_create_user_command("SaganiSelectAgent", function(cmd_args)
    local sagani = require("sagani")
    sagani.select_agent_harness(cmd_args.args, sagani.options or opts)
  end, { nargs = "?", desc = "Select target agent harness (agy, codex, opencode, hermes, etc.)" })

  vim.api.nvim_create_user_command("SaganiAskAgent", function(cmd_args)
    local sagani = require("sagani")
    sagani.ask_agent_prompt(cmd_args.args)
  end, { nargs = "*", range = true, desc = "Ask general question to agent in Herdr popup" })

  vim.api.nvim_create_user_command("SaganiSelectHarness", function(cmd_args)
    local sagani = require("sagani")
    sagani.select_agent_harness(cmd_args.args, sagani.options or opts)
  end, { nargs = "?", desc = "Alias for SaganiSelectAgent" })

  vim.api.nvim_create_user_command("SaganiSpawnPane", function()
    local sagani = require("sagani")
    local options = sagani.options or opts
    local adapter, backend_name, placement, ui_opts, agent_opts = backend.get_backend(options, "chat")
    local harness = (agent_opts and agent_opts.harness) or "agy"
    local spawn_opts = vim.tbl_deep_extend(
      "force",
      options,
      { placement = placement, ui_opts = ui_opts, agent_opts = agent_opts }
    )
    local pane_id, err, _ = adapter.spawn_pane(spawn_opts)
    if pane_id then
      notify.info(
        string.format("Spawned new pane '%s' for '%s' via %s backend", pane_id, harness, backend_name),
        options
      )
    else
      notify.error(
        string.format("Failed to spawn pane via %s: %s", backend_name, err or "Unknown error"),
        options
      )
    end
  end, { desc = "Spawn new agent terminal pane" })

  vim.api.nvim_create_user_command("SaganiPrompt", function(cmd_args)
    local sagani = require("sagani")
    local options = sagani.options or opts
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
        sagani.dispatch_prompt(text)
      end
    end

    if prompt_text == "" then
      local task_agent = backend.resolve_task_agent(options, "chat")
      local agent_name = ((task_agent and task_agent.harness) or "agy"):upper()
      vim.ui.input({ prompt = string.format("Prompt for %s: ", agent_name) }, function(input)
        dispatch(input)
      end)
    else
      dispatch(prompt_text)
    end
  end, { nargs = "*", desc = "Send custom prompt to target agent pane" })

  vim.api.nvim_create_user_command("SaganiSend", function()
    local sagani = require("sagani")
    selection.send_selection_prompt(sagani.options or opts)
  end, { range = true, desc = "Send visual selection with instruction prompt to target agent" })

  vim.api.nvim_create_user_command("SaganiContext", function()
    local sagani = require("sagani")
    selection.send_code_context(sagani.options or opts)
  end, { range = true, desc = "Send visual selection code context to target agent" })

  vim.api.nvim_create_user_command("SaganiDiff", function()
    local sagani = require("sagani")
    diff.send_diff_comment(sagani.options or opts)
  end, { range = true, desc = "Send diff review comment to target agent" })

  vim.api.nvim_create_user_command("SaganiReview", function(cmd_args)
    local sagani = require("sagani")
    diff.toggle_review(nil, sagani.options or opts, cmd_args.args)
  end, { nargs = "?", desc = "Toggle agent edit review diff view (inline or split)" })

  vim.api.nvim_create_user_command("SaganiReviewToggle", function()
    local sagani = require("sagani")
    diff.toggle_review(nil, sagani.options or opts)
  end, { desc = "Alias for SaganiReview" })

  vim.api.nvim_create_user_command("SaganiAccept", function(cmd_args)
    local sagani = require("sagani")
    diff.accept_change(cmd_args.args, nil, sagani.options or opts)
  end, { nargs = "?", desc = "Accept agent edit change (hunk under cursor or all)" })

  vim.api.nvim_create_user_command("SaganiAcceptHunk", function()
    local sagani = require("sagani")
    diff.accept_change("hunk", nil, sagani.options or opts)
  end, { desc = "Accept agent edit hunk under cursor position" })

  vim.api.nvim_create_user_command("SaganiAcceptAll", function()
    local sagani = require("sagani")
    diff.accept_change("all", nil, sagani.options or opts)
  end, { desc = "Accept all agent edit changes in buffer" })

  vim.api.nvim_create_user_command("SaganiReject", function(cmd_args)
    local sagani = require("sagani")
    diff.reject_change(cmd_args.args, nil, sagani.options or opts)
  end, { nargs = "?", desc = "Reject agent edit change (revert hunk under cursor or all)" })

  vim.api.nvim_create_user_command("SaganiRejectHunk", function()
    local sagani = require("sagani")
    diff.reject_change("hunk", nil, sagani.options or opts)
  end, { desc = "Reject agent edit hunk under cursor position" })

  vim.api.nvim_create_user_command("SaganiRejectAll", function()
    local sagani = require("sagani")
    diff.reject_change("all", nil, sagani.options or opts)
  end, { desc = "Reject all agent edit changes in buffer" })

  vim.api.nvim_create_user_command("SaganiNextHunk", function()
    local sagani = require("sagani")
    diff.next_hunk(nil, sagani.options or opts)
  end, { desc = "Jump cursor to next agent edit hunk" })

  vim.api.nvim_create_user_command("SaganiPrevHunk", function()
    local sagani = require("sagani")
    diff.prev_hunk(nil, sagani.options or opts)
  end, { desc = "Jump cursor to previous agent edit hunk" })

  vim.api.nvim_create_user_command("SaganiReload", function()
    local sagani = require("sagani")
    local options = sagani.options or opts
    local saved_opts = vim.tbl_deep_extend("force", {}, options)
    for k in pairs(package.loaded) do
      if k:match("^sagani") then
        package.loaded[k] = nil
      end
    end
    require("sagani").setup(saved_opts)
    notify.info("Flushed all sagani.* modules and reloaded configuration", options)
  end, { desc = "Hot-reload all sagani modules" })

  vim.api.nvim_create_user_command("SaganiPromote", function(cmd_args)
    local target = cmd_args.args
    if not target or target == "" then
      target = "right"
    end
    local popup = require("sagani.ui.markdown_popup")
    popup.promote(nil, target)
  end, { nargs = "?", desc = "Promote floating popup window to split (left, right, top, bottom) or tab" })

  vim.api.nvim_create_user_command("SaganiClearCache", function()
    local sagani = require("sagani")
    require("sagani.cache").clear_cache()
    notify.info("Cleared Sagani persistent model cache", sagani.options or opts)
  end, { desc = "Clear persistent model cache" })

  vim.api.nvim_create_user_command("SaganiToggleBackend", function(cmd_args)
    local sagani = require("sagani")
    sagani.toggle_backend(cmd_args.args)
  end, { nargs = "?", desc = "Toggle backend transport mode between auto and native (or specify explicit backend)" })

  vim.api.nvim_create_user_command("SaganiBackend", function(cmd_args)
    local sagani = require("sagani")
    sagani.toggle_backend(cmd_args.args)
  end, { nargs = "?", desc = "Alias for SaganiToggleBackend" })
end

return M
