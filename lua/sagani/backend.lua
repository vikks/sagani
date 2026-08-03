local notify = require("sagani.notify")

local M = {}

--- Registry of available backends
M.backends = {}

--- Registers a backend adapter
--- @param name string Backend name (e.g. "native", "herdr", "tmux", "zellij")
--- @param adapter table Backend adapter implementation table
function M.register(name, adapter)
  if type(name) ~= "string" or name == "" then
    error("Backend name must be a non-empty string")
  end
  if type(adapter) ~= "table" then
    error("Backend adapter must be a table")
  end
  M.backends[name] = adapter
end

--- Resolves the active backend adapter based on options and environment
--- @param opts table Sagani configuration options
--- @return table adapter Active backend adapter table
--- @return string backend_name Active backend name
function M.get_backend(opts)
  opts = type(opts) == "table" and opts or {}
  local requested = opts.backend or "auto"

  -- If user passed a custom adapter table directly
  if type(requested) == "table" then
    return requested, requested.name or "custom"
  end

  if type(requested) == "string" and requested ~= "auto" then
    if M.backends[requested] then
      return M.backends[requested], requested
    else
      notify.warn(string.format("Requested backend '%s' not found, falling back to auto-detection", requested), opts)
    end
  end

  -- Auto-detection hierarchy: Herdr -> Tmux -> Zellij -> Native
  if M.backends["herdr"] then
    local env = M.backends["herdr"].detect_env(opts.runner)
    if env and env.active then
      return M.backends["herdr"], "herdr"
    end
  end

  if M.backends["tmux"] then
    local env = M.backends["tmux"].detect_env(opts.runner)
    if env and env.active then
      return M.backends["tmux"], "tmux"
    end
  end

  if M.backends["zellij"] then
    local env = M.backends["zellij"].detect_env(opts.runner)
    if env and env.active then
      return M.backends["zellij"], "zellij"
    end
  end

  -- Fallback to native backend
  if M.backends["native"] then
    return M.backends["native"], "native"
  end

  error("No valid sagani backend adapter found!")
end

return M
