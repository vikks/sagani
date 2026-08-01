# Defect Analysis Report: Headless Test Suite Hang & Remediation Strategy

**Project**: `herdr-agy.nvim`  
**Milestone**: Milestone 3 (Iteration 2)  
**Agent**: Explorer 1 (`.agents/teamwork_preview_explorer_m3_r2_1`)  
**Date**: 2026-08-01  

---

## Executive Summary

When running the master headless test runner via:
```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```
the process hangs indefinitely during the execution of `tests/test_adversarial_m2.lua`.

### Core Findings
1. **Primary Defect (High Severity)**: In `tests/test_adversarial_m2.lua`, line 179 executes `:1,2HerdrAgySend` on a buffer containing text lines. In Milestone 3, `:HerdrAgySend` was wired in `lua/herdr-agy/init.lua` to call `selection.send_selection_prompt()`, which invokes Neovim's interactive input API `vim.ui.input({ prompt = "AGY Instruction: " }, callback)`. Because `test_adversarial_m2.lua` does NOT mock `vim.ui.input`, `vim.ui.input` waits for input on standard input (`stdin`). In headless mode (`--headless`), no terminal stdin is supplied, causing Neovim to hang indefinitely.
2. **Secondary Defect (Medium Severity)**: The LazyVim plugin specification in `plugins/herdr-agy.lua` defines the lazy-loading `cmd` table but omits `"HerdrAgyContext"`. Lazy.nvim will fail to lazy-load `herdr-agy.nvim` when `:HerdrAgyContext` is invoked directly by a user.

---

## 1. Technical Deep-Dive & Evidence Chain

### 1.1 Trace of Execution Flow & Failure Point

1. `tests/run_tests.lua` sets `_G.RUNNING_TEST_SUITE = true` and iterates over test files in alphabetical order.
2. The first file executed is `tests/test_adversarial_m2.lua`.
3. In `tests/test_adversarial_m2.lua` (lines 168–189), the test case `"adversarial_keymaps: user commands range execution in visual mode"` executes:
   ```lua
   -- Line 174: Creates a scratch buffer with 3 lines of text
   local buf = vim.api.nvim_create_buf(false, true)
   vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
   vim.api.nvim_set_current_buf(buf)

   -- Line 179: Executes the user command with range
   local ok1 = pcall(vim.cmd, "1,2HerdrAgySend")
   ```
4. User command `:HerdrAgySend` is registered in `lua/herdr-agy/init.lua` (lines 71–73):
   ```lua
   vim.api.nvim_create_user_command("HerdrAgySend", function()
     selection.send_selection_prompt(M.options)
   end, { range = true, desc = "Send visual selection with instruction prompt to AGY" })
   ```
5. `selection.send_selection_prompt` in `lua/herdr-agy/selection.lua` (lines 106–124) extracts the selection:
   ```lua
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
   ```
6. Because lines 1 and 2 exist in `buf`, `selection.get_visual_selection(0)` returns a valid non-empty snippet (`"line 1\nline 2"`).
7. Execution reaches line 114: `vim.ui.input({ prompt = "AGY Instruction: ", default = "" }, function(input) ... end)`.
8. Neovim's built-in `vim.ui.input` attempts to read interactive keyboard input from terminal stdin. Because Neovim is running headlessly, standard input never receives a newline or EOF, blocking the event loop indefinitely.

### 1.2 Comparison with `tests/test_selection.lua`

In `tests/test_selection.lua` (lines 136–152 and 164–178), `vim.ui.input` is explicitly mocked prior to calling `send_selection_prompt`:
```lua
-- Mock vim.ui.input
local orig_input = vim.ui.input
vim.ui.input = function(opts, cb)
  assert_eq(opts.prompt, "AGY Instruction: ", "input prompt string")
  cb("Explain this function")
end

selection.send_selection_prompt({ notify = { enabled = false } })

-- Restore vim.ui.input
vim.ui.input = orig_input
```
This is why `tests/test_selection.lua` runs and passes without hanging.

### 1.3 Empirical Verification of Hang

Running `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` in the background via tool execution produced the following log output before hanging:
```
==========================================================
  herdr-agy.nvim Master Test Runner
==========================================================

>>> Executing Test Suite: test_adversarial_m2.lua
...
Running Test: adversarial_keymaps: user commands execution from normal mode
  ✓ PASS: HerdrAgyStatus executes in normal mode
  ✓ PASS: HerdrAgySend executes in normal mode
  ✓ PASS: HerdrAgyDiff executes in normal mode

Running Test: adversarial_keymaps: user commands range execution in visual mode
AGY Instruction: 
```
The test runner output stops right at `AGY Instruction: `, confirming that `vim.ui.input` is waiting on interactive stdin.

---

## 2. Secondary Defect Analysis (`plugins/herdr-agy.lua`)

In `plugins/herdr-agy.lua`, lines 17–23 define Lazy.nvim command triggers:
```lua
    cmd = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyDiff",
    },
```
Notice that `"HerdrAgyContext"` (which was added to `lua/herdr-agy/init.lua` in M3 line 75) is omitted from this table. If a user triggers `:HerdrAgyContext` in LazyVim before the plugin is loaded, Lazy.nvim will not recognize `:HerdrAgyContext` as a command trigger for `herdr-agy.nvim`.

---

## 3. Remediation Strategy

To achieve 100% test pass rate with zero hanging and ensure full LazyVim integration, the following remediation strategy is recommended for Implementer:

### 3.1 Remediation Part 1: Mock `vim.ui.input` in `tests/test_adversarial_m2.lua`

In `tests/test_adversarial_m2.lua`, both command execution tests should mock `vim.ui.input` during command execution and restore it afterward:

#### Change in `tests/test_adversarial_m2.lua`:
```lua
  run_test("adversarial_keymaps: user commands execution from normal mode", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "herdr-agy.nvim")
    main_spec.config(main_spec, { notify = { enabled = false } })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      if cb then cb("normal mode instruction") end
    end

    -- Test executing user commands without error
    local ok1 = pcall(vim.cmd, "HerdrAgyStatus")
    assert_true(ok1, "HerdrAgyStatus executes in normal mode")

    local ok2 = pcall(vim.cmd, "HerdrAgySend")
    assert_true(ok2, "HerdrAgySend executes in normal mode")

    local ok3 = pcall(vim.cmd, "HerdrAgyDiff")
    assert_true(ok3, "HerdrAgyDiff executes in normal mode")

    vim.ui.input = orig_input
  end)

  run_test("adversarial_keymaps: user commands range execution in visual mode", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "herdr-agy.nvim")
    main_spec.config(main_spec, { notify = { enabled = false } })

    -- Create a test buffer and select lines
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
    vim.api.nvim_set_current_buf(buf)

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      if cb then cb("test instruction") end
    end

    -- Test range command execution with range
    local ok1 = pcall(vim.cmd, "1,2HerdrAgySend")
    assert_true(ok1, "1,2HerdrAgySend with range succeeds (range = true)")

    -- Test whether HerdrAgyDiff or HerdrAgyPrompt accept ranges
    local ok2, err2 = pcall(vim.cmd, "1,2HerdrAgyDiff")
    print("  ℹ Note: 1,2HerdrAgyDiff with range ok=" .. tostring(ok2) .. (err2 and (" err=" .. tostring(err2)) or ""))

    local ok3, err3 = pcall(vim.cmd, "1,2HerdrAgyPrompt Test")
    print("  ℹ Note: 1,2HerdrAgyPrompt with range ok=" .. tostring(ok3) .. (err3 and (" err=" .. tostring(err3)) or ""))

    vim.ui.input = orig_input
  end)
```

### 3.2 Remediation Part 2: Add `"HerdrAgyContext"` to `plugins/herdr-agy.lua`

Update `plugins/herdr-agy.lua` to include `"HerdrAgyContext"` in the `cmd` list:
```lua
    cmd = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyContext",
      "HerdrAgyDiff",
    },
```
Also update `tests/test_plugin_spec.lua` if needed to assert 6 commands instead of 5 in `cmd`.

### 3.3 Remediation Part 3: Defensive Safety Net in `tests/run_tests.lua` (Optional Hardening)

To prevent future unmocked `vim.ui.input` calls from hanging the runner if any new test is added without explicit input mocking, `tests/run_tests.lua` can set up a global fallback override for `vim.ui.input`:

```lua
-- In tests/run_tests.lua after setting _G.RUNNING_TEST_SUITE = true
local default_ui_input = vim.ui.input
vim.ui.input = function(opts, cb)
  if type(cb) == "function" then
    cb(opts and opts.default or "headless test default input")
  end
end
```
Individual test suites like `test_selection.lua` will continue to override `vim.ui.input` locally during their own test cases and restore it, while any unmocked call elsewhere will receive immediate non-blocking test input instead of hanging stdin.

---

## 4. Verification Protocol

After implementing the remediation changes:
1. Run the headless master test runner:
   ```bash
   nvim --headless -u NONE -c "luafile tests/run_tests.lua"
   ```
2. Verify exit code is 0 (`echo $?`).
3. Verify output contains `TOTAL TEST RESULTS: X Passed, 0 Failed across N test file(s)` and finishes with `All test suites passed successfully!`.
