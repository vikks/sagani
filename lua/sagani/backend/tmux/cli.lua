--- ==============================================================================
--- Module: sagani.backend.tmux.cli
---
--- Description:
---   Tmux CLI command executor for sagani.nvim. Detects $TMUX environment variables,
---   splits Tmux panes (`tmux split-window`), launches popup windows (`tmux display-popup`),
---   and sends keys (`tmux send-keys`) to target Tmux pane handles.
---
--- Responsibilities:
---   - Detect active Tmux environment via $TMUX.
---   - Execute Tmux pane splitting and popup display commands.
---   - Deliver prompt text to target Tmux panes via tmux send-keys.
--- ==============================================================================

local M = {}

--- Executes a command via runner or vim.system / vim.fn.system
--- @param cmd table Command arguments array
--- @param opts table Options table (may contain runner)
--- @return string stdout, number code
function M.exec_cmd(cmd, opts)
  opts = type(opts) == "table" and opts or {}
  if opts.runner then
    local out, code = opts.runner(cmd)
    return out or "", code or 0
  end

  if vim.system then
    local res = vim.system(cmd):wait()
    return res.stdout or "", res.code or 0
  end

  local out = vim.fn.system(cmd)
  return out or "", vim.v.shell_error or 0
end

--- Detects active Tmux environment
--- @return table { active, id, metadata }
function M.detect_env(_)
  local tmux_env = vim.env.TMUX
  local is_tmux = tmux_env ~= nil and tmux_env ~= ""
  local pane_id = vim.env.TMUX_PANE
  return {
    active = is_tmux,
    id = pane_id,
    metadata = { tmux = tmux_env, pane = pane_id },
  }
end

--- Lists active tmux panes
--- @param runner function|nil Mock runner for tests
--- @return table|nil agents, string|nil err
function M.list_agents(runner)
  local cmd = { "tmux", "list-panes", "-a", "-F", "#{pane_id}\t#{pane_current_command}\t#{pane_title}\t#{pane_current_path}" }
  local stdout, code = M.exec_cmd(cmd, { runner = runner })

  if code ~= 0 or not stdout or stdout == "" then
    return {}, nil
  end

  local agents = {}
  for line in stdout:gmatch("[^\r\n]+") do
    local p_id, p_cmd, p_title, p_path = line:match("^([^\t]+)\t([^\t]*)\t([^\t]*)\t?(.*)$")
    if p_id then
      table.insert(agents, {
        pane_id = p_id,
        agent = (p_cmd and p_cmd ~= "") and p_cmd or "agent",
        terminal_title = p_title,
        cwd = p_path,
      })
    end
  end

  return agents, nil
end

--- Discovers target tmux pane ID from options or override
--- @param opts table Options table
--- @return string|nil pane_id, string|nil err, table metadata
function M.discover_target(opts)
  opts = type(opts) == "table" and opts or {}
  if opts.pane_override then
    return tostring(opts.pane_override), nil, {}
  end
  local target = opts.backends and opts.backends.tmux and opts.backends.tmux.target_pane
  if target and target ~= "" then
    return target, nil, {}
  end
  return nil, "No target tmux pane configured (use opts.pane_override or opts.backends.tmux.target_pane)", {}
end

--- Spawns a new tmux pane or window
--- @param opts table Options table
--- @return string|nil pane_id, string|nil err, table metadata
function M.spawn_pane(opts)
  opts = type(opts) == "table" and opts or {}
  local backend_lib = require("sagani.backend")
  local agent = (opts.agent_opts and backend_lib.resolve_agent_cmd(opts.agent_opts)) or opts.target_agent or "agy"
  local placement = opts.placement or "right-pane"

  if placement == "popup" or placement == "floating" then
    return M.spawn_popup(opts)
  end

  if placement == "tab" or placement == "new-tab" then
    if _G.RUNNING_TEST_SUITE and not opts.runner then
      return "%tab1", nil, { spawned = true, is_popup = false, is_tab = true }
    end
    local cmd = { "tmux", "new-window", "-P", "-F", "#{pane_id}", agent }
    local stdout, code = M.exec_cmd(cmd, opts)
    if code == 0 and stdout and stdout ~= "" then
      return vim.trim(stdout), nil, { spawned = true, is_popup = false, is_tab = true }
    end
    return nil, "Failed to create tmux window/tab", {}
  end

  local split_flag = "-h"
  if placement == "bottom-pane" or placement == "down" or (opts.backends and opts.backends.tmux and opts.backends.tmux.split_direction == "bottom") then
    split_flag = "-v"
  end

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    return "%1", nil, { spawned = true, is_popup = false }
  end

  local cmd = { "tmux", "split-window", split_flag, "-P", "-F", "#{pane_id}", agent }
  local stdout, code = M.exec_cmd(cmd, opts)

  if code == 0 and stdout and stdout ~= "" then
    local pane_id = vim.trim(stdout)
    return pane_id, nil, { spawned = true, is_popup = false }
  end

  return nil, "Failed to split tmux pane", {}
end

--- Spawns a tmux display-popup window
--- @param opts table Options table
--- @return string|nil target_id, string|nil err, table metadata
function M.spawn_popup(opts)
  opts = type(opts) == "table" and opts or {}
  local backend_lib = require("sagani.backend")
  local agent = (opts.agent_opts and backend_lib.resolve_agent_cmd(opts.agent_opts)) or opts.target_agent or "agy"

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    return "%popup", nil, { spawned = true, is_popup = true }
  end

  local cmd = { "tmux", "display-popup", "-E", "-w", "80%", "-h", "80%", agent }
  local _, code = M.exec_cmd(cmd, opts)

  if code == 0 then
    return "%popup", nil, { spawned = true, is_popup = true }
  end

  return nil, "Failed to display tmux popup", {}
end

--- Sends prompt text to a target tmux pane
--- @param target_id string Target pane ID
--- @param prompt_text string Text to send
--- @param opts table Options table
--- @return boolean ok, string|nil err
function M.prompt_target(target_id, prompt_text, opts)
  opts = type(opts) == "table" and opts or {}
  if _G.RUNNING_TEST_SUITE and not opts.runner then
    return true, nil
  end

  local cmd = { "tmux", "send-keys", "-t", target_id, prompt_text, "C-m" }
  local stdout, code = M.exec_cmd(cmd, opts)

  if code ~= 0 then
    return false, string.format("Failed to send prompt to tmux pane '%s': %s", target_id, stdout)
  end

  return true, nil
end

return M
