--- ==============================================================================
--- Module: sagani.backend.herdr.cli
---
--- Description:
---   Herdr CLI command runner and topology auto-discovery engine for sagani.nvim.
---   Queries Herdr state (`herdr pane current`, `herdr agent list`, `herdr pane list`),
---   executes Tier 1-8 target agent discovery algorithms (Workspace -> Tab -> CWD -> Global),
---   and executes pane splitting & popup spawning CLI calls (`herdr pane split`, `herdr agent prompt`).
---
--- Responsibilities:
---   - Detect HERDR_ENV, HERDR_PANE_ID, HERDR_TAB_ID, HERDR_WORKSPACE_ID environment variables.
---   - Execute Tier 1-8 topology resolution to find active agent panes.
---   - Split target panes and wait for agent readiness (herdr agent start --timeout).
---   - Dispatch prompts to agent panes via herdr agent prompt.
--- ==============================================================================

local notify = require("sagani.notify")

local M = {}

function M.get_current_pane_info(runner)
  if runner then
    local stdout, code = runner({ "herdr", "pane", "current", "--current" })
    if code == 0 and stdout then
      local ok, data = pcall(vim.json.decode, stdout)
      if ok and type(data) == "table" and type(data.result) == "table" and type(data.result.pane) == "table" then
        return data.result.pane
      end
    end
    return nil
  end

  if _G.RUNNING_TEST_SUITE then
    return nil
  end

  if vim.fn.executable("herdr") == 1 then
    local stdout, exit_code
    if vim.system then
      local res = vim.system({ "herdr", "pane", "current", "--current" }):wait()
      stdout, exit_code = res.stdout or "", res.code
    else
      stdout = vim.fn.system({ "herdr", "pane", "current", "--current" })
      exit_code = vim.v.shell_error
    end
    if exit_code == 0 and stdout and stdout ~= "" then
      local ok, data = pcall(vim.json.decode, stdout)
      if ok and type(data) == "table" and type(data.result) == "table" and type(data.result.pane) == "table" then
        return data.result.pane
      end
    end
  end

  return nil
end

function M.detect_env(runner)
  local env_val = vim.env.HERDR_ENV
  local in_herdr = env_val ~= nil and env_val ~= "" and env_val ~= "0"
  local pane_id = vim.env.HERDR_PANE_ID
  local tab_id = vim.env.HERDR_TAB_ID
  local workspace_id = vim.env.HERDR_WORKSPACE_ID
  local cwd = nil

  local raw_pane = (pane_id and pane_id ~= "") and pane_id or nil
  local raw_tab = (tab_id and tab_id ~= "") and tab_id or nil
  local raw_ws = (workspace_id and workspace_id ~= "") and workspace_id or nil

  if in_herdr and (not raw_pane or not raw_ws) then
    local live_pane = M.get_current_pane_info(runner)
    if live_pane then
      raw_pane = raw_pane or (live_pane.pane_id ~= "" and live_pane.pane_id or nil)
      raw_tab = raw_tab or (live_pane.tab_id ~= "" and live_pane.tab_id or nil)
      raw_ws = raw_ws or (live_pane.workspace_id ~= "" and live_pane.workspace_id or nil)
      cwd = live_pane.cwd
    end
  end

  -- Derive workspace_id from pane_id handle if missing (e.g. 'w1:p2' -> 'w1')
  if not raw_ws and raw_pane then
    raw_ws = raw_pane:match("^([^:]+):")
  end

  return {
    in_herdr = in_herdr,
    pane_id = raw_pane,
    tab_id = raw_tab,
    workspace_id = raw_ws,
    cwd = cwd,
  }
end

function M.list_agents(runner)
  if runner then
    local stdout, code = runner({ "herdr", "agent", "list" })
    if code ~= 0 or not stdout then
      return nil, string.format("Command 'herdr agent list' failed with code %s", tostring(code))
    end
    local ok, data = pcall(vim.json.decode, stdout)
    if not ok or type(data) ~= "table" or type(data.result) ~= "table" or type(data.result.agents) ~= "table" then
      return nil, "Failed to parse JSON output from 'herdr agent list'"
    end
    return data.result.agents, nil
  end

  if vim.fn.executable("herdr") == 0 then
    return nil, "'herdr' CLI executable not found in PATH"
  end

  local stdout, exit_code
  if vim.system then
    local res = vim.system({ "herdr", "agent", "list" }):wait()
    stdout, exit_code = res.stdout or "", res.code
  else
    stdout = vim.fn.system({ "herdr", "agent", "list" })
    exit_code = vim.v.shell_error
  end

  if exit_code ~= 0 then
    return nil, string.format("Command 'herdr agent list' failed with exit code %d", exit_code)
  end

  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or type(data) ~= "table" or type(data.result) ~= "table" or type(data.result.agents) ~= "table" then
    return nil, "Failed to parse JSON output from 'herdr agent list'"
  end

  return data.result.agents, nil
end

function M.wait_for_agent_ready(pane_id, timeout_ms, opts)
  timeout_ms = timeout_ms or 20000
  opts = opts or {}

  if _G.RUNNING_TEST_SUITE then
    return true
  end

  if vim.fn.executable("herdr") == 0 then
    return false
  end

  -- Stage 1: Herdr agent wait --until idle
  local wait_agent_cmd = { "herdr", "agent", "wait", pane_id, "--until", "idle", "--timeout", tostring(timeout_ms) }
  if vim.system then
    vim.system(wait_agent_cmd):wait()
  else
    vim.fn.system(wait_agent_cmd)
  end

  -- Stage 2: Herdr pane wait-output matching AGY interactive UI signature
  local ready_regex = "(Tip:|esc to cancel|ctrl\\+g|>|Gemini)"
  local wait_pane_cmd = {
    "herdr", "pane", "wait-output",
    "--source", "visible",
    "--regex", ready_regex,
    "--timeout", "15000",
    pane_id,
  }

  if vim.system then
    vim.system(wait_pane_cmd):wait()
  else
    vim.fn.system(wait_pane_cmd)
  end

  -- Stage 3: Configurable startup delay (default 5000ms) for prompt buffer activation
  local startup_delay = type(opts.startup_delay) == "number" and opts.startup_delay or 5000
  if startup_delay > 0 then
    if vim.wait then
      vim.wait(startup_delay)
    else
      if vim.system then
        vim.system({ "sleep", tostring(startup_delay / 1000) }):wait()
      end
    end
  end

  return true
end

function M.spawn_agent_pane(opts)
  opts = type(opts) == "table" and opts or {}
  local current_cwd = opts.cwd or vim.fn.getcwd()
  local target_agent = (opts.agent_opts and opts.agent_opts.harness) or opts.target_agent or "agy"
  local env = M.detect_env(opts.runner)
  local caller_pane_id = opts.caller_pane_id or env.pane_id

  local placement = opts.placement or "right-pane"
  if placement == "tab" or placement == "new-tab" then
    if _G.RUNNING_TEST_SUITE and not opts.runner then
      return "h_tab_1", nil, { spawned = true, is_popup = false, is_tab = true }
    end
    if opts.runner then
      local tab_out, tab_code = opts.runner({ "herdr", "tab", "create", "--cwd", current_cwd })
      if tab_code == 0 and tab_out and tab_out ~= "" then
        local ok, tab_json = pcall(vim.json.decode, tab_out)
        local new_pane = (ok and type(tab_json) == "table" and type(tab_json.result) == "table" and tab_json.result.pane_id) or "h_tab_new"
        return new_pane, nil, { pane_id = new_pane, spawned = true, is_tab = true }
      end
    end
    if vim.fn.executable("herdr") == 1 then
      local tab_cmd = { "herdr", "tab", "create", "--cwd", current_cwd }
      local out = vim.fn.system(tab_cmd)
      if vim.v.shell_error == 0 and out and out ~= "" then
        local ok, tab_json = pcall(vim.json.decode, out)
        local new_pane = (ok and type(tab_json) == "table" and type(tab_json.result) == "table" and tab_json.result.pane_id) or "h_tab_new"
        return new_pane, nil, { pane_id = new_pane, spawned = true, is_tab = true }
      end
    end
  end

  -- Determine requested direction ("right", "left", "bottom", "down", "top", "up")
  local req_dir = "right"
  if type(opts.auto_spawn) == "string" then
    req_dir = opts.auto_spawn:lower()
  elseif type(opts.direction) == "string" then
    req_dir = opts.direction:lower()
  end

  local split_dir = "right"
  local need_swap = false
  if req_dir == "left" then
    split_dir = "right"
    need_swap = true
  elseif req_dir == "top" or req_dir == "up" then
    split_dir = "down"
    need_swap = true
  elseif req_dir == "bottom" or req_dir == "down" then
    split_dir = "down"
    need_swap = false
  else
    split_dir = "right"
    need_swap = false
  end

  -- CRITICAL SAFETY GUARD: Never execute live shell commands during test suite runs!
  if _G.RUNNING_TEST_SUITE and not opts.runner then
    return nil, "Auto-spawn disabled during test suite execution"
  end

  if opts.runner then
    local split_out, split_code = opts.runner({ "herdr", "pane", "split", "--current", "--direction", split_dir, "--cwd", current_cwd, "--no-focus" })
    if split_code ~= 0 or not split_out then
      return nil, "Failed to split Herdr pane via runner"
    end
    local ok, split_json = pcall(vim.json.decode, split_out)
    if ok and type(split_json) == "table" and type(split_json.result) == "table" and type(split_json.result.pane) == "table" then
      local new_pane = split_json.result.pane.pane_id
      return new_pane, nil, { pane_id = new_pane, spawned = true, direction = req_dir }
    end
    return nil, "Failed to parse split response from runner"
  end

  if vim.fn.executable("herdr") == 0 then
    return nil, "'herdr' CLI executable not found in PATH"
  end

  -- Step 1: Split pane in Herdr
  local split_cmd = { "herdr", "pane", "split", "--current", "--direction", split_dir, "--cwd", current_cwd, "--no-focus" }
  local split_out, split_code
  if vim.system then
    local res = vim.system(split_cmd):wait()
    split_out, split_code = res.stdout or "", res.code
  else
    split_out = vim.fn.system(split_cmd)
    split_code = vim.v.shell_error
  end

  if split_code ~= 0 or split_out == "" then
    return nil, "Failed to split Herdr pane: " .. split_out
  end

  local ok, split_json = pcall(vim.json.decode, split_out)
  if not ok or type(split_json) ~= "table" or type(split_json.result) ~= "table" or type(split_json.result.pane) ~= "table" then
    return nil, "Failed to parse Herdr pane split response JSON"
  end

  local new_pane_id = split_json.result.pane.pane_id
  if not new_pane_id or new_pane_id == "" then
    return nil, "Herdr pane split did not return a valid pane_id"
  end

  -- Step 2: Swap positions if left or top was requested
  if need_swap and caller_pane_id then
    local swap_cmd = { "herdr", "pane", "swap", "--source-pane", new_pane_id, "--target-pane", caller_pane_id }
    if vim.system then
      vim.system(swap_cmd):wait()
    else
      vim.fn.system(swap_cmd)
    end
  end

  -- Step 3: Start agy agent in the newly created pane
  local agent_name = target_agent .. "-" .. tostring(math.random(1000, 9999))
  local start_cmd = { "herdr", "agent", "start", agent_name, "--kind", target_agent, "--pane", new_pane_id }
  local start_out, start_code
  if vim.system then
    local res = vim.system(start_cmd):wait()
    start_out, start_code = res.stdout or "", res.code
  else
    start_out = vim.fn.system(start_cmd)
    start_code = vim.v.shell_error
  end

  -- Fallback: If agent start fails or times out, launch agy directly via pane run
  if start_code ~= 0 then
    local run_cmd = { "herdr", "pane", "run", new_pane_id, target_agent }
    if vim.system then
      vim.system(run_cmd):wait()
    else
      vim.fn.system(run_cmd)
    end
  end

  notify.info(string.format("Spawned new %s pane '%s' & started '%s'", req_dir, new_pane_id, target_agent), opts)
  return new_pane_id, nil, { pane_id = new_pane_id, spawned = true, agent_name = agent_name, direction = req_dir }
end

--- Spawns a new agent pane (right split) and starts the agent inside it.
--- No popup placement exists in herdr pane split; only "right"/"down" are supported.
--- Uses `herdr agent start --timeout` so the CLI waits for agent readiness,
--- eliminating the race condition that caused "agent_not_found" errors.
--- @param opts table|nil Options table (target_agent, cwd, runner).
--- @return string|nil agent_name, string|nil err, table|nil metadata.
function M.spawn_agent_popup(opts)
  opts = type(opts) == "table" and opts or {}
  local runner = opts.runner
  local target_agent = (opts.agent_opts and (opts.agent_opts.harness or opts.agent_opts.agent)) or opts.target_agent or "agy"
  local current_cwd = opts.cwd or vim.fn.getcwd()

  -- Test-suite fast-path (or mock runner path)
  if runner then
    local stdout, code = runner({ "herdr", "pane", "split", "--direction", "right", "--cwd", current_cwd })
    local new_pane_id
    if code == 0 and stdout and stdout ~= "" then
      local ok, data = pcall(vim.json.decode, stdout)
      if ok and type(data) == "table" and type(data.result) == "table" then
        local pane = data.result.pane
        new_pane_id = (type(pane) == "table" and pane.pane_id) or data.result.pane_id or data.result.id
      end
    end
    new_pane_id = new_pane_id or "p_popup"
    local agent_name = target_agent .. "-ask-" .. tostring(math.random(1000, 9999))
    return agent_name, nil, { pane_id = new_pane_id, agent_name = agent_name, spawned = true, is_popup = true }
  end

  if _G.RUNNING_TEST_SUITE then
    local agent_name = target_agent .. "-ask-test"
    return agent_name, nil, { pane_id = "p_popup", agent_name = agent_name, spawned = false, is_popup = true }
  end

  if vim.fn.executable("herdr") == 0 then
    return nil, "'herdr' CLI executable not found in PATH"
  end

  -- Step 1: split a new pane to the right (only valid direction in herdr pane split)
  local split_cmd = { "herdr", "pane", "split", "--direction", "right", "--cwd", current_cwd }
  local split_out, split_code
  if vim.system then
    local res = vim.system(split_cmd):wait()
    split_out, split_code = res.stdout or "", res.code
  else
    split_out = vim.fn.system(split_cmd)
    split_code = vim.v.shell_error
  end

  if split_code ~= 0 or split_out == "" then
    return nil, string.format("herdr pane split failed (exit %d): %s", split_code, split_out)
  end

  local new_pane_id
  local ok, split_json = pcall(vim.json.decode, split_out)
  if ok and type(split_json) == "table" then
    if type(split_json.result) == "table" then
      local pane = split_json.result.pane
      new_pane_id = (type(pane) == "table" and pane.pane_id) or split_json.result.pane_id or split_json.result.id
    end
  end

  if not new_pane_id or new_pane_id == "" then
    return nil, "herdr pane split returned no pane_id: " .. split_out
  end

  -- Step 2: start agent in that pane; --timeout lets herdr wait for agent readiness
  local agent_name = target_agent .. "-ask-" .. tostring(math.random(1000, 9999))
  local timeout_sec = math.floor((opts.agent_start_timeout_ms or 30000) / 1000)
  local start_cmd = { "herdr", "agent", "start", agent_name, "--kind", target_agent, "--pane", new_pane_id, "--timeout", tostring(timeout_sec) }
  local start_out, start_code
  if vim.system then
    local res = vim.system(start_cmd):wait()
    start_out, start_code = res.stdout or "", res.code
  else
    start_out = vim.fn.system(start_cmd)
    start_code = vim.v.shell_error
  end

  if start_code ~= 0 then
    return nil, string.format("herdr agent start failed (exit %d): %s", start_code, start_out)
  end

  notify.info(string.format("Spawned '%s' agent pane '%s' for '%s'", agent_name, new_pane_id, target_agent), opts)
  return agent_name, nil, { pane_id = new_pane_id, agent_name = agent_name, spawned = true, is_popup = true }
end

function M.discover_target_pane(opts)
  opts = type(opts) == "table" and opts or {}
  if type(opts.pane_override) == "string" and opts.pane_override ~= "" then
    return opts.pane_override, nil, { pane_id = opts.pane_override, is_override = true }
  elseif type(opts.pane_override) == "number" then
    local override_str = tostring(opts.pane_override)
    return override_str, nil, { pane_id = override_str, is_override = true }
  end

  local env = M.detect_env(opts.runner)
  local workspace_id = opts.workspace_id or env.workspace_id
  local tab_id = opts.tab_id or env.tab_id
  local caller_pane_id = opts.caller_pane_id or env.pane_id
  if caller_pane_id == "" then
    caller_pane_id = nil
  end
  local current_cwd = opts.cwd or env.cwd or vim.fn.getcwd()
  local target_agent = (opts.agent_opts and (opts.agent_opts.harness or opts.agent_opts.agent)) or opts.target_agent or "agy"
  if type(target_agent) ~= "string" then
    return nil, "Invalid target_agent: must be a string"
  end

  if not opts.agents and not env.in_herdr and not opts.ignore_herdr_env then
    return nil, "Not running inside a Herdr environment (HERDR_ENV missing)"
  end

  local agents, err
  if opts.agents then
    agents = opts.agents
  else
    agents, err = M.list_agents(opts.runner)
  end

  if not agents then
    return nil, err or "Failed to retrieve agent list from Herdr"
  end

  local candidates = {}
  if type(agents) == "table" then
    for _, a in ipairs(agents) do
      if type(a) == "table" and type(a.agent) == "string" and a.agent == target_agent then
        if type(a.pane_id) == "string" and a.pane_id ~= "" then
          if (not a.workspace_id or a.workspace_id == "") and a.pane_id then
            a.workspace_id = a.pane_id:match("^([^:]+):")
          end
          table.insert(candidates, a)
        end
      end
    end
  end

  -- Tier 1: Same workspace + same tab, excluding caller pane
  if workspace_id and tab_id then
    for _, c in ipairs(candidates) do
      if c.workspace_id == workspace_id and c.tab_id == tab_id and c.pane_id ~= caller_pane_id then
        return c.pane_id, nil, c
      end
    end
  end

  -- Tier 2: Same workspace (any tab), excluding caller pane
  if workspace_id then
    for _, c in ipairs(candidates) do
      if c.workspace_id == workspace_id and c.pane_id ~= caller_pane_id then
        return c.pane_id, nil, c
      end
    end
  end

  -- Tier 3: Same workspace + same tab (any pane)
  if workspace_id and tab_id then
    for _, c in ipairs(candidates) do
      if c.workspace_id == workspace_id and c.tab_id == tab_id then
        return c.pane_id, nil, c
      end
    end
  end

  -- Tier 4: Same workspace (any pane)
  if workspace_id then
    for _, c in ipairs(candidates) do
      if c.workspace_id == workspace_id then
        return c.pane_id, nil, c
      end
    end
  end

  -- Tier 5: Working directory match (only within candidates)
  if current_cwd then
    for _, c in ipairs(candidates) do
      if c.cwd == current_cwd or c.foreground_cwd == current_cwd then
        return c.pane_id, nil, c
      end
    end
  end

  -- Tier 6: Auto-spawn pane if enabled (auto_spawn can be boolean true or string "right", "left", "bottom", "down", "top", "up")
  local allow_auto_spawn = (opts.auto_spawn == true)
    or (type(opts.auto_spawn) == "string" and opts.auto_spawn:lower() ~= "false" and opts.auto_spawn:lower() ~= "none" and opts.auto_spawn ~= "")

  if allow_auto_spawn and env.in_herdr and not _G.RUNNING_TEST_SUITE then
    local spawned_pane, spawn_err, spawn_meta = M.spawn_agent_pane(opts)
    if spawned_pane then
      return spawned_pane, nil, spawn_meta
    end
  end

  -- Tier 7: Strict error if no candidate found in current workspace/tab
  if #candidates == 0 then
    return nil, string.format("No active '%s' agent found in Herdr session", target_agent)
  end

  -- Tier 8: Fallback to first candidate only if auto_spawn disabled or impossible
  return candidates[1].pane_id, nil, candidates[1]
end

return M
