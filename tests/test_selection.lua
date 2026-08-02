-- Headless Neovim Unit Test Suite for sagani.nvim visual selection module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local selection = require("sagani.selection")
local init = require("sagani")

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

  local function create_fixture_buf(lines, ft, file_path)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    if ft then
      vim.bo[buf].filetype = ft
    end
    if file_path then
      vim.api.nvim_buf_set_name(buf, file_path)
    end
    vim.api.nvim_set_current_buf(buf)
    return buf
  end

  local function set_visual_marks(buf, mode, start_line, start_col, end_line, end_col)
    vim.fn.setpos("'<", { buf, start_line, start_col, 0 })
    vim.fn.setpos("'>", { buf, end_line, end_col, 0 })
    rawset(vim.fn, "visualmode", function() return mode end)
  end

  local function enter_real_visual_mode(buf, mode_char, start_line, start_col, end_line, end_col)
    rawset(vim.fn, "visualmode", nil)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { start_line, math.max(0, start_col - 1) })
    if mode_char == "V" then
      vim.cmd("normal! V")
    elseif mode_char == "\22" or mode_char == "<C-v>" then
      vim.cmd('execute "normal! \\<C-v>"')
    else
      vim.cmd("normal! v")
    end
    vim.api.nvim_win_set_cursor(0, { end_line, math.max(0, end_col - 1) })
  end

  -- ==========================================================
  -- 1. VISUAL SELECTION EXTRACTION TESTS
  -- ==========================================================

  run_test("get_visual_selection: Real characterwise visual mode exit ('v')", function()
    local initial_lines = { "hello world", "foo bar" }
    local buf = create_fixture_buf(initial_lines, "python")
    enter_real_visual_mode(buf, "v", 1, 7, 1, 11)

    assert_eq(vim.fn.mode(), "v", "active mode is v before call")
    local sel = selection.get_visual_selection(buf)
    assert_eq(vim.fn.mode(), "n", "exits visual mode cleanly to normal mode ('n')")

    local after_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_eq(table.concat(after_lines, "\n"), table.concat(initial_lines, "\n"), "buffer text is preserved without deletion")
    assert_eq(sel.snippet, "world", "characterwise single line slice extracts 'world'")
  end)

  run_test("get_visual_selection: Real linewise visual mode exit ('V')", function()
    local initial_lines = { "line 1", "line 2", "line 3", "line 4" }
    local buf = create_fixture_buf(initial_lines, "lua", project_root .. "/real_test.lua")
    enter_real_visual_mode(buf, "V", 2, 1, 3, 6)

    assert_eq(vim.fn.mode(), "V", "active mode is V before call")
    local sel = selection.get_visual_selection(buf)
    assert_eq(vim.fn.mode(), "n", "exits visual mode cleanly to normal mode ('n')")

    local after_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_eq(table.concat(after_lines, "\n"), table.concat(initial_lines, "\n"), "buffer text is preserved without deletion")
    assert_eq(sel.snippet, "line 2\nline 3", "linewise snippet extracts full lines 2-3")
  end)

  run_test("get_visual_selection: Real blockwise visual mode exit ('\\22')", function()
    local initial_lines = { "ABCDEF", "GHIJKL", "MNOPQR" }
    local buf = create_fixture_buf(initial_lines, "text")
    enter_real_visual_mode(buf, "\22", 1, 2, 3, 4)

    assert_true(vim.fn.mode():find("[\22\x16]") ~= nil, "active mode is blockwise visual before call")
    local sel = selection.get_visual_selection(buf)
    assert_eq(vim.fn.mode(), "n", "exits visual mode cleanly to normal mode ('n')")

    local after_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert_eq(table.concat(after_lines, "\n"), table.concat(initial_lines, "\n"), "buffer text is preserved without deletion")
    assert_eq(sel.snippet, "BCD\nHIJ\nNOP", "blockwise rectangle extracts columns 2-4 across lines 1-3")
  end)

  run_test("get_visual_selection: Linewise visual selection ('V')", function()
    local buf = create_fixture_buf({ "line 1", "line 2", "line 3", "line 4" }, "lua", project_root .. "/test.lua")
    set_visual_marks(buf, "V", 2, 1, 3, 6)

    local sel = selection.get_visual_selection(buf)
    assert_eq(sel.mode, "V", "mode is V")
    assert_eq(sel.start_line, 2, "start_line is 2")
    assert_eq(sel.end_line, 3, "end_line is 3")
    assert_eq(sel.snippet, "line 2\nline 3", "linewise snippet extracts full lines 2-3")
    assert_eq(sel.filetype, "lua", "filetype matches lua")
    assert_true(sel.file_path:find("test.lua", 1, true) ~= nil, "file_path contains test.lua")
  end)

  run_test("get_visual_selection: Characterwise visual selection ('v') single line", function()
    local buf = create_fixture_buf({ "hello world", "foo bar" }, "python")
    set_visual_marks(buf, "v", 1, 7, 1, 11)

    local sel = selection.get_visual_selection(buf)
    assert_eq(sel.mode, "v", "mode is v")
    assert_eq(sel.snippet, "world", "characterwise single line slice extracts 'world'")
  end)

  run_test("get_visual_selection: Characterwise visual selection ('v') multi-line", function()
    local buf = create_fixture_buf({ "first line text", "second middle line", "third ending line" }, "javascript")
    set_visual_marks(buf, "v", 1, 7, 3, 5)

    local sel = selection.get_visual_selection(buf)
    local expected = "line text\nsecond middle line\nthird"
    assert_eq(sel.snippet, expected, "characterwise multi-line slices correctly")
  end)

  run_test("get_visual_selection: Blockwise visual selection ('\\22') rectangle", function()
    local buf = create_fixture_buf({ "ABCDEF", "GHIJKL", "MNOPQR" }, "text")
    set_visual_marks(buf, "\22", 1, 2, 3, 4)

    local sel = selection.get_visual_selection(buf)
    assert_eq(sel.snippet, "BCD\nHIJ\nNOP", "blockwise rectangle extracts columns 2-4 across lines 1-3")
  end)

  run_test("get_visual_selection: Boundary normalization (bottom-to-top selection)", function()
    local buf = create_fixture_buf({ "line 1", "line 2", "line 3", "line 4" }, "lua")
    -- Set end_line < start_line (selected bottom-to-top)
    set_visual_marks(buf, "V", 4, 1, 2, 1)

    local sel = selection.get_visual_selection(buf)
    assert_eq(sel.start_line, 2, "normalized start_line is 2")
    assert_eq(sel.end_line, 4, "normalized end_line is 4")
    assert_eq(sel.snippet, "line 2\nline 3\nline 4", "snippet extracts normalized range 2-4")
  end)

  run_test("get_visual_selection: Unnamed buffer handling ([No Name])", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unnamed buffer line" })
    vim.api.nvim_set_current_buf(buf)
    set_visual_marks(buf, "V", 1, 1, 1, 19)

    local sel = selection.get_visual_selection(buf)
    assert_eq(sel.file_path, "[No Name]", "unnamed buffer gets file_path [No Name]")
    assert_eq(sel.filetype, "text", "unnamed buffer gets default filetype text")
  end)

  -- ==========================================================
  -- 2. DISPATCH & INTERACTIVE PROMPT TESTS
  -- ==========================================================

  run_test("send_selection_prompt: Dispatches formatted payload when user inputs instruction", function()
    local abs_path = project_root .. "/lua/demo.lua"
    local buf = create_fixture_buf({ "function test()", "  return 42", "end" }, "lua", abs_path)
    set_visual_marks(buf, "V", 1, 1, 3, 3)

    -- Mock vim.ui.input
    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      assert_eq(opts.prompt, "AGY Instruction: ", "input prompt string")
      cb("Explain this function")
    end

    -- Mock dispatch_prompt
    local dispatched_text = nil
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function(text, target, opts)
      dispatched_text = text
      return true, nil
    end

    selection.send_selection_prompt({ notify = { enabled = false } })

    vim.ui.input = orig_input
    init.dispatch_prompt = orig_dispatch

    assert_true(dispatched_text ~= nil, "dispatch_prompt was called")
    assert_true(dispatched_text:find("Explain this function", 1, true) ~= nil, "payload contains user instruction")
    assert_true(dispatched_text:find("Context from `lua/demo.lua` (L1-L3):", 1, true) ~= nil, "payload contains metadata header")
  end)

  run_test("send_selection_prompt: Aborts dispatch when user cancels (nil or empty input)", function()
    local buf = create_fixture_buf({ "code line" }, "lua")
    set_visual_marks(buf, "V", 1, 1, 1, 9)

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      cb(nil) -- User pressed Esc
    end

    local dispatched = false
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function()
      dispatched = true
      return true, nil
    end

    selection.send_selection_prompt({ notify = { enabled = false } })

    vim.ui.input = orig_input
    init.dispatch_prompt = orig_dispatch

    assert_eq(dispatched, false, "no dispatch performed when user cancels")
  end)

  run_test("send_code_context: Sends code context directly with default prompt", function()
    local abs_path = project_root .. "/src/app.ts"
    local buf = create_fixture_buf({ "const x = 100;" }, "typescript", abs_path)
    set_visual_marks(buf, "V", 1, 1, 1, 15)

    local dispatched_text = nil
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function(text, target, opts)
      dispatched_text = text
      return true, nil
    end

    selection.send_code_context({ notify = { enabled = false } })

    init.dispatch_prompt = orig_dispatch

    assert_true(dispatched_text ~= nil, "dispatch_prompt was called")
    assert_true(dispatched_text:find("Context snippet for review:", 1, true) ~= nil, "payload contains default prompt")
    assert_true(dispatched_text:find("```typescript\nconst x = 100;\n```", 1, true) ~= nil, "payload contains code block")
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
  print(string.format("TEST RESULTS (test_selection): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
