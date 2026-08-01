# Handoff Report: Headless Test Hang Analysis & Remediation Strategy

**Project**: `herdr-agy.nvim`  
**Milestone**: Milestone 3 (Iteration 2)  
**Agent**: Explorer 1 (`.agents/teamwork_preview_explorer_m3_r2_1`)  
**Type**: Hard Handoff  

---

## 1. Observation

Direct observations from codebase inspection and headless command execution:

1. **`tests/test_adversarial_m2.lua` Line 179**:
   ```lua
   174: local buf = vim.api.nvim_create_buf(false, true)
   175: vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
   176: vim.api.nvim_set_current_buf(buf)
   177: 
   178: -- Test range command execution with range
   179: local ok1 = pcall(vim.cmd, "1,2HerdrAgySend")
   ```
   *Observation*: `:1,2HerdrAgySend` is invoked on a buffer containing lines, without mocking `vim.ui.input`.

2. **`lua/herdr-agy/init.lua` Lines 71–73**:
   ```lua
   71: vim.api.nvim_create_user_command("HerdrAgySend", function()
   72:   selection.send_selection_prompt(M.options)
   73: end, { range = true, desc = "Send visual selection with instruction prompt to AGY" })
   ```
   *Observation*: User command `:HerdrAgySend` executes `selection.send_selection_prompt(M.options)`.

3. **`lua/herdr-agy/selection.lua` Lines 106–118**:
   ```lua
   106: function M.send_selection_prompt(opts)
   107:   local selection = M.get_visual_selection(0)
   108: 
   109:   if not selection.snippet or selection.snippet == "" then
   110:     notify.warn("No visual selection found in buffer", opts)
   111:     return false
   112:   end
   113: 
   114:   vim.ui.input({ prompt = "AGY Instruction: ", default = "" }, function(input)
   ```
   *Observation*: When `selection.snippet` is non-empty, `send_selection_prompt` calls `vim.ui.input({ prompt = "AGY Instruction: ", default = "" }, callback)`.

4. **Headless Terminal Command Execution Output**:
   Command: `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`
   Verbatim output before hanging:
   ```
   ==========================================================
     herdr-agy.nvim Master Test Runner
   ==========================================================

   >>> Executing Test Suite: test_adversarial_m2.lua

   Running Test: adversarial_whichkey: plugin spec evaluates when which-key is unloaded
     ✓ PASS: plugins/herdr-agy.lua executes cleanly without which-key loaded
     ✓ PASS: returns spec array with 2 entries
     ✓ PASS: which-key spec present in array
     ✓ PASS: which-key spec is optional=true
     ✓ PASS: main spec present independently of which-key
   ...
   Running Test: adversarial_keymaps: user commands execution from normal mode
     ✓ PASS: HerdrAgyStatus executes in normal mode
     ✓ PASS: HerdrAgySend executes in normal mode
     ✓ PASS: HerdrAgyDiff executes in normal mode

   Running Test: adversarial_keymaps: user commands range execution in visual mode
   AGY Instruction: 
   ```
   *Observation*: The headless process stopped and remained running indefinitely right after printing `AGY Instruction: `.

5. **`plugins/herdr-agy.lua` Lines 17–23**:
   ```lua
   17:     cmd = {
   18:       "HerdrAgyStatus",
   19:       "HerdrAgySelectTarget",
   20:       "HerdrAgyPrompt",
   21:       "HerdrAgySend",
   22:       "HerdrAgyDiff",
   23:     },
   ```
   *Observation*: `"HerdrAgyContext"` is registered in `lua/herdr-agy/init.lua:75` but omitted from `plugins/herdr-agy.lua` `cmd` array.

---

## 2. Logic Chain

1. Observation 1 shows `tests/test_adversarial_m2.lua` executes `pcall(vim.cmd, "1,2HerdrAgySend")` on a buffer containing `"line 1", "line 2", "line 3"`.
2. Observation 2 shows `HerdrAgySend` calls `selection.send_selection_prompt(M.options)`.
3. Observation 3 shows `send_selection_prompt` extracts visual selection, finds non-empty snippet `"line 1\nline 2"`, and invokes `vim.ui.input({ prompt = "AGY Instruction: " }, ...)`.
4. In headless Neovim (`nvim --headless`), `vim.ui.input` blocks waiting for interactive terminal input from stdin. Because no input is supplied on stdin, the event loop blocks indefinitely.
5. Observation 4 empirically confirms that running `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` hangs indefinitely at `AGY Instruction: ` in `test_adversarial_m2.lua`.
6. Therefore, mocking `vim.ui.input` during command execution tests in `test_adversarial_m2.lua` will allow `send_selection_prompt` to complete synchronously and allow the master test runner to complete to exit code 0.
7. Observation 5 shows `plugins/herdr-agy.lua` omits `"HerdrAgyContext"` from the `cmd` table. Adding `"HerdrAgyContext"` ensures Lazy.nvim lazy-loads the plugin when `:HerdrAgyContext` is run.

---

## 3. Caveats

- We did not observe any other test files in `tests/` (`test_topology.lua`, `test_format.lua`, `test_selection.lua`, `test_plugin_spec.lua`) hanging because they either mock `vim.ui.input` locally or do not execute commands that prompt for user input.
- If additional tests are created in the future that execute `:HerdrAgySelectTarget` or `:HerdrAgyPrompt` (with empty args), those test cases must also mock `vim.ui.input` or rely on a global fallback in `tests/run_tests.lua`.

---

## 4. Conclusion

The test suite hang is caused by unmocked `vim.ui.input` execution in `tests/test_adversarial_m2.lua` during visual range `:1,2HerdrAgySend` command invocation.

Remediation requires:
1. Mocking `vim.ui.input` in `tests/test_adversarial_m2.lua` around command execution blocks.
2. Adding `"HerdrAgyContext"` to the `cmd` list in `plugins/herdr-agy.lua`.
3. Optionally providing a fallback mock for `vim.ui.input` in `tests/run_tests.lua`.

---

## 5. Verification Method

### Command
Run the master test runner headlessly from the working directory:
```bash
nvim --headless -u NONE -c "luafile tests/run_tests.lua"
```

### Expected Output
- Exit code: 0 (`echo $?` -> `0`)
- Standard output ends with:
  ```
  ==========================================================
  TOTAL TEST RESULTS: <N> Passed, 0 Failed across 5 test file(s)
  ==========================================================

  All test suites passed successfully!
  ```
- Completion time < 3 seconds with zero hanging processes.

### Invalidation Conditions
- Any hang or process timeout when executing `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`.
- Any test failure in any of the 5 test suites (`test_adversarial_m2.lua`, `test_plugin_spec.lua`, `test_selection.lua`, `test_format.lua`, `test_topology.lua`).
