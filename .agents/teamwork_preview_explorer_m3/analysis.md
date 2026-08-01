# Technical Analysis & Implementation Blueprint: Milestone 3 (Visual Selection & Context Dispatch to AGY)

**Author:** Explorer M3  
**Target Repository:** `herdr-agy.nvim`  
**Date:** 2026-08-01  
**Status:** Complete Analysis & Implementation Blueprint  

---

## 1. Executive Summary

Milestone 3 implements Requirement R2 of `herdr-agy.nvim`: Visual Selection & Context Dispatch to AGY. This capability allows Neovim users to visually select code blocks in any buffer and seamlessly dispatch the code context—along with relative file paths, 1-indexed line ranges, filetype syntax tags, and user instructions—directly to an adjacent `agy` agent running in a `herdr` terminal multiplexer pane.

This report provides complete, production-ready Lua implementation code blueprints and comprehensive headless test suites for:
1. `lua/herdr-agy/format.lua`: Context prompt formatter transforming user instructions and visual selection metadata into structured Markdown payloads.
2. `lua/herdr-agy/selection.lua`: Neovim visual selection extraction handling characterwise (`v`), linewise (`V`), and blockwise (`<C-v>`) visual modes with position mark synchronization (`'<` and `'>`), boundary normalization, non-blocking asynchronous user interaction (`vim.ui.input`), and dispatch integration.
3. `lua/herdr-agy/init.lua`: Command routing updates directing `:HerdrAgySend` to `selection.send_selection_prompt()`.
4. `tests/test_format.lua` & `tests/test_selection.lua`: Unit test suites compatible with the master headless test runner (`tests/run_tests.lua`).

---

## 2. Architecture & Design Blueprint

### 2.1 Component Interaction Flow

```
 +-----------------------------------------------------------------------------------+
 | Neovim Visual Mode Selection                                                      |
 | User presses <leader>at or runs :HerdrAgySend / :HerdrAgyContext                  |
 +-----------------------------------------+-----------------------------------------+
                                           |
                                           v
 +-----------------------------------------------------------------------------------+
 | lua/herdr-agy/selection.lua                                                       |
 | 1. Exits visual mode cleanly (noau normal! \x1b) to update '< and '> marks        |
 | 2. Reads visual mode (v, V, \22) via vim.fn.visualmode()                          |
 | 3. Queries start/end positions (getpos("'<"), getpos("'>"))                       |
 | 4. Normalizes boundaries (bottom-to-top & right-to-left selection handling)       |
 | 5. Slices buffer text for characterwise, linewise, or blockwise visual rect      |
 | 6. Extracts relative file path (fnamemodify) & buffer filetype                    |
 +-----------------------------------------+-----------------------------------------+
                                           |
                        +------------------+------------------+
                        |                                     |
                        v (send_selection_prompt)             v (send_code_context)
 +-----------------------------------------------+  +--------------------------------+
 | Asynchronous User Prompt                      |  | Default Context Prompt         |
 | vim.ui.input({ prompt = "AGY Instruction: " })|  | "Context snippet for review:"  |
 +----------------------+------------------------+  +---------------+----------------+
                        |                                           |
                        +------------------+------------------------+
                                           |
                                           v
 +-----------------------------------------------------------------------------------+
 | lua/herdr-agy/format.lua                                                          |
 | build_context_prompt(user_instruction, selection)                                 |
 | Formats Markdown payload with line ranges (L10 or L10-L25), file path, syntax tag |
 +-----------------------------------------+-----------------------------------------+
                                           |
                                           v
 +-----------------------------------------------------------------------------------+
 | lua/herdr-agy/init.lua                                                            |
 | dispatch_prompt(payload, nil, opts)                                               |
 | Auto-discovers target AGY pane and dispatches via herdr CLI execve                |
 +-----------------------------------------------------------------------------------+
```

---

## 3. Module Specifications & Code Blueprints

### 3.1 `lua/herdr-agy/format.lua`

The `format.lua` module is responsible for constructing human-readable, machine-parseable Markdown prompt strings sent to the target AGY agent.

#### Contract & Requirements
- `format.build_context_prompt(user_instruction, selection)` -> `string`
- Expected string format:
  ```markdown
  <user_instruction>

  Context from `<file_path>` (<line_range>):
  ```<filetype>
  <code_snippet>
  ```
  ```
- **Line Range Formatting Rules**:
  - If `start_line == end_line`: `"L" .. start_line` (e.g. `L15`)
  - If `start_line ~= end_line`: `"L" .. start_line .. "-L" .. end_line` (e.g. `L15-L25`)
  - Defaults: `start_line` fallback `1`, `end_line` fallback `start_line`.
- **Metadata Fallbacks**:
  - `file_path`: empty string or nil fallback to `"[No Name]"`.
  - `filetype`: empty string or nil fallback to `"text"`.
  - `user_instruction`: empty string or nil fallback to `"Context snippet for review:"`.
  - `snippet`: nil fallback to `""`.

#### Implementation Blueprint (`lua/herdr-agy/format.lua`)

```lua
local M = {}

--- Formats a context prompt string containing user instruction and visual code selection.
--- @param user_instruction string|nil Optional user instruction or prompt.
--- @param selection table|nil Table containing selection metadata (file_path, start_line, end_line, filetype, snippet).
--- @return string Formatted markdown string.
function M.build_context_prompt(user_instruction, selection)
  selection = type(selection) == "table" and selection or {}

  local file_path = (type(selection.file_path) == "string" and selection.file_path ~= "") and selection.file_path or "[No Name]"
  local filetype = (type(selection.filetype) == "string" and selection.filetype ~= "") and selection.filetype or "text"
  local snippet = type(selection.snippet) == "string" and selection.snippet or ""

  local start_line = type(selection.start_line) == "number" and selection.start_line or 1
  local end_line = type(selection.end_line) == "number" and selection.end_line or start_line

  local line_range
  if start_line == end_line then
    line_range = "L" .. tostring(start_line)
  else
    line_range = string.format("L%d-L%d", start_line, end_line)
  end

  local instruction = (type(user_instruction) == "string" and user_instruction ~= "") and user_instruction or "Context snippet for review:"

  return string.format(
    "%s\n\nContext from `%s` (%s):\n```%s\n%s\n```",
    instruction,
    file_path,
    line_range,
    filetype,
    snippet
  )
end

--- Formats a diff review prompt string containing user comment and diff hunk information.
--- @param user_comment string|nil Optional user review comment.
--- @param diff_info table|nil Table containing diff metadata (file_path, start_line, end_line, diff_text).
--- @return string Formatted markdown diff prompt string.
function M.build_diff_prompt(user_comment, diff_info)
  diff_info = type(diff_info) == "table" and diff_info or {}

  local file_path = (type(diff_info.file_path) == "string" and diff_info.file_path ~= "") and diff_info.file_path or "[No Name]"
  local start_line = type(diff_info.start_line) == "number" and diff_info.start_line or 1
  local end_line = type(diff_info.end_line) == "number" and diff_info.end_line or start_line
  local diff_text = type(diff_info.diff_text) == "string" and diff_info.diff_text or ""

  local line_range
  if start_line == end_line then
    line_range = "L" .. tostring(start_line)
  else
    line_range = string.format("L%d-L%d", start_line, end_line)
  end

  local comment = (type(user_comment) == "string" and user_comment ~= "") and user_comment or "Diff review comment:"

  return string.format(
    "%s\n\nDiff Context from `%s` (%s):\n```diff\n%s\n```",
    comment,
    file_path,
    line_range,
    diff_text
  )
end

return M
```

---

### 3.2 `lua/herdr-agy/selection.lua`

The `selection.lua` module handles extraction of visual selection ranges from active or specified Neovim buffers, normalization of boundary marks, user prompt collection via `vim.ui.input`, and dispatching to `herdr-agy`.

#### Extraction Mechanics & Algorithm
1. **Exit Visual Mode**: Execute `vim.cmd([[noau normal! \x1b]])` to sync position marks `'<` and `'>`.
2. **Retrieve Mode**: Query `vim.fn.visualmode()`. Returns `'v'`, `'V'`, or `'\22'` (Ctrl-V).
3. **Retrieve Position Marks**: `getpos("'<")` and `getpos("'>")` return `[bufnum, lnum, col, off]`.
4. **Boundary Normalization**:
   - Swap `start_line` and `end_line` if `start_line > end_line`.
   - Swap `start_col` and `end_col` if `start_line == end_line` and `start_col > end_col`.
   - In blockwise visual mode (`\22`), compute `min_col = math.min(start_col, end_col)` and `max_col = math.max(start_col, end_col)`.
5. **Buffer Line Retrieval**: `vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)` (converts 1-indexed line numbers to 0-indexed start / exclusive end).
6. **Mode Slicing**:
   - **Linewise (`V`)**: Join retrieved lines with `\n` without column clipping.
   - **Characterwise (`v`)**:
     - Single line selection: `string.sub(lines[1], start_col, end_col)`.
     - Multi-line selection: slice `lines[1]` from `start_col` to end of string, slice `lines[#lines]` from start of string to `end_col`, leave inner lines untouched, join with `\n`.
   - **Blockwise (`\22` / `<C-v>`)**:
     - Slice `string.sub(line, min_col, max_col)` for every line in the range.
7. **Metadata Retrieval**:
   - `file_path`: `vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:.")`. Fallback to `"[No Name]"`.
   - `filetype`: `vim.bo[bufnr].filetype`. Fallback to `"text"`.

#### Implementation Blueprint (`lua/herdr-agy/selection.lua`)

```lua
local format = require("herdr-agy.format")
local notify = require("herdr-agy.notify")

local M = {}

--- Extracts visual selection range, snippet text, and metadata from a buffer.
--- @param bufnr number|nil Buffer handle (defaults to current buffer 0).
--- @return table Selection table { snippet, start_line, end_line, start_col, end_col, mode, file_path, filetype }
function M.get_visual_selection(bufnr)
  bufnr = (type(bufnr) == "number" and bufnr >= 0) and bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- Exit visual mode cleanly to flush '< and '> position marks
  local cur_mode = vim.fn.mode()
  if cur_mode:find("[vV\22]") then
    vim.cmd([[noau normal! \x1b]])
  end

  local mode = vim.fn.visualmode()
  if mode == "" or not mode:find("[vV\22]") then
    mode = "v"
  end

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  -- Fallback if visual marks are uninitialized
  if start_line == 0 or end_line == 0 then
    local cursor = vim.api.nvim_win_get_cursor(0)
    start_line, end_line = cursor[1], cursor[1]
    start_col, end_col = cursor[2] + 1, cursor[2] + 1
  end

  -- Normalize top-to-bottom and left-to-right boundary order
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  -- Fetch line contents from buffer (0-indexed start, exclusive end)
  local raw_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local lines = {}
  for i, l in ipairs(raw_lines) do
    lines[i] = l
  end

  local snippet = ""
  if #lines > 0 then
    if mode == "V" then
      -- Linewise selection
      snippet = table.concat(lines, "\n")
    elseif mode == "\22" or mode == "<C-v>" then
      -- Blockwise selection rectangle
      local min_col = math.min(start_col, end_col)
      local max_col = math.max(start_col, end_col)
      for i, line in ipairs(lines) do
        lines[i] = string.sub(line, min_col, max_col)
      end
      snippet = table.concat(lines, "\n")
    else
      -- Characterwise selection ('v')
      if #lines == 1 then
        lines[1] = string.sub(lines[1], start_col, end_col)
      else
        lines[1] = string.sub(lines[1], start_col)
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
      end
      snippet = table.concat(lines, "\n")
    end
  end

  -- Extract file path and filetype metadata
  local full_name = vim.api.nvim_buf_get_name(bufnr)
  local file_path = "[No Name]"
  if full_name and full_name ~= "" then
    file_path = vim.fn.fnamemodify(full_name, ":~:.")
    if file_path == "" then
      file_path = full_name
    end
  end

  local filetype = vim.bo[bufnr].filetype
  if not filetype or filetype == "" then
    filetype = "text"
  end

  return {
    snippet = snippet,
    start_line = start_line,
    end_line = end_line,
    start_col = start_col,
    end_col = end_col,
    mode = mode,
    file_path = file_path,
    filetype = filetype,
  }
end

--- Prompts the user asynchronously for an instruction, formats selection context, and dispatches to AGY.
--- @param opts table|nil Options table passed to dispatch_prompt.
function M.send_selection_prompt(opts)
  local selection = M.get_visual_selection(0)

  if not selection.snippet or selection.snippet == "" then
    notify.warn("No visual selection found in buffer", opts)
    return false
  end

  vim.ui.input({ prompt = "AGY Instruction: ", default = "" }, function(input)
    if input == nil or input == "" then
      notify.info("Dispatch cancelled: no instruction entered", opts)
      return
    end

    local payload = format.build_context_prompt(input, selection)
    local main = require("herdr-agy")
    main.dispatch_prompt(payload, nil, opts)
  end)
end

--- Dispatches code selection context directly to AGY with default review prompt.
--- @param opts table|nil Options table passed to dispatch_prompt.
function M.send_code_context(opts)
  local selection = M.get_visual_selection(0)

  if not selection.snippet or selection.snippet == "" then
    notify.warn("No visual selection found in buffer", opts)
    return false
  end

  local payload = format.build_context_prompt("Context snippet for review:", selection)
  local main = require("herdr-agy")
  return main.dispatch_prompt(payload, nil, opts)
end

return M
```

---

### 3.3 `lua/herdr-agy/init.lua` Updates

The main module `lua/herdr-agy/init.lua` must be updated to route `:HerdrAgySend` to `selection.send_selection_prompt()`.

#### Exact Code Changes Blueprint

```lua
-- Add require at top of lua/herdr-agy/init.lua:
local selection = require("herdr-agy.selection")

-- Update user command definition inside M.setup(user_opts):
vim.api.nvim_create_user_command("HerdrAgySend", function()
  selection.send_selection_prompt(M.options)
end, { range = true, desc = "Send visual selection with instruction prompt to AGY" })

-- Add HerdrAgyContext command:
vim.api.nvim_create_user_command("HerdrAgyContext", function()
  selection.send_code_context(M.options)
end, { range = true, desc = "Send visual selection code context to AGY" })

-- Expose selection and format modules on main table:
M.selection = selection
M.format = require("herdr-agy.format")
```

---

## 4. Comprehensive Test Architecture & Blueprints

### 4.1 `tests/test_format.lua` Blueprint

The `tests/test_format.lua` test suite tests all edge cases for markdown context formatting.

```lua
-- Headless Neovim Unit Test Suite for herdr-agy.nvim format module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local format = require("herdr-agy.format")

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
      file_path = "lua/herdr-agy/init.lua",
      start_line = 10,
      end_line = 10,
      filetype = "lua",
      snippet = "local M = {}",
    }
    local res = format.build_context_prompt("Explain this line", selection)
    local expected = "Explain this line\n\nContext from `lua/herdr-agy/init.lua` (L10):\n```lua\nlocal M = {}\n```"
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
    assert_true(res:find("Context from `[No Name]`") ~= nil, "unnamed buffer uses [No Name]")
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
    assert_true(res:find("```text\nsome notes\n```") ~= nil, "empty filetype falls back to text")
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
    assert_true(res:find('echo "$VAR" `date` `uname -a`') ~= nil, "preserves backticks and quotes verbatim")
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
    assert_true(res1:sub(1, # "Context snippet for review:") == "Context snippet for review:", "nil user_instruction uses default prompt")

    local res2 = format.build_context_prompt("", selection)
    assert_true(res2:sub(1, # "Context snippet for review:") == "Context snippet for review:", "empty user_instruction uses default prompt")
  end)

  run_test("build_context_prompt: Nil selection table safety", function()
    local res = format.build_context_prompt("Hello", nil)
    assert_true(res:find("Context from `[No Name]` (L1):") ~= nil, "handles nil selection safely")
  end)

  run_test("build_diff_prompt: Formats diff comment prompt correctly", function()
    local diff_info = {
      file_path = "lua/herdr-agy/notify.lua",
      start_line = 12,
      end_line = 15,
      diff_text = "- old line\n+ new line",
    }
    local res = format.build_diff_prompt("Looks good", diff_info)
    local expected = "Looks good\n\nDiff Context from `lua/herdr-agy/notify.lua` (L12-L15):\n```diff\n- old line\n+ new line\n```"
    assert_eq(res, expected, "build_diff_prompt matches format")
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
```

---

### 4.2 `tests/test_selection.lua` Blueprint

The `tests/test_selection.lua` test suite tests visual selection extraction across all 3 visual modes, boundary normalizations, and dispatch callbacks.

```lua
-- Headless Neovim Unit Test Suite for herdr-agy.nvim visual selection module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local selection = require("herdr-agy.selection")
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

  -- Helper to set visual mode marks manually in test environment
  local function set_visual_marks(buf, mode, start_line, start_col, end_line, end_col)
    vim.fn.setpos("'<", { buf, start_line, start_col, 0 })
    vim.fn.setpos("'>", { buf, end_line, end_col, 0 })
    -- Override visualmode function return value for test duration
    vim.fn.visualmode = function() return mode end
  end

  -- ==========================================================
  -- 1. VISUAL SELECTION EXTRACTION TESTS
  -- ==========================================================

  run_test("get_visual_selection: Linewise visual selection ('V')", function()
    local buf = create_fixture_buf({ "line 1", "line 2", "line 3", "line 4" }, "lua", "/tmp/test.lua")
    set_visual_marks(buf, "V", 2, 1, 3, 6)

    local sel = selection.get_visual_selection(buf)
    assert_eq(sel.mode, "V", "mode is V")
    assert_eq(sel.start_line, 2, "start_line is 2")
    assert_eq(sel.end_line, 3, "end_line is 3")
    assert_eq(sel.snippet, "line 2\nline 3", "linewise snippet extracts full lines 2-3")
    assert_eq(sel.filetype, "lua", "filetype matches lua")
    assert_true(sel.file_path:find("test.lua") ~= nil, "file_path contains test.lua")
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
    assert_eq(sel.snippet, "BCD\nHIJ\nOPQ", "blockwise rectangle extracts columns 2-4 across lines 1-3")
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
    local buf = create_fixture_buf({ "function test()", "  return 42", "end" }, "lua", "/tmp/demo.lua")
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
    assert_true(dispatched_text:find("Explain this function") ~= nil, "payload contains user instruction")
    assert_true(dispatched_text:find("Context from `/tmp/demo.lua` %((L1-L3)%):") ~= nil, "payload contains metadata header")
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
    local buf = create_fixture_buf({ "const x = 100;" }, "typescript", "/tmp/app.ts")
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
    assert_true(dispatched_text:find("Context snippet for review:") ~= nil, "payload contains default prompt")
    assert_true(dispatched_text:find("```typescript\nconst x = 100;\n```") ~= nil, "payload contains code block")
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
```

---

## 5. Boundary Conditions, Edge Cases & Fault Tolerance Matrix

| Scenario / Edge Case | Cause / Condition | Handling Strategy | Operational Outcome |
|---|---|---|---|
| **Reverse Selection (Bottom-to-Top)** | User selected from bottom line to top line (e.g., L20 to L10) | Boundary normalization compares `start_line` vs `end_line` and swaps them if `start_line > end_line` | Clean range extraction `L10-L20` |
| **Right-to-Left Selection** | Characterwise/blockwise selection pulled right-to-left | Boundary normalization swaps `start_col` and `end_col` or computes `min_col`/`max_col` | Verbatim text block extraction without negative string indexing error |
| **Uninitialized Marks (`'<` and `'>` = 0)** | Buffer created without entering visual mode | Fallback to `vim.api.nvim_win_get_cursor(0)` position | Single-line cursor position fallback |
| **Unnamed Buffer** | Buffer has no name (`nvim_buf_get_name` returns `""`) | `fnamemodify` check converts empty path to `"[No Name]"` | Clean header `Context from [No Name]` |
| **Empty Filetype** | Buffer lacks filetype option (e.g. scratch buffer) | Fallback `filetype` check defaults to `"text"` | Markdown fence rendered as ` ```text ` |
| **Esc / User Cancel in `vim.ui.input`** | User presses Esc or submits empty input | Callback checks `input == nil or input == ""`, sends info notification, aborts dispatch | Zero side-effects; Neovim state unaffected |
| **Special Characters in Code Snippet** | Code contains backticks, `$`, quotes, backslashes, newlines | `build_context_prompt` embeds code inside 3-backtick fence block; `dispatch_prompt` uses array table `vim.system` execution | Safe, exact transmission without shell execution vulnerabilities |

---

## 6. Verification & Test Plan

1. **Headless Execution Test**:
   ```bash
   nvim --headless -u NONE -c "luafile tests/run_tests.lua"
   ```
   *Expected Outcome*: All test suites (`test_topology.lua`, `test_plugin_spec.lua`, `test_adversarial_m2.lua`, `test_format.lua`, `test_selection.lua`) pass with 0 failures.

2. **Visual Selection Mode Verification**:
   - Verify characterwise (`v`), linewise (`V`), and blockwise (`<C-v>`) extraction against fixture buffers.
   - Verify 1-indexed line range strings (`L10` vs `L10-L20`).

3. **User Command & Keymap Integration Verification**:
   - Verify `:HerdrAgySend` executes `selection.send_selection_prompt()`.
   - Verify `<leader>at` triggers `:HerdrAgySend` in visual mode.
