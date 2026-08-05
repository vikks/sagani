local window = require("sagani.backend.native.window")

local M = {
  name = "native",
  capabilities = {
    ask = true,
    review = true,
    code = true,
    chat = true,
  },
}

function M.detect_env(runner)
  return window.detect_env(runner)
end

function M.discover_target(opts)
  return window.discover_target(opts)
end

function M.spawn_pane(opts)
  return window.spawn_pane(opts)
end

function M.spawn_popup(opts)
  return window.spawn_popup(opts)
end

function M.prompt_target(target_id, prompt_text, opts)
  return window.prompt_target(target_id, prompt_text, opts)
end

function M.wait_for_ready(target_id, opts)
  return window.wait_for_ready(target_id, opts)
end

function M.reset_popup(agent)
  return window.reset_popup(agent)
end

return M
