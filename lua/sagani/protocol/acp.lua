local notify = require("sagani.notify")

local M = {}

--- Formats command array for ACP request execution based on agent harness
--- @param harness string Agent harness name ("agy", "codex", "opencode", "hermes")
--- @param prompt_text string Prompt text
--- @param agent_opts table|nil Options (model, effort, provider)
--- @return table cmd Subprocess command array
function M.build_acp_command(harness, prompt_text, agent_opts)
  harness = (harness or "agy"):lower()
  agent_opts = type(agent_opts) == "table" and agent_opts or {}

  local cmd = {}
  if harness == "agy" or harness == "antigravity" then
    cmd = { "agy", "prompt", prompt_text, "--non-interactive" }
    if agent_opts.model then
      table.insert(cmd, "--model")
      table.insert(cmd, agent_opts.model)
    end
  elseif harness == "codex" then
    cmd = { "codex", "exec", prompt_text }
  elseif harness == "opencode" then
    cmd = { "opencode", "run", prompt_text }
  elseif harness == "hermes" then
    cmd = { "hermes", "prompt", prompt_text }
  else
    cmd = { harness, "prompt", prompt_text }
  end

  return cmd
end

--- Executes a prompt via ACP request-response subprocess asynchronously
--- @param harness string Agent harness name
--- @param prompt_text string Prompt text
--- @param agent_opts table Agent execution options
--- @param callback function Callback receiving (response_text, err)
--- @param opts table|nil Options (runner for tests)
function M.execute_prompt(harness, prompt_text, agent_opts, callback, opts)
  opts = type(opts) == "table" and opts or {}
  local cmd = M.build_acp_command(harness, prompt_text, agent_opts)
  local executable = cmd[1]

  if _G.RUNNING_TEST_SUITE and not opts.runner then
    local mock_resp = string.format("### Mock ACP Response (%s)\n\nHere is the answer to your prompt:\n```lua\nlocal x = 42\n```", harness:upper())
    callback(mock_resp, nil)
    return
  end

  if opts.runner then
    local out_text, code = opts.runner(cmd)
    if code == 0 then
      callback(out_text or "No output returned", nil)
    else
      callback(nil, string.format("ACP execution failed (code %d): %s", code, out_text or ""))
    end
    return
  end

  if vim.fn.executable(executable) == 0 then
    callback(nil, string.format("ACP executable '%s' not found in PATH", executable))
    return
  end

  if vim.system then
    vim.system(cmd, { text = true, stdin = "" }, function(obj)
      vim.schedule(function()
        if obj.code == 0 then
          local out = (obj.stdout and obj.stdout ~= "") and obj.stdout or (obj.stderr or "")
          callback(out, nil)
        else
          local err_msg = (obj.stderr and obj.stderr ~= "") and obj.stderr or obj.stdout or ("Exit code " .. tostring(obj.code))
          callback(nil, string.format("ACP request failed (%s): %s", executable, err_msg))
        end
      end)
    end)
  else
    local out = vim.fn.system(cmd)
    local code = vim.v.shell_error
    if code == 0 then
      callback(out, nil)
    else
      callback(nil, string.format("ACP request failed (%s): %s", executable, out))
    end
  end
end

return M
