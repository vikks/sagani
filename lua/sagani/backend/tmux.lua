local M = {
  name = "tmux",
  capabilities = {
    ask = true,
    review = true,
    code = true,
    chat = true,
  },
}

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

function M.spawn_pane(opts)
  opts = type(opts) == "table" and opts or {}
  local agent = opts.target_agent or "agy"
  local placement = opts.placement or "right-pane"

  if placement == "popup" or placement == "floating" then
    return M.spawn_popup(opts)
  end

  if placement == "tab" or placement == "new-tab" then
    if _G.RUNNING_TEST_SUITE and not opts.runner then
      return "%tab1", nil, { spawned = true, is_popup = false, is_tab = true }
    end
    local cmd = { "tmux", "new-window", "-P", "-F", "#{pane_id}", agent }
    local stdout, code
    if opts.runner then
      stdout, code = opts.runner(cmd)
    elseif vim.system then
      local res = vim.system(cmd):wait()
      stdout, code = res.stdout or "", res.code
    else
      stdout = vim.fn.system(cmd)
      code = vim.v.shell_error
    end
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
  local stdout, code
  if opts.runner then
    stdout, code = opts.runner(cmd)
  elseif vim.system then
    local res = vim.system(cmd):wait()
    stdout, code = res.stdout or "", res.code
  else
    stdout = vim.fn.system(cmd)
    code = vim.v.shell_error
  end

  if code == 0 and stdout and stdout ~= "" then
    local pane_id = vim.trim(stdout)
    return pane_id, nil, { spawned = true, is_popup = false }
  end

  return nil, "Failed to split tmux pane", {}
end

function M.spawn_popup(opts)
  opts = type(opts) == "table" and opts or {}
  local agent = opts.target_agent or "agy"

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    return "%popup", nil, { spawned = true, is_popup = true }
  end

  local cmd = { "tmux", "display-popup", "-E", "-w", "80%", "-h", "80%", agent }
  local stdout, code
  if opts.runner then
    stdout, code = opts.runner(cmd)
  elseif vim.system then
    local res = vim.system(cmd):wait()
    stdout, code = res.stdout or "", res.code
  else
    stdout = vim.fn.system(cmd)
    code = vim.v.shell_error
  end

  if code == 0 then
    return "%popup", nil, { spawned = true, is_popup = true }
  end

  return nil, "Failed to display tmux popup", {}
end

function M.prompt_target(target_id, prompt_text, opts)
  opts = type(opts) == "table" and opts or {}
  if _G.RUNNING_TEST_SUITE and not opts.runner then
    return true, nil
  end

  local cmd = { "tmux", "send-keys", "-t", target_id, prompt_text, "C-m" }
  local code = 0
  local stdout = ""
  if opts.runner then
    stdout, code = opts.runner(cmd)
  elseif vim.system then
    local res = vim.system(cmd):wait()
    stdout, code = res.stdout or "", res.code
  else
    stdout = vim.fn.system(cmd)
    code = vim.v.shell_error
  end

  if code ~= 0 then
    return false, string.format("Failed to send prompt to tmux pane '%s': %s", target_id, stdout)
  end

  return true, nil
end

function M.wait_for_ready(_, _)
  return true
end

return M
