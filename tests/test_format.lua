-- Headless Neovim Unit Test Suite for sagani.nvim format module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local format = require("sagani.format")

local M = {}

function M.run()
  local passed_count = 0
  local failed_count = 0
  local test_failures = {}

  local function assert_eq(actual, expected, test_name)
    if actual == expected then
      passed_count = passed_count + 1
      print(string.format("  ✓ PASS: %s", test_name))
    else
      failed_count = failed_count + 1
      local msg = string.format("  ✗ FAIL: %s (Expected: %s, Got: %s)", test_name, tostring(expected), tostring(actual))
      print(msg)
      table.insert(test_failures, msg)
    end
  end

  local function assert_true(cond, test_name)
    assert_eq(cond, true, test_name)
  end

  local function run_test(name, fn)
    print("\nRunning Test: " .. name)
    local ok, err = pcall(fn)
    if not ok then
      failed_count = failed_count + 1
      local msg = string.format("  ✗ EXCEPTION: %s error: %s", name, tostring(err))
      print(msg)
      table.insert(test_failures, msg)
    end
  end

  -- ==========================================================
  -- 1. BUILD_CONTEXT_PROMPT FORMATTING TESTS
  -- ==========================================================

  run_test("build_context_prompt: Single line selection formatting (L10)", function()
    local selection = {
      file_path = "lua/sagani/init.lua",
      start_line = 10,
      end_line = 10,
      filetype = "lua",
      snippet = "local M = {}",
    }
    local res = format.build_context_prompt("Explain this line", selection)
    local expected = "Explain this line\n\nContext from `lua/sagani/init.lua` (L10):\n```lua\nlocal M = {}\n```"
    assert_eq(res, expected, "single line selection output matches format")
  end)

  run_test("build_context_prompt: Multi-line selection formatting (L10-L25)", function()
    local selection = {
      file_path = "src/main.rs",
      start_line = 10,
      end_line = 25,
      filetype = "rust",
      snippet = "fn main() {\n    println!(\"Hello\");\n}",
    }
    local res = format.build_context_prompt("Refactor main", selection)
    local expected = "Refactor main\n\nContext from `src/main.rs` (L10-L25):\n```rust\nfn main() {\n    println!(\"Hello\");\n}\n```"
    assert_eq(res, expected, "multi-line selection output matches format")
  end)

  run_test("build_context_prompt: Unnamed buffer fallback ([No Name])", function()
    local selection = {
      file_path = "",
      start_line = 1,
      end_line = 5,
      filetype = "lua",
      snippet = "print('test')",
    }
    local res = format.build_context_prompt("Review code", selection)
    assert_true(res:find("Context from `[No Name]`", 1, true) ~= nil, "unnamed buffer uses [No Name]")
  end)

  run_test("build_context_prompt: Empty filetype fallback (text)", function()
    local selection = {
      file_path = "notes.txt",
      start_line = 1,
      end_line = 2,
      filetype = "",
      snippet = "some notes",
    }
    local res = format.build_context_prompt("Review text", selection)
    assert_true(res:find("```text\nsome notes\n```", 1, true) ~= nil, "empty filetype falls back to text")
  end)

  run_test("build_context_prompt: Special characters and backticks in snippet", function()
    local selection = {
      file_path = "test.sh",
      start_line = 5,
      end_line = 5,
      filetype = "bash",
      snippet = 'echo "$VAR" `date` `uname -a`',
    }
    local res = format.build_context_prompt("Check shell escaping", selection)
    assert_true(res:find('echo "$VAR" `date` `uname -a`', 1, true) ~= nil, "preserves backticks and quotes verbatim")
  end)

  run_test("build_context_prompt: Nil or empty user_instruction fallback", function()
    local selection = {
      file_path = "app.py",
      start_line = 3,
      end_line = 3,
      filetype = "python",
      snippet = "import os",
    }
    local res1 = format.build_context_prompt(nil, selection)
    assert_true(res1:sub(1, #"Context snippet for review:") == "Context snippet for review:", "nil user_instruction uses default prompt")

    local res2 = format.build_context_prompt("", selection)
    assert_true(res2:sub(1, #"Context snippet for review:") == "Context snippet for review:", "empty user_instruction uses default prompt")
  end)

  run_test("build_context_prompt: Nil selection table safety", function()
    local res = format.build_context_prompt("Hello", nil)
    assert_true(res:find("Context from `[No Name]` (L1):", 1, true) ~= nil, "handles nil selection safely")
  end)

  -- ==========================================================
  -- 2. BUILD_DIFF_PROMPT FORMATTING TESTS
  -- ==========================================================

  run_test("build_diff_prompt: Formats diff comment prompt correctly", function()
    local diff_info = {
      file_path = "lua/sagani/notify.lua",
      start_line = 12,
      end_line = 15,
      diff_text = "- old line\n+ new line",
    }
    local res = format.build_diff_prompt("Looks good", diff_info)
    local expected = "Looks good\n\nDiff Context from `lua/sagani/notify.lua` (L12-L15):\n```diff\n- old line\n+ new line\n```"
    assert_eq(res, expected, "build_diff_prompt matches format")
  end)

  run_test("build_diff_prompt: Single line diff and nil comment fallbacks", function()
    local diff_info = {
      file_path = "lua/sagani/notify.lua",
      start_line = 12,
      end_line = 12,
      diff_text = "+ single line addition",
    }
    local res = format.build_diff_prompt(nil, diff_info)
    local expected = "Diff review comment:\n\nDiff Context from `lua/sagani/notify.lua` (L12):\n```diff\n+ single line addition\n```"
    assert_eq(res, expected, "single line diff and default comment match format")
  end)

  return {
    passed = passed_count,
    failed = failed_count,
    failures = test_failures,
  }
end

if not _G.RUNNING_TEST_SUITE then
  local results = M.run()
  print("\n==========================================================")
  print(string.format("TEST RESULTS (test_format): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
