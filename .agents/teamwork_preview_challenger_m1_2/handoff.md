# Handoff Report — Milestone 1 (M1) Adversarial Challenge

**Agent**: `teamwork_preview_challenger_m1_2`  
**Role**: Empirical Challenger 2 (critic, specialist)  
**Milestone**: M1: Herdr Auto-Discovery & Core Topology  
**Date**: 2026-08-01  
**Verdict**: **`REQUEST_CHANGES`**

---

## 1. Observation

Direct observations and empirical test results obtained by executing headless Neovim commands (`nvim --headless -u NONE`):

1. **Process Execution Stderr Discarded on Failure (`lua/herdr-agy/init.lua:97-108`)**:
   - Lines 97-99:
     ```lua
     if vim.system then
       local res = vim.system(cmd):wait()
       stdout, code = res.stdout or "", res.code
     ```
   - Lines 105-108:
     ```lua
     if code ~= 0 then
       local msg = string.format("Failed to prompt agent pane '%s' (exit code %d): %s", pane_id, code, stdout)
       notify.error(msg, opts)
       return false, msg
     end
     ```
   - **Empirical execution**: Mocked `vim.system` to return `{ code = 1, stdout = "", stderr = "herdr: error: pane w1:p99 does not exist" }`.
   - **Result**: `dispatch_prompt("test", "w1:p99")` returned `(false, "Failed to prompt agent pane 'w1:p99' (exit code 1): ")`. `res.stderr` was completely discarded and omitted from the error notification given to the user.

2. **Fatal Crash & Failure to Suppress in Notification Module (`lua/herdr-agy/notify.lua:28, 33`)**:
   - Line 28:
     ```lua
     if opts.notify and opts.notify.enabled == false then
       return
     end
     ```
   - Line 33:
     ```lua
     local title = (opts.notify and opts.notify.title) or opts.title or "herdr-agy.nvim"
     ```
   - **Empirical execution 1**: `notify.info("test", { notify = true })`.
   - **Result 1**: Fatal Lua runtime error: `./lua/herdr-agy/notify.lua:28: attempt to index field 'notify' (a boolean value)`.
   - **Empirical execution 2**: `notify.info("test", { notify = false })`.
   - **Result 2**: `vim.notify` was called anyway because `opts.notify and opts.notify.enabled == false` evaluates to `false` when `opts.notify` is `false`.

3. **Empty String `target_pane` Bypasses Auto-Discovery (`lua/herdr-agy/init.lua:77, 80`)**:
   - Line 77: `local pane_id = target_pane or opts.pane_override`
   - Line 80: `if not pane_id then pane_id, err = topology.discover_target_pane(opts) end`
   - **Empirical execution**: `dispatch_prompt("test prompt", "")` outside Herdr environment.
   - **Result**: Since `""` is truthy in Lua, `pane_id` remained `""`. `if not pane_id` evaluated to `false`, skipping `topology.discover_target_pane(opts)` and executing `herdr agent prompt "" "test prompt"`, resulting in execution error rather than running auto-discovery or returning a clean target validation error.

4. **Missing Prompt Text Validation (`lua/herdr-agy/init.lua:75-95`)**:
   - **Empirical execution**: `dispatch_prompt(nil, "w1:p1")`.
   - **Result**: `dispatch_prompt` attempted process execution with `nil` prompt argument, returning CLI exit code 2 error (`Failed to prompt agent pane 'w1:p1' (exit code 2): `).

5. **`setup()` Option Validation (`lua/herdr-agy/init.lua:19`)**:
   - **Empirical execution**: `init.setup("invalid_type")`.
   - **Result**: `vim.tbl_deep_extend` threw `expected table, got string`.

---

## 2. Logic Chain

1. Requirements in `ORIGINAL_REQUEST.md` and `PROJECT.md` mandate robust process execution, error handling when binaries are missing or invalid args passed, user command integration, and notification handling.
2. When executing `herdr agent prompt` via `vim.system`, CLI commands output failure diagnostics (e.g. non-existent pane, unhandled args, daemon offline) to `stderr`. Because `init.lua` reads only `res.stdout`, all failure notifications present blank error messages `(exit code X): ` to users, obscuring actionable diagnostic feedback.
3. Neovim plugins commonly accept boolean option flags (e.g. `{ notify = false }` or `{ notify = true }`). In `notify.lua`, passing a boolean `notify` key causes either a fatal Lua indexing crash (`notify = true`) or completely fails to disable notifications (`notify = false`).
4. Passing empty string `target_pane = ""` to `dispatch_prompt` violates Lua truthiness assumptions (`""` is truthy), bypassing auto-discovery and executing malformed CLI commands.
5. Therefore, while command registration and topology scoring work under happy-path conditions, critical process execution error reporting and notification handling contain defects that require resolution before M1 approval.

---

## 3. Caveats

- Live Herdr daemon interaction was tested using `vim.system` mocks and execution against the local PATH environment where `herdr` binary was absent.
- visual selection (`HerdrAgySend`) and diff comment (`HerdrAgyDiff`) command handlers are stubs by specification for M1; detailed inspection of their internal logic is scheduled for M3 and M4.

---

## 4. Conclusion & Verdict

**Verdict**: **`REQUEST_CHANGES`**

Milestone 1 satisfies command registration and topology score hierarchy requirements, but cannot be approved in its current state due to 2 confirmed functional bugs and 3 edge-case vulnerabilities:

1. **[HIGH] Process Execution Error Output Discarded**: `init.lua` discards `res.stderr` when `vim.system` commands fail, presenting empty error notifications to the user.
2. **[MEDIUM] `notify.lua` Boolean Option Crash/Failure**: `{ notify = true }` causes a fatal Lua indexing runtime error; `{ notify = false }` fails to suppress notifications.
3. **[LOW/MEDIUM] Empty Target Pane Auto-Discovery Bypass**: `dispatch_prompt(prompt, "")` treats empty string `target_pane` as truthy, bypassing topology auto-discovery.
4. **[LOW] Missing Prompt Text Validation**: `dispatch_prompt` does not validate `prompt_text` presence/type before running `vim.system`.
5. **[LOW] Non-table `user_opts` Unhandled**: `init.setup(user_opts)` throws uncaught `tbl_deep_extend` error if non-table `user_opts` is supplied.

---

## 5. Verification Method

To verify these findings independently:

1. **Verify `stderr` Discard Bug**:
   Run in headless Neovim:
   ```bash
   nvim --headless -u NONE -c "lua
   package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
   local init = require('herdr-agy.init')
   local orig = vim.system
   vim.system = function() return { wait = function() return { code = 1, stdout = '', stderr = 'pane not found' } end } end
   local _, err = init.dispatch_prompt('hello', 'p1')
   vim.system = orig
   assert(err:find('pane not found') ~= nil, 'FAIL: stderr was discarded!')
   vim.cmd('qall!')
   "
   ```
   *Expected Failure*: Assert fails with `'FAIL: stderr was discarded!'` because `err` is `"Failed to prompt agent pane 'p1' (exit code 1): "`.

2. **Verify `notify.lua` Boolean Crash & Suppression Failure**:
   Run in headless Neovim:
   ```bash
   nvim --headless -u NONE -c "lua
   package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
   local notify = require('herdr-agy.notify')
   -- Crash test:
   local ok, _ = pcall(function() notify.info('msg', { notify = true }) end)
   assert(ok, 'FAIL: crashed on notify = true')
   vim.cmd('qall!')
   "
   ```
   *Expected Failure*: Assert fails with `'FAIL: crashed on notify = true'` due to `attempt to index field 'notify' (a boolean value)`.

---

## Adversarial Challenge Report

## Challenge Summary

**Overall risk assessment**: MEDIUM

## Challenges

### [High] Process Error Output Discarded
- **Assumption challenged**: `vim.system` results store failure output in `res.stdout`.
- **Attack scenario**: Process `herdr agent prompt` fails (pane missing, daemon down) and writes error text to `stderr`.
- **Blast radius**: User receives uninformative notification `Failed to prompt agent pane 'x' (exit code 1): ` without knowing why.
- **Mitigation**: Fall back to `res.stderr` when `res.stdout` is empty on command failure.

### [Medium] `notify.lua` Option Type Rigidity
- **Assumption challenged**: `opts.notify` is always a table or nil.
- **Attack scenario**: User passes `{ notify = true }` or `{ notify = false }` in plugin setup or command invocation options.
- **Blast radius**: Fatal Lua crash on `notify = true`; failure to mute notifications on `notify = false`.
- **Mitigation**: Add explicit `type(opts.notify)` checks in `notify.lua`.

### [Low/Medium] Empty Target Pane Handling
- **Assumption challenged**: `target_pane` is either a non-empty string or `nil`.
- **Attack scenario**: Caller passes `""` (empty string) as `target_pane`.
- **Blast radius**: Bypasses auto-discovery, attempts process execution with invalid pane `""`.
- **Mitigation**: Check `target_pane ~= ""` before setting `pane_id`.

## Stress Test Results

- `dispatch_prompt` with failing `vim.system` (stderr output) → captures error text → error text discarded → **FAIL**
- `notify.info` with `{ notify = true }` → executes without error → fatal Lua crash → **FAIL**
- `notify.info` with `{ notify = false }` → mutes notification → calls `vim.notify` anyway → **FAIL**
- `dispatch_prompt` with `target_pane = ""` → triggers auto-discovery → executes CLI with `""` → **FAIL**
- `:HerdrAgyStatus` command registration & run → outputs status string cleanly → works cleanly → **PASS**
- `init.setup()` option merging → merges defaults with user_opts → default values preserved → **PASS**

## Unchallenged Areas

- Visual selection extraction (`lua/herdr-agy/selection.lua`) — out of scope for M1 (scheduled for M3).
- Diff review integration (`lua/herdr-agy/diff.lua`) — out of scope for M1 (scheduled for M4).
