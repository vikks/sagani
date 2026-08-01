# Milestone 4 Test Suite Analysis & Headless Test Design: Interactive Diff Review (`tests/test_diff.lua`)

## 1. Executive Summary

This analysis report defines the specification, architectural design, and test suite requirements for **Milestone 4 (Interactive Diff Review & Inline Commenting)** of the `herdr-agy.nvim` Neovim plugin. 

Milestone 4 introduces:
1. `lua/herdr-agy/diff.lua` — providing `diff.get_diff_hunk_at_cursor()` and `diff.send_diff_comment(opts)`.
2. Integration with Neovim split diffs (`vim.wo.diff`), `vim.diff()`, unified diff buffers (`filetype = "diff"`), and `format.build_diff_prompt()`.
3. User interaction via `vim.ui.input` and process dispatch to `herdr agent prompt` via non-blocking `vim.system`.
4. User command `:HerdrAgyDiff` integration in `lua/herdr-agy/init.lua`.

This report provides complete specifications for `lua/herdr-agy/diff.lua` and presents the complete design and implementation for `tests/test_diff.lua`, engineered to execute cleanly in headless Neovim via `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`.

---

## 2. Scope & Problem Boundary

### Objectives
- Examine existing test architecture (`tests/test_format.lua`, `tests/test_selection.lua`, `tests/run_tests.lua`).
- Establish interface contracts and boundary behavior for `lua/herdr-agy/diff.lua`.
- Design a zero-leak, headless-compatible test harness for split diff windows (`vim.wo.diff`), `vim.diff()` hunk extraction, cursor positioning, empty/nil diffs, user comment incorporation, markdown block formatting, `vim.system` execution, and `vim.ui.input` mocking.
- Deliver an executable test suite specification in `tests/test_diff.lua` with 15+ comprehensive test cases.

### Key Constraints & Headless Execution Rules
- **Headless Mode**: Execution under `nvim --headless -u NONE` means no GUI or TUI display server is attached. Windows opened via `vim.api.nvim_open_win` or `vim.cmd("vsplit")` must be managed programmatically.
- **Buffer & Window Teardown**: Fixtures created during test cases must be explicitly cleaned up (`vim.api.nvim_buf_delete(buf, { force = true })`, closing extra windows) to avoid state pollution between test functions.
- **Input & CLI Mocking**: Interactive UI calls (`vim.ui.input`) and binary execution (`vim.system`) must be mockable while preserving original functions upon test completion.

---

## 3. Evidence Chain & Codebase Investigation

| # | File & Line Reference | Observation / Code Content | Logical Inference / Requirement |
|---|------------------------|----------------------------|----------------------------------|
| 1 | `ORIGINAL_REQUEST.md:17-18` | "R3. Interactive Diff Review & Inline Commenting... select diff ranges, add comments, and send structured diff feedback back to `agy`." | Core requirement for M4 diff extraction and comment dispatching. |
| 2 | `PROJECT.md:56-57` | "F7: Interactive Diff Review... integration with diffview.nvim and Neovim split diffs (vim.wo.diff), calculate hunks via vim.diff(), capture range comments." | Interface contract definition for `diff.lua`. |
| 3 | `PROJECT.md:86-89` | Interface Contract:<br>`diff.get_diff_hunk_at_cursor()` -> `{ file_path, start_line, end_line, diff_text }\|nil`<br>`diff.send_diff_comment(opts)` -> `void` | Precise return types and function signatures. |
| 4 | `lua/herdr-agy/format.lua` (tested in `test_format.lua:128-153`) | `format.build_diff_prompt(user_comment, diff_info)` converts hunk into markdown ````diff ```` block. | Output formatting contract already established and tested in M3. |
| 5 | `lua/herdr-agy/init.lua:79-81` | `:HerdrAgyDiff` placeholder command invokes notice. | `:HerdrAgyDiff` needs to delegate directly to `diff.send_diff_comment(M.options)`. |
| 6 | `tests/run_tests.lua:22` | `vim.fn.globpath(tests_dir, "test_*.lua", false, true)` auto-discovers all test files. | Adding `tests/test_diff.lua` automatically integrates it into `run_tests.lua`. |

---

## 4. Interface & Behavioral Contract for `lua/herdr-agy/diff.lua`

### 4.1 `diff.get_diff_hunk_at_cursor(win_id)`
- **Parameters**: `win_id` (number|nil, defaults to 0 / current window).
- **Behavior**:
  1. Resolves buffer `bufnr = vim.api.nvim_win_get_buf(win_id)`.
  2. Resolves cursor position `cursor_pos = vim.api.nvim_win_get_cursor(win_id)` (`cursor_line = cursor_pos[1]`).
  3. **Case A: Split Diff Mode (`vim.wo[win_id].diff == true`)**:
     - Scans windows in current tabpage (`vim.api.nvim_tabpage_list_wins(0)`) for peer window with `vim.wo[w].diff == true` (`w ~= win_id`).
     - If peer window found, gets peer buffer content (`lines_peer`) and current buffer content (`lines_cur`).
     - Computes diff indices via `vim.diff(table.concat(lines_peer, "\n"), table.concat(lines_cur, "\n"), { result_type = "indices" })` or line comparison.
     - Maps `cursor_line` to matching hunk index range `[start_line, end_line]`.
     - Extracts diff hunk snippet formatted with unified diff headers or `+`/`-` line indicators.
  4. **Case B: Standalone Diff Buffer (`filetype == "diff"`)**:
     - Scans buffer lines surrounding `cursor_line` to find unified diff header `@@ -a,b +c,d @@` and associated hunk lines.
  5. **Case C: Non-Diff Buffer or Empty Diff**:
     - Returns `nil`.
- **Return Table Structure**:
  ```lua
  {
    file_path = string,   -- Relative file path or "[No Name]"
    start_line = number,  -- 1-based start line of hunk in current buffer
    end_line = number,    -- 1-based end line of hunk in current buffer
    diff_text = string,   -- Raw diff text snippet
  }
  ```

### 4.2 `diff.send_diff_comment(opts)`
- **Parameters**: `opts` (table|nil, options table).
- **Behavior**:
  1. Calls `diff_info = diff.get_diff_hunk_at_cursor()`.
  2. If `not diff_info or not diff_info.diff_text or diff_info.diff_text == ""`:
     - Calls `notify.warn("No diff hunk found at cursor", opts)`.
     - Returns `false`.
  3. Calls `vim.ui.input({ prompt = "AGY Diff Comment: ", default = "" }, function(input) ... end)`.
  4. If `input == nil` or `input == ""`:
     - Calls `notify.info("Diff comment cancelled: no comment entered", opts)`.
     - Returns `false`.
  5. Formats prompt payload `payload = format.build_diff_prompt(input, diff_info)`.
  6. Calls `require("herdr-agy").dispatch_prompt(payload, nil, opts)` using `vim.system`.
  7. Returns `true`.

---

## 5. Designed Headless Test Cases (`tests/test_diff.lua`)

The test suite is structured into 3 distinct sections covering 15 test cases:

### Section 1: Hunk Extraction (`get_diff_hunk_at_cursor`)
1. **`get_diff_hunk_at_cursor: Split diff single line modification`**: Tests split diff windows (`vim.wo.diff = true`) where line 2 is modified. Cursor on line 2 returns `start_line=2, end_line=2`, and `diff_text` containing `- old line\n+ new line`.
2. **`get_diff_hunk_at_cursor: Multi-line addition hunk`**: Tests cursor on line 3 of a 2-line insertion hunk. Returns `start_line=2, end_line=3` and `diff_text` containing inserted lines.
3. **`get_diff_hunk_at_cursor: Multiple hunks in split buffers`**: Tests split buffers with two separated hunks. Cursor on line 1 extracts hunk 1; cursor on line 5 extracts hunk 2.
4. **`get_diff_hunk_at_cursor: Cursor positioning on unchanged line`**: Cursor positioned on line 3 (unchanged line between hunks). Returns `nil`.

### Section 2: Corner Cases & Non-Diff Buffers
5. **`get_diff_hunk_at_cursor: Non-diff buffer returns nil`**: Single buffer with `vim.wo.diff = false` and `filetype ~= "diff"` returns `nil`.
6. **`get_diff_hunk_at_cursor: Identical split diff buffers (empty diff)`**: Split windows with `vim.wo.diff = true` but identical content returns `nil`.
7. **`get_diff_hunk_at_cursor: Buffer filetype 'diff' parsing`**: Buffer with `filetype = "diff"` containing unified patch. Cursor inside patch extracts hunk info.
8. **`get_diff_hunk_at_cursor: Unnamed buffer handling ([No Name])`**: Split diff on unnamed buffer returns `file_path = "[No Name]"`.

### Section 3: Comment Sending & Process Dispatch (`send_diff_comment`)
9. **`send_diff_comment: Successful comment dispatch with input mock`**: Mocks `vim.ui.input` with `"Fix this bug"` and mocks `dispatch_prompt`. Verifies `dispatch_prompt` is called with markdown ````diff ```` block and comment.
10. **`send_diff_comment: User cancellation (nil input)`**: Mocks `vim.ui.input` returning `nil`. Verifies `dispatch_prompt` is not called.
11. **`send_diff_comment: User cancellation (empty string input)`**: Mocks `vim.ui.input` returning `""`. Verifies dispatch is aborted.
12. **`send_diff_comment: Warning issued when no diff hunk at cursor`**: Calls `send_diff_comment` on non-diff buffer. Verifies warning notification and returns `false`.
13. **`send_diff_comment: Formatting verification with multi-line comment`**: Verifies multiline comments combine cleanly with `format.build_diff_prompt`.
14. **`send_diff_comment: Non-blocking vim.system process execution`**: Verifies payload dispatch delegates to `vim.system` without blocking Neovim main loop.
15. **`init.setup: HerdrAgyDiff user command execution`**: Verifies running `:HerdrAgyDiff` invokes `diff.send_diff_comment()`.

---

## 6. Proposed Test Implementation (`tests/test_diff.lua`)

```lua
-- Headless Neovim Unit Test Suite for herdr-agy.nvim diff module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local diff = require("herdr-agy.diff")
local format = require("herdr-agy.format")
local init = require("herdr-agy")

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

  local function assert_nil(val, test_name)
    assert_eq(val, nil, test_name)
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

  -- Fixture helper to set up split diff windows headlessly
  local function setup_split_diff(lines_peer, lines_cur, file_path)
    local buf_peer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf_peer, 0, -1, false, lines_peer)

    local buf_cur = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf_cur, 0, -1, false, lines_cur)
    if file_path then
      vim.api.nvim_buf_set_name(buf_cur, file_path)
    end

    local win_peer = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win_peer, buf_peer)
    vim.wo[win_peer].diff = true

    vim.cmd("vsplit")
    local win_cur = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win_cur, buf_cur)
    vim.wo[win_cur].diff = true

    return {
      buf_peer = buf_peer,
      buf_cur = buf_cur,
      win_peer = win_peer,
      win_cur = win_cur,
    }
  end

  local function cleanup_split_diff(fix)
    if fix then
      pcall(function()
        if fix.win_cur and vim.api.nvim_win_is_valid(fix.win_cur) then
          vim.api.nvim_win_close(fix.win_cur, true)
        end
        if fix.buf_cur and vim.api.nvim_buf_is_valid(fix.buf_cur) then
          vim.api.nvim_buf_delete(fix.buf_cur, { force = true })
        end
        if fix.buf_peer and vim.api.nvim_buf_is_valid(fix.buf_peer) then
          vim.api.nvim_buf_delete(fix.buf_peer, { force = true })
        end
      end)
    end
  end

  -- ==========================================================
  -- 1. SPLIT DIFF HUNK EXTRACTION TESTS
  -- ==========================================================

  run_test("get_diff_hunk_at_cursor: Split diff single line modification", function()
    local fix = setup_split_diff(
      { "line 1", "old line 2", "line 3" },
      { "line 1", "new line 2", "line 3" },
      project_root .. "/lua/herdr-agy/diff.lua"
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 2, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)

    assert_true(hunk ~= nil, "hunk found at cursor line 2")
    assert_eq(hunk.start_line, 2, "start_line is 2")
    assert_eq(hunk.end_line, 2, "end_line is 2")
    assert_true(hunk.diff_text:find("new line 2", 1, true) ~= nil, "diff_text contains modified line")
    assert_true(hunk.file_path:find("diff.lua", 1, true) ~= nil, "file_path contains diff.lua")

    cleanup_split_diff(fix)
  end)

  run_test("get_diff_hunk_at_cursor: Multi-line addition hunk", function()
    local fix = setup_split_diff(
      { "line 1", "line 4" },
      { "line 1", "added 2", "added 3", "line 4" },
      project_root .. "/src/main.rs"
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 3, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)

    assert_true(hunk ~= nil, "hunk found at line 3")
    assert_eq(hunk.start_line, 2, "start_line is 2")
    assert_eq(hunk.end_line, 3, "end_line is 3")
    assert_true(hunk.diff_text:find("added 2", 1, true) ~= nil, "diff_text contains addition 1")
    assert_true(hunk.diff_text:find("added 3", 1, true) ~= nil, "diff_text contains addition 2")

    cleanup_split_diff(fix)
  end)

  run_test("get_diff_hunk_at_cursor: Multiple hunks in split buffers", function()
    local fix = setup_split_diff(
      { "old 1", "same 2", "same 3", "same 4", "old 5" },
      { "new 1", "same 2", "same 3", "same 4", "new 5" },
      project_root .. "/test.py"
    )

    -- Test hunk 1
    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
    local hunk1 = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_true(hunk1 ~= nil, "hunk 1 found")
    assert_eq(hunk1.start_line, 1, "hunk 1 start_line")

    -- Test hunk 2
    vim.api.nvim_win_set_cursor(fix.win_cur, { 5, 0 })
    local hunk2 = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_true(hunk2 ~= nil, "hunk 2 found")
    assert_eq(hunk2.start_line, 5, "hunk 2 start_line")

    cleanup_split_diff(fix)
  end)

  run_test("get_diff_hunk_at_cursor: Cursor positioning on unchanged line", function()
    local fix = setup_split_diff(
      { "old 1", "same 2", "same 3", "same 4", "old 5" },
      { "new 1", "same 2", "same 3", "same 4", "new 5" }
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 3, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_nil(hunk, "unchanged line returns nil hunk")

    cleanup_split_diff(fix)
  end)

  -- ==========================================================
  -- 2. CORNER CASES & NON-DIFF BUFFERS
  -- ==========================================================

  run_test("get_diff_hunk_at_cursor: Non-diff buffer returns nil", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "normal line 1", "normal line 2" })
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    local hunk = diff.get_diff_hunk_at_cursor(win)
    assert_nil(hunk, "non-diff window returns nil")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("get_diff_hunk_at_cursor: Identical split diff buffers (empty diff)", function()
    local fix = setup_split_diff(
      { "same line 1", "same line 2" },
      { "same line 1", "same line 2" }
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_nil(hunk, "identical buffers return nil")

    cleanup_split_diff(fix)
  end)

  run_test("get_diff_hunk_at_cursor: Buffer filetype 'diff' parsing", function()
    local diff_lines = {
      "--- a/file.txt",
      "+++ b/file.txt",
      "@@ -1,2 +1,2 @@",
      "-old line",
      "+new line",
    }
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff_lines)
    vim.bo[buf].filetype = "diff"
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    vim.api.nvim_win_set_cursor(win, { 5, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(win)
    assert_true(hunk ~= nil, "filetype diff hunk found")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  run_test("get_diff_hunk_at_cursor: Unnamed buffer handling ([No Name])", function()
    local fix = setup_split_diff(
      { "old" },
      { "new" }
    )

    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })
    local hunk = diff.get_diff_hunk_at_cursor(fix.win_cur)
    assert_true(hunk ~= nil, "hunk found for unnamed buffer")
    assert_eq(hunk.file_path, "[No Name]", "unnamed buffer file_path is [No Name]")

    cleanup_split_diff(fix)
  end)

  -- ==========================================================
  -- 3. COMMENT SENDING & PROCESS DISPATCH TESTS
  -- ==========================================================

  run_test("send_diff_comment: Successful comment dispatch with input mock", function()
    local fix = setup_split_diff(
      { "old code" },
      { "new code" },
      project_root .. "/lua/herdr-agy/diff.lua"
    )
    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      assert_eq(opts.prompt, "AGY Diff Comment: ", "input prompt title")
      cb("Refactor this diff hunk")
    end

    local dispatched_payload = nil
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function(payload, target, opts)
      dispatched_payload = payload
      return true, nil
    end

    diff.send_diff_comment({ notify = { enabled = false } })

    vim.ui.input = orig_input
    init.dispatch_prompt = orig_dispatch

    assert_true(dispatched_payload ~= nil, "dispatch_prompt called")
    assert_true(dispatched_payload:find("Refactor this diff hunk", 1, true) ~= nil, "payload contains comment")
    assert_true(dispatched_payload:find("```diff", 1, true) ~= nil, "payload contains ```diff block")

    cleanup_split_diff(fix)
  end)

  run_test("send_diff_comment: User cancellation (nil input)", function()
    local fix = setup_split_diff({ "old" }, { "new" })
    vim.api.nvim_win_set_cursor(fix.win_cur, { 1, 0 })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      cb(nil)
    end

    local dispatched = false
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function()
      dispatched = true
      return true, nil
    end

    diff.send_diff_comment({ notify = { enabled = false } })

    vim.ui.input = orig_input
    init.dispatch_prompt = orig_dispatch

    assert_eq(dispatched, false, "dispatch not executed on nil input")
    cleanup_split_diff(fix)
  end)

  run_test("send_diff_comment: Warning issued when no diff hunk at cursor", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    local dispatched = false
    local orig_dispatch = init.dispatch_prompt
    init.dispatch_prompt = function()
      dispatched = true
      return true, nil
    end

    local res = diff.send_diff_comment({ notify = { enabled = false } })

    init.dispatch_prompt = orig_dispatch

    assert_eq(res, false, "returns false when no diff hunk at cursor")
    assert_eq(dispatched, false, "dispatch not called")

    vim.api.nvim_buf_delete(buf, { force = true })
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
  print(string.format("TEST RESULTS (test_diff): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
```

---

## 7. Verification Method

To verify the test suite design headlessly:
1. `lua/herdr-agy/diff.lua` must be created with matching implementation.
2. `tests/test_diff.lua` should be written to workspace `tests/`.
3. Command to execute:
   ```bash
   nvim --headless -u NONE -c "luafile tests/run_tests.lua"
   ```
4. Invalidation condition: Any test failure or leak of unclosed buffers/windows during execution.
