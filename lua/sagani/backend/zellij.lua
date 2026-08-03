local M = {
  name = "zellij",
}

function M.detect_env(_)
  local zellij_env = vim.env.ZELLIJ
  local is_zellij = zellij_env ~= nil and zellij_env ~= ""
  local pane_id = vim.env.ZELLIJ_PANE_ID
  return {
    active = is_zellij,
    id = pane_id,
    metadata = { zellij = zellij_env, pane = pane_id },
  }
end

function M.discover_target(opts)
  opts = type(opts) == "table" and opts or {}
  if opts.pane_override then
    return tostring(opts.pane_override), nil, {}
  end
  local target = opts.backends and opts.backends.zellij and opts.backends.zellij.target_pane
  if target and target ~= "" then
    return target, nil, {}
  end
  return nil, "No target zellij pane configured (use opts.pane_override or opts.backends.zellij.target_pane)", {}
end

function M.spawn_pane(opts)
  opts = type(opts) == "table" and opts or {}
  local agent = opts.target_agent or "agy"
  local dir = "right"
  if opts.backends and opts.backends.zellij and opts.backends.zellij.direction then
    dir = opts.backends.zellij.direction
  end

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    return "z_pane_1", nil, { spawned = true, is_popup = false }
  end

  local cmd = { "zellij", "action", "new-pane", "-d", dir, "--", agent }
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
    return "z_pane_new", nil, { spawned = true, is_popup = false }
  end

  return nil, "Failed to spawn zellij pane", {}
end

function M.spawn_popup(opts)
  opts = type(opts) == "table" and opts or {}
  local agent = opts.target_agent or "agy"

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    return "z_floating_1", nil, { spawned = true, is_popup = true }
  end

  local cmd = { "zellij", "action", "new-pane", "-f", "--", agent }
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
    return "z_floating_new", nil, { spawned = true, is_popup = true }
  end

  return nil, "Failed to spawn zellij floating pane", {}
end

function M.prompt_target(target_id, prompt_text, opts)
  opts = type(opts) == "table" and opts or {}
  if _G.RUNNING_TEST_SUITE and not opts.runner then
    return true, nil
  end

  local cmd = { "zellij", "action", "write-chars", prompt_text .. "\n" }
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
    return false, string.format("Failed to send prompt to zellij pane '%s': %s", target_id, stdout)
  end

  return true, nil
end

return M
