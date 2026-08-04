local M = {
  _mem_cache = {},
  _cache_dir = nil,
  _cache_file = nil,
}

--- Returns the path to the persistent cache JSON file
--- @return string path
function M.get_cache_file()
  if M._cache_file then
    return M._cache_file
  end
  local state_dir = vim.fn.stdpath and vim.fn.stdpath("state") or "/tmp"
  M._cache_dir = state_dir .. "/sagani"
  M._cache_file = M._cache_dir .. "/models.json"
  return M._cache_file
end

--- Loads disk cache into memory
--- @return table cache
function M.load_disk_cache()
  if next(M._mem_cache) then
    return M._mem_cache
  end

  if _G.RUNNING_TEST_SUITE then
    return M._mem_cache
  end

  local file = M.get_cache_file()
  if vim.fn.filereadable(file) == 1 then
    local content = table.concat(vim.fn.readfile(file), "\n")
    if content and content ~= "" then
      local ok, data = pcall(vim.json.decode, content)
      if ok and type(data) == "table" then
        M._mem_cache = data
        return M._mem_cache
      end
    end
  end

  return M._mem_cache
end

--- Saves memory cache to persistent disk file
function M.save_disk_cache()
  if _G.RUNNING_TEST_SUITE then
    return
  end

  local file = M.get_cache_file()
  local dir = M._cache_dir
  if dir and vim.fn.isdirectory(dir) == 0 then
    pcall(vim.fn.mkdir, dir, "p")
  end

  local ok, json_str = pcall(vim.json.encode, M._mem_cache)
  if ok and json_str then
    pcall(vim.fn.writefile, { json_str }, file)
  end
end

--- Retrieves cached models for a harness if fresh (age < ttl_seconds)
--- @param harness string Agent harness
--- @param ttl_seconds number|nil TTL in seconds (default 86400 / 24 hours)
--- @return table|nil models
function M.get_cached_models(harness, ttl_seconds)
  harness = (harness or ""):lower()
  ttl_seconds = ttl_seconds or 86400

  local cache = M.load_disk_cache()
  local entry = cache[harness]
  if entry and type(entry) == "table" and type(entry.models) == "table" and #entry.models > 0 then
    local ts = entry.timestamp or 0
    local now = os.time()
    if (now - ts) < ttl_seconds then
      return entry.models
    end
  end

  return nil
end

--- Saves dynamic models for a harness into memory & disk cache
--- @param harness string Agent harness
--- @param models table Models array
function M.set_cached_models(harness, models)
  if type(models) ~= "table" or #models == 0 then
    return
  end
  harness = (harness or ""):lower()

  M._mem_cache[harness] = {
    timestamp = os.time(),
    models = models,
  }
  M.save_disk_cache()
end

--- Clears memory and persistent disk model cache
function M.clear_cache()
  M._mem_cache = {}
  local file = M.get_cache_file()
  if vim.fn.filereadable(file) == 1 then
    pcall(vim.fn.delete, file)
  end
end

return M
