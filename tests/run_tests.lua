-- Master Headless Test Runner for sagani.nvim
-- Target modules: sagani.backend.herdr.topology, sagani.selection, sagani.diff, sagani.format, sagani.init
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. project_root .. "/?.lua;" .. package.path

_G.RUNNING_TEST_SUITE = true

-- Fallback mock for vim.ui.input in headless test runs
if not _G._orig_vim_ui_input then
  _G._orig_vim_ui_input = vim.ui.input
end
vim.ui.input = function(opts, cb)
  if type(cb) == "function" then
    cb(opts and opts.default or "test fallback input")
  end
end


print("==========================================================")
print("  sagani.nvim Master Test Runner")
print("==========================================================")

local tests_dir = project_root .. "/tests"
local test_files = vim.fn.globpath(tests_dir, "test_*.lua", false, true)

if type(test_files) == "string" then
  test_files = { test_files }
end

table.sort(test_files)

if #test_files == 0 then
  print("ERROR: No test files matching 'test_*.lua' found in " .. tests_dir)
  vim.cmd("cquit 1")
end

local total_passed = 0
local total_failed = 0
local all_failures = {}

for _, file_path in ipairs(test_files) do
  local filename = vim.fn.fnamemodify(file_path, ":t")
  print("\n>>> Executing Test Suite: " .. filename)

  local sagani_init = require("sagani")
  sagani_init._session_agent = nil
  sagani_init._session_harness = nil
  sagani_init._session_model = nil
  sagani_init._session_effort = nil
  sagani_init._session_backend = nil
  sagani_init._session_mode = nil

  local mod = dofile(file_path)
  local results = nil
  if type(mod) == "table" and type(mod.run) == "function" then
    results = mod.run()
  elseif type(mod) == "function" then
    results = mod()
  end

  if results then
    total_passed = total_passed + (results.passed or 0)
    total_failed = total_failed + (results.failed or 0)
    if results.failures then
      for _, f in ipairs(results.failures) do
        table.insert(all_failures, string.format("[%s] %s", filename, f))
      end
    end
  end
end

print("\n==========================================================")
print(string.format("TOTAL TEST RESULTS: %d Passed, %d Failed across %d test file(s)", total_passed, total_failed, #test_files))
print("==========================================================")

if total_failed > 0 then
  print("\nSummary of Failures:")
  for _, failure in ipairs(all_failures) do
    print("  " .. failure)
  end
  vim.cmd("cquit 1")
else
  print("\nAll test suites passed successfully!")
  vim.cmd("qall!")
end
