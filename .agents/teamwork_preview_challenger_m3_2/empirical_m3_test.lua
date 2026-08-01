-- Empirical Verification Test Harness for Milestone 3 (herdr-agy.nvim)
local project_root = "/Users/vikks/teamwork_projects/nvim_herdr_agy"
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local format = require("herdr-agy.format")
local selection = require("herdr-agy.selection")
local init = require("herdr-agy")

local passed = 0
local failed = 0
local failures = {}

local function assert_eq(actual, expected, name)
  if actual == expected then
    passed = passed + 1
    print("  ✓ PASS: " .. name)
  else
    failed = failed + 1
    local msg = string.format("  ✗ FAIL: %s (Expected: %q, Got: %q)", name, tostring(expected), tostring(actual))
    print(msg)
    table.insert(failures, msg)
  end
end

local function assert_contains(str, substr, name)
  if type(str) == "string" and str:find(substr, 1, true) ~= nil then
    passed = passed + 1
    print("  ✓ PASS: " .. name)
  else
    failed = failed + 1
    local msg = string.format("  ✗ FAIL: %s (Expected substring %q in %q)", name, tostring(substr), tostring(str))
    print(msg)
    table.insert(failures, msg)
  end
end

local function run_test(name, fn)
  print("\n>>> Testing: " .. name)
  local ok, err = pcall(fn)
  if not ok then
    failed = failed + 1
    local msg = string.format("  ✗ EXCEPTION: %s - %s", name, tostring(err))
    print(msg)
    table.insert(failures, msg)
  end
end

-- Setup plugin
init.setup({ notify = { enabled = false } })

-- ==========================================================
-- 1. MARKDOWN PROMPT PAYLOAD FORMATTING TESTS
-- ==========================================================
run_test("Payload: Standard context prompt layout", function()
  local sel = {
    file_path = "lua/herdr-agy/format.lua",
    start_line = 12,
    end_line = 18,
    filetype = "lua",
    snippet = "local M = {}\nreturn M",
  }
  local res = format.build_context_prompt("Please review this code", sel)
  local expected = "Please review this code\n\nContext from `lua/herdr-agy/format.lua` (L12-L18):\n```lua\nlocal M = {}\nreturn M\n```"
  assert_eq(res, expected, "exact markdown layout matches spec")
end)

run_test("Payload: Default user instruction when nil or empty", function()
  local sel = { file_path = "test.py", start_line = 5, end_line = 5, filetype = "python", snippet = "x = 1" }
  
  local res_nil = format.build_context_prompt(nil, sel)
  assert_contains(res_nil, "Context snippet for review:", "nil instruction uses default text")

  local res_empty = format.build_context_prompt("", sel)
  assert_contains(res_empty, "Context snippet for review:", "empty instruction uses default text")
end)

run_test("Payload: Default file_path fallback when nil or empty", function()
  local sel_nil = { file_path = nil, start_line = 1, end_line = 1, filetype = "lua", snippet = "code" }
  assert_contains(format.build_context_prompt("Check", sel_nil), "`[No Name]`", "nil file_path uses [No Name]")

  local sel_empty = { file_path = "", start_line = 1, end_line = 1, filetype = "lua", snippet = "code" }
  assert_contains(format.build_context_prompt("Check", sel_empty), "`[No Name]`", "empty file_path uses [No Name]")
end)

run_test("Payload: Diff prompt formatting and default comment", function()
  local diff_info = {
    file_path = "src/main.rs",
    start_line = 20,
    end_line = 25,
    diff_text = "- old_fn();\n+ new_fn();",
  }
  local res = format.build_diff_prompt(nil, diff_info)
  local expected = "Diff review comment:\n\nDiff Context from `src/main.rs` (L20-L25):\n```diff\n- old_fn();\n+ new_fn();\n```"
  assert_eq(res, expected, "diff prompt matches spec")
end)

-- ==========================================================
-- 2. LINE RANGE REPRESENTATION TESTS
-- ==========================================================
run_test("Line Range: Single line (L<start>)", function()
  local sel = { file_path = "foo.lua", start_line = 42, end_line = 42, filetype = "lua", snippet = "print(42)" }
  local res = format.build_context_prompt("Check", sel)
  assert_contains(res, "(L42):", "single line uses L42")
end)

run_test("Line Range: Multi-line (L<start>-L<end>)", function()
  local sel = { file_path = "foo.lua", start_line = 10, end_line = 50, filetype = "lua", snippet = "-- code" }
  local res = format.build_context_prompt("Check", sel)
  assert_contains(res, "(L10-L50):", "multi-line uses L10-L50")
end)

run_test("Line Range: Nil end_line defaults to start_line", function()
  local sel = { file_path = "foo.lua", start_line = 7, end_line = nil, filetype = "lua", snippet = "code" }
  local res = format.build_context_prompt("Check", sel)
  assert_contains(res, "(L7):", "missing end_line defaults to start_line (L7)")
end)

run_test("Line Range: Nil start_line defaults to 1", function()
  local sel = { file_path = "foo.lua", start_line = nil, end_line = nil, filetype = "lua", snippet = "code" }
  local res = format.build_context_prompt("Check", sel)
  assert_contains(res, "(L1):", "missing start_line defaults to 1")
end)

-- ==========================================================
-- 3. FILETYPE CODEBLOCK TESTS
-- ==========================================================
run_test("Filetype: Standard filetypes (lua, rust, python)", function()
  local sel1 = { file_path = "a.rs", start_line = 1, end_line = 1, filetype = "rust", snippet = "fn test() {}" }
  assert_contains(format.build_context_prompt("Check", sel1), "```rust\nfn test() {}\n```", "rust codeblock")

  local sel2 = { file_path = "b.py", start_line = 1, end_line = 1, filetype = "python", snippet = "def test(): pass" }
  assert_contains(format.build_context_prompt("Check", sel2), "```python\ndef test(): pass\n```", "python codeblock")
end)

run_test("Filetype: Empty or non-string filetype falls back to 'text'", function()
  local sel1 = { file_path = "a.txt", start_line = 1, end_line = 1, filetype = "", snippet = "hello" }
  assert_contains(format.build_context_prompt("Check", sel1), "```text\nhello\n```", "empty string filetype falls back to text")

  local sel2 = { file_path = "a.txt", start_line = 1, end_line = 1, filetype = nil, snippet = "hello" }
  assert_contains(format.build_context_prompt("Check", sel2), "```text\nhello\n```", "nil filetype falls back to text")
end)

run_test("Filetype: Code snippet with multi-line content and trailing whitespace", function()
  local snippet = "line 1  \n\nline 3\n"
  local sel = { file_path = "a.lua", start_line = 1, end_line = 4, filetype = "lua", snippet = snippet }
  local res = format.build_context_prompt("Check", sel)
  assert_contains(res, "```lua\n" .. snippet .. "\n```", "preserves exact snippet layout")
end)

-- ==========================================================
-- 4. VISUAL SELECTION & :HerdrAgySend INTEGRATION TESTS
-- ==========================================================
local function create_test_buf(lines, filetype, name)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if filetype then vim.bo[buf].filetype = filetype end
  if name then vim.api.nvim_buf_set_name(buf, name) end
  vim.api.nvim_set_current_buf(buf)
  return buf
end

local function set_marks(buf, mode, s_row, s_col, e_row, e_col)
  vim.fn.setpos("'<", { buf, s_row, s_col, 0 })
  vim.fn.setpos("'>", { buf, e_row, e_col, 0 })
  rawset(vim.fn, "visualmode", function() return mode end)
end

run_test("Selection: Characterwise single-line visual selection", function()
  local buf = create_test_buf({ "function add(a, b) return a + b end" }, "lua", project_root .. "/math.lua")
  set_marks(buf, "v", 1, 10, 1, 18) -- "add(a, b)"
  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "add(a, b)", "characterwise slice matches sub-string")
  assert_eq(sel.start_line, 1, "start_line is 1")
  assert_eq(sel.end_line, 1, "end_line is 1")
  assert_eq(sel.filetype, "lua", "filetype is lua")
end)

run_test("Selection: Linewise visual selection", function()
  local buf = create_test_buf({ "local a = 1", "local b = 2", "local c = 3" }, "lua", project_root .. "/vars.lua")
  set_marks(buf, "V", 1, 1, 2, 11)
  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "local a = 1\nlocal b = 2", "linewise snippet gets full lines 1 and 2")
  assert_eq(sel.start_line, 1, "start_line 1")
  assert_eq(sel.end_line, 2, "end_line 2")
end)

run_test("Selection: Blockwise visual selection", function()
  local buf = create_test_buf({ "12345", "67890", "ABCDE" }, "text", project_root .. "/block.txt")
  set_marks(buf, "\22", 1, 2, 3, 4)
  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.snippet, "234\n789\nBCD", "blockwise rectangle snippet correct")
end)

run_test("Selection: Boundary normalization (reversed selection)", function()
  local buf = create_test_buf({ "line 1", "line 2", "line 3" }, "lua", project_root .. "/rev.lua")
  set_marks(buf, "V", 3, 1, 1, 1) -- Bottom to top
  local sel = selection.get_visual_selection(buf)
  assert_eq(sel.start_line, 1, "start_line normalized to 1")
  assert_eq(sel.end_line, 3, "end_line normalized to 3")
end)

run_test(":HerdrAgySend integration with mock ui.input and dispatch", function()
  local buf = create_test_buf({ "const x = 42;" }, "typescript", project_root .. "/app.ts")
  set_marks(buf, "v", 1, 1, 1, 13)

  local original_input = vim.ui.input
  local original_dispatch = init.dispatch_prompt

  local input_prompt_received = nil
  vim.ui.input = function(opts, cb)
    input_prompt_received = opts.prompt
    cb("Refactor to let")
  end

  local dispatched_payload = nil
  init.dispatch_prompt = function(payload, target, opts)
    dispatched_payload = payload
    return true, nil
  end

  -- Execute command :HerdrAgySend
  local cmd_ok = pcall(vim.cmd, "HerdrAgySend")
  
  vim.ui.input = original_input
  init.dispatch_prompt = original_dispatch

  assert_eq(cmd_ok, true, ":HerdrAgySend command executed without error")
  assert_eq(input_prompt_received, "AGY Instruction: ", "ui.input received correct prompt option")
  assert_contains(dispatched_payload, "Refactor to let", "dispatched payload contains user instruction")
  assert_contains(dispatched_payload, "Context from `app.ts` (L1):", "dispatched payload contains relative path and line range L1")
  assert_contains(dispatched_payload, "```typescript\nconst x = 42;\n```", "dispatched payload contains typescript code block")
end)

run_test(":HerdrAgyContext integration with default prompt", function()
  local buf = create_test_buf({ "print('hello')" }, "lua", project_root .. "/hello.lua")
  set_marks(buf, "v", 1, 1, 1, 14)

  local original_dispatch = init.dispatch_prompt
  local dispatched_payload = nil
  init.dispatch_prompt = function(payload, target, opts)
    dispatched_payload = payload
    return true, nil
  end

  local cmd_ok = pcall(vim.cmd, "HerdrAgyContext")
  init.dispatch_prompt = original_dispatch

  assert_eq(cmd_ok, true, ":HerdrAgyContext command executed without error")
  assert_contains(dispatched_payload, "Context snippet for review:", "payload contains default context review prompt")
  assert_contains(dispatched_payload, "(L1):", "payload contains single line range L1")
end)

print("\n==========================================================")
print(string.format("EMPIRICAL TEST SUMMARY: %d Passed, %d Failed", passed, failed))
print("==========================================================")

if failed > 0 then
  for _, f in ipairs(failures) do
    print("FAILURE: " .. f)
  end
  vim.cmd("cquit 1")
else
  print("ALL EMPIRICAL TESTS PASSED SUCCESSFULLY!")
  vim.cmd("qall!")
end
