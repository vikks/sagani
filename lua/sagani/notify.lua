local M = {}

local level_map = {
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  warning = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

local function normalize_level(level)
  if type(level) == "number" then
    local str = "info"
    if level == vim.log.levels.WARN then
      str = "warn"
    elseif level == vim.log.levels.ERROR then
      str = "error"
    end
    return level, str
  end
  local str_level = tostring(level or "info"):lower()
  local num_level = level_map[str_level] or vim.log.levels.INFO
  local canon_str = (str_level == "warning" and "warn") or (level_map[str_level] and str_level) or "info"
  return num_level, canon_str
end

function M.notify(msg, level, opts)
  opts = type(opts) == "table" and opts or {}
  if opts.notify == false then
    return
  end
  if type(opts.notify) == "table" and opts.notify.enabled == false then
    return
  end

  -- Suppress all notifications during headless test suite runs to avoid
  -- polluting stdout with expected error/warn messages from tested code paths.
  -- Exception: opts.notify == true explicitly opts-in (used by tests that mock vim.notify).
  if _G.RUNNING_TEST_SUITE and opts.notify ~= true then
    return
  end

  local msg_str = type(msg) == "string" and msg or (type(msg) == "table" and vim.inspect(msg) or tostring(msg or ""))
  local num_level, str_level = normalize_level(level)
  local title = "sagani.nvim"
  if type(opts.notify) == "table" and opts.notify.title then
    title = tostring(opts.notify.title)
  elseif opts.title then
    title = tostring(opts.title)
  end

  -- Check for LazyVim notification utility
  local lazy_ok, LazyVim = pcall(require, "lazyvim.util")
  if lazy_ok and LazyVim and type(LazyVim[str_level]) == "function" then
    LazyVim[str_level](msg_str, { title = title })
    return
  end

  -- Fallback to standard Neovim vim.notify
  vim.notify(msg_str, num_level, { title = title })
end

function M.info(msg, opts)
  M.notify(msg, "info", opts)
end

function M.warn(msg, opts)
  M.notify(msg, "warn", opts)
end

function M.error(msg, opts)
  M.notify(msg, "error", opts)
end

return M
