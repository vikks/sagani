--- ==============================================================================
--- Module: sagani.ui.picker
---
--- Description:
---   Interactive selection picker UI for agent harness selection (`:SaganiSelectAgent`),
---   dynamic model selection (`<leader>ah`), reasoning effort level selection, and
---   operating mode toggles. Uses Snacks.picker / Telescope / Snacks / vim.ui.select.
---
--- Responsibilities:
---   - Render agent harness selection UI with dynamic model discovery.
---   - Prompt for reasoning effort levels (low, medium, high) based on model capabilities.
---   - Invoke completion callbacks on harness/model selection.
--- ==============================================================================

local notify = require("sagani.notify")
local backend = require("sagani.backend")

local M = {}

--- Evaluates whether a given agent harness + model combination supports reasoning effort settings
--- @param harness_name string Agent harness identifier
--- @param selected_model string Selected model identifier
--- @return boolean supports_effort
function M.supports_effort(harness_name, selected_model)
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

--- Interactively prompts for dynamic CLI model and reasoning effort for an active harness
--- @param harness string Agent harness identifier
--- @param opts table Configuration options
--- @param on_complete function|nil Completion callback
function M.prompt_model_and_effort(harness, opts, on_complete)
  local sagani = require("sagani")
  opts = type(opts) == "table" and opts or sagani.options
  harness = (harness or "agy"):lower()
  sagani._session_agent = harness
  sagani._session_harness = harness

  local cli_transport = require("sagani.protocol.cli")
  local efforts = { "low", "medium", "high" }

  cli_transport.list_models_async(harness, opts, function(models)
    models = models or {}

    local function finish()
      local m_str = sagani._session_model or "Default"
      local e_str = sagani._session_effort or "Default"
      notify.info(
        string.format("Active Agent: '%s' | Model: %s | Effort: %s", harness:upper(), m_str, e_str),
        opts
      )
      if on_complete then
        on_complete(harness)
      end
    end

    local function pick_effort()
      local model_name = sagani._session_model or ""
      if not M.supports_effort(harness, model_name) then
        sagani._session_effort = nil
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
            sagani._session_effort = e_choice
          else
            sagani._session_effort = nil
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
            sagani._session_model = m_choice
          else
            sagani._session_model = nil
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

--- Interactively selects active agent harness from list of candidates or custom input
--- @param arg string|nil Direct harness string or nil to prompt interactively
--- @param opts table Configuration options
--- @param on_complete function|nil Completion callback
--- @return string|nil active_harness
function M.select_agent_harness(arg, opts, on_complete)
  local sagani = require("sagani")
  opts = type(opts) == "table" and opts or sagani.options

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

  local active_h = sagani._session_agent or sagani._session_harness or "none"
  if not _G.RUNNING_TEST_SUITE and vim.ui and vim.ui.select then
    vim.ui.select(choices, {
      prompt = string.format("Select Target Agent (Active Session: %s):", active_h),
      format_item = function(item)
        if item == sagani._session_agent or item == sagani._session_harness then
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

  return sagani._session_harness
end

--- Interactively selects active Sagani operating mode (review, learn, or user-defined modes)
--- @param opts table Configuration options
function M.select_mode(opts)
  local sagani = require("sagani")
  opts = type(opts) == "table" and opts or sagani.options

  local mode_set = { review = true, learn = true }
  if type(opts.tasks) == "table" then
    for t_name, _ in pairs(opts.tasks) do
      if type(t_name) == "string" then
        mode_set[t_name] = true
      end
    end
  end

  local modes = {}
  for m_name, _ in pairs(mode_set) do
    table.insert(modes, m_name)
  end
  table.sort(modes)
  table.insert(modes, "off")

  local active = sagani._session_mode or "off"

  if not _G.RUNNING_TEST_SUITE and vim.ui and vim.ui.select then
    vim.ui.select(modes, {
      prompt = string.format("Select Sagani Operating Mode (Current: %s):", active:upper()),
      format_item = function(item)
        if item == sagani._session_mode then
          return item:upper() .. " (active)"
        elseif item == "off" and not sagani._session_mode then
          return "OFF (standard operation)"
        end
        return item:upper()
      end,
    }, function(choice)
      if choice then
        sagani.set_mode(choice)
      end
    end)
  end
end

return M
