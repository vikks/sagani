--- ==============================================================================
--- Module: sagani.ui.picker.target
---
--- Description:
---   Target agent pane selection UI for sagani.nvim. Queries active multiplexer
---   agent panes (Herdr, Tmux, Zellij) and Native Neovim agent panes to present an
---   interactive vim.ui.select picker.
---
--- Responsibilities:
---   - Query active multiplexer and native Neovim agent panes.
---   - Format clean, human-readable pane labels without redundant workspace IDs.
---   - Present interactive target pane picker (`select_target_pane`).
--- ==============================================================================

local notify = require("sagani.notify")
local backend = require("sagani.backend")

local M = {}

--- Interactively selects target agent pane from list of running agent panes or resets to auto-discovery
--- @param opts table|nil Options table
--- @param on_complete function|nil Optional callback on selection
--- @return string|nil selected_pane_id
function M.select_target_pane(opts, on_complete)
  local sagani = require("sagani")
  opts = type(opts) == "table" and opts or sagani.options or {}

  local adapter, backend_name = backend.get_backend(opts)
  local active_override = opts.pane_override

  local choices = {
    {
      id = "auto",
      label = "[Auto-Discover Target Pane] (Clear Manual Override)",
      pane_id = nil,
    },
  }

  local agent_panes = {}
  local seen_panes = {}

  -- 1. Query active backend agent panes (Herdr, Tmux, Zellij)
  if adapter and adapter.list_agents then
    local backend_agents = adapter.list_agents(opts.runner) or {}
    for _, a in ipairs(backend_agents) do
      if type(a) == "table" and (a.pane_id or a.id) then
        table.insert(agent_panes, a)
        seen_panes[tostring(a.pane_id or a.id)] = true
      end
    end
  elseif backend_name == "herdr" then
    local herdr_cli = require("sagani.backend.herdr.cli")
    local herdr_agents = herdr_cli.list_agents(opts.runner) or {}
    for _, a in ipairs(herdr_agents) do
      if type(a) == "table" and (a.pane_id or a.id) then
        table.insert(agent_panes, a)
        seen_panes[tostring(a.pane_id or a.id)] = true
      end
    end
  end

  -- 2. Query Native Neovim agent panes (always available as fallback/option)
  if backend_name ~= "native" then
    local native_adapter = require("sagani.backend.native")
    if native_adapter and native_adapter.list_agents then
      local native_agents = native_adapter.list_agents(opts.runner) or {}
      for _, na in ipairs(native_agents) do
        if type(na) == "table" and (na.pane_id or na.id) then
          local p_id = tostring(na.pane_id or na.id)
          if not seen_panes[p_id] then
            table.insert(agent_panes, na)
            seen_panes[p_id] = true
          end
        end
      end
    end
  end

  if type(agent_panes) == "table" then
    local current_cwd = vim.fn.getcwd()
    for _, a in ipairs(agent_panes) do
      if type(a) == "table" and (a.pane_id or a.id) then
        local raw_p_id = tostring(a.pane_id or a.id)
        local agent_name = (a.agent or a.harness or "agent"):upper()
        local status = (a.agent_status and a.agent_status ~= "") and string.format("[%s]", a.agent_status) or ""

        -- CWD directory formatting (short folder name or current dir indicator)
        local dir_str = ""
        if a.cwd and a.cwd ~= "" then
          if a.cwd == current_cwd then
            dir_str = " (current dir)"
          else
            local folder_name = vim.fn.fnamemodify(a.cwd, ":t")
            dir_str = string.format(" in %s", (folder_name ~= "" and folder_name or a.cwd))
          end
        end

        -- Terminal title formatting (if custom)
        local title_str = ""
        if a.terminal_title and a.terminal_title ~= "" and a.terminal_title:lower() ~= a.agent:lower() then
          title_str = string.format(" — \"%s\"", a.terminal_title)
        end

        local is_active = (active_override and tostring(active_override) == raw_p_id)
        local label = string.format(
          "[%s] %s %s%s%s%s",
          raw_p_id,
          agent_name,
          status,
          dir_str,
          title_str,
          is_active and " (active override)" or ""
        )

        table.insert(choices, {
          id = raw_p_id,
          label = label,
          pane_id = raw_p_id,
          agent_name = agent_name,
        })
      end
    end
  end

  table.insert(choices, {
    id = "manual",
    label = "[Manual Pane ID Input...]",
    pane_id = "manual",
  })

  if not _G.RUNNING_TEST_SUITE and vim.ui and vim.ui.select then
    local prompt_title = string.format(
      "Select Target Agent Pane (Backend: %s | Override: %s):",
      (backend_name or "auto"):upper(),
      active_override and tostring(active_override) or "Auto"
    )

    vim.ui.select(choices, {
      prompt = prompt_title,
      format_item = function(item)
        return item.label
      end,
    }, function(choice)
      if not choice then
        return
      end

      if choice.id == "auto" then
        opts.pane_override = nil
        notify.info("Target pane override cleared. Reverted to auto-discovery.", opts)
        if on_complete then on_complete(nil) end
      elseif choice.id == "manual" then
        vim.ui.input({ prompt = "Enter target pane ID: " }, function(input)
          if input and input ~= "" then
            opts.pane_override = vim.trim(input)
            notify.info("Target pane override set to: " .. input, opts)
            if on_complete then on_complete(opts.pane_override) end
          end
        end)
      else
        opts.pane_override = choice.pane_id
        notify.info(string.format("Target pane override set to: %s (%s)", choice.pane_id, choice.agent_name or "Agent"), opts)
        if on_complete then on_complete(choice.pane_id) end
      end
    end)
  end

  return opts.pane_override
end

return M
