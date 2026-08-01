# Handoff Report — Milestone 1 (M1) Adversarial Challenge

**Agent**: `teamwork_preview_challenger_m1_1`  
**Role**: Empirical Challenger (critic / specialist)  
**Milestone**: M1: Herdr Auto-Discovery & Core Topology  
**Date**: 2026-08-01  
**Verdict**: `REQUEST_CHANGES`

---

## 1. Observation

Adversarial stress testing was conducted against `lua/herdr-agy/topology.lua` and `lua/herdr-agy/notify.lua` using an empirical test harness (`.agents/teamwork_preview_challenger_m1_1/stress_test.lua`) executed via headless Neovim:

```bash
nvim --headless -u NONE -c "luafile .agents/teamwork_preview_challenger_m1_1/stress_test.lua"
```

**Test Execution Results**: **11 Passed, 10 Failed** out of 21 stress scenarios.

### Verbatim Failures & Errors:

1. **`JSON 1.2` & `JSON 1.3` Failure**:
   - Command: `nvim --headless -u NONE -c "luafile .agents/teamwork_preview_challenger_m1_1/stress_test.lua"`
   - Output:
     ```
     [STRESS TEST] JSON 1.2: JSON result field is primitive number (data.result = 123)
       ✗ FAIL: JSON 1.2 — CRASH/UNHANDLED EXCEPTION: .../lua/herdr-agy/topology.lua:27: attempt to index field 'result' (a number value)
     [STRESS TEST] JSON 1.3: JSON result field is boolean true (data.result = true)
       ✗ FAIL: JSON 1.3 — CRASH/UNHANDLED EXCEPTION: .../lua/herdr-agy/topology.lua:27: attempt to index field 'result' (a boolean value)
     ```
   - Target File: `lua/herdr-agy/topology.lua:27` and `lua/herdr-agy/topology.lua:51`

2. **`JSON 1.8` & `DISCOVER 2.1` Failure**:
   - Command: `nvim --headless -u NONE -c "luafile .agents/teamwork_preview_challenger_m1_1/stress_test.lua"`
   - Output:
     ```
     [STRESS TEST] JSON 1.8: Non-table items inside agents array
       ✗ FAIL: JSON 1.8 — CRASH/UNHANDLED EXCEPTION: .../lua/herdr-agy/topology.lua:88: attempt to index local 'a' (a number value)
     [STRESS TEST] DISCOVER 2.1: Candidates array with non-table elements
       ✗ FAIL: DISCOVER 2.1 — CRASH/UNHANDLED EXCEPTION: .../lua/herdr-agy/topology.lua:88: attempt to index local 'a' (a number value)
     ```
   - Target File: `lua/herdr-agy/topology.lua:88`

3. **`DISCOVER 2.2` & `DISCOVER 2.3` Failure**:
   - Command: `nvim --headless -u NONE -c "luafile .agents/teamwork_preview_challenger_m1_1/stress_test.lua"`
   - Output:
     ```
     [STRESS TEST] DISCOVER 2.2: Candidate agent has nil pane_id
       ✗ FAIL: DISCOVER 2.2 — Got pane=nil, err=nil
     [STRESS TEST] DISCOVER 2.3: Candidate agent has empty string pane_id
       ✗ FAIL: DISCOVER 2.3 — Got pane=, err=nil
     ```
   - Target File: `lua/herdr-agy/topology.lua:97-144`

4. **`DISCOVER 2.4` Failure**:
   - Command: `nvim --headless -u NONE -c "luafile .agents/teamwork_preview_challenger_m1_1/stress_test.lua"`
   - Output:
     ```
     [STRESS TEST] DISCOVER 2.4: Non-string pane_override (e.g. number 100)
       ✗ FAIL: DISCOVER 2.4 — Returned non-string pane: number (100)
     ```
   - Target File: `lua/herdr-agy/topology.lua:60`

5. **`NOTIFY 3.1`, `NOTIFY 3.2`, `NOTIFY 3.3` Failure**:
   - Command: `nvim --headless -u NONE -c "luafile .agents/teamwork_preview_challenger_m1_1/stress_test.lua"`
   - Output:
     ```
     [STRESS TEST] NOTIFY 3.1: opts.notify is boolean true (opts = { notify = true })
       ✗ FAIL: NOTIFY 3.1 — Crashed: .../lua/herdr-agy/notify.lua:28: attempt to index field 'notify' (a boolean value)
     [STRESS TEST] NOTIFY 3.2: opts is primitive number (opts = 123)
       ✗ FAIL: NOTIFY 3.2 — Crashed: .../lua/herdr-agy/notify.lua:28: attempt to index local 'opts' (a number value)
     [STRESS TEST] NOTIFY 3.3: opts is primitive boolean true (opts = true)
       ✗ FAIL: NOTIFY 3.3 — Crashed: .../lua/herdr-agy/notify.lua:28: attempt to index local 'opts' (a boolean value)
     ```
   - Target File: `lua/herdr-agy/notify.lua:28` and `lua/herdr-agy/notify.lua:33`

---

## 2. Logic Chain

1. **Defect 1 (`topology.lua` lines 27 & 51)**:
   - Observation: Line 27 reads: `if not ok or type(data) ~= "table" or not data.result or type(data.result.agents) ~= "table" then`.
   - Logic: `pcall` is used only for `vim.json.decode`. The structure assertion is evaluated outside `pcall`. When JSON contains `{"result": 123}` or `{"result": true}`, `not data.result` evaluates to `false` because numbers and booleans are truthy in Lua. Subsequently, Lua evaluates `type(data.result.agents)`, which attempts to index a primitive (`(123).agents`), throwing an unhandled runtime exception.
   - Conclusion: `type(data.result) ~= "table"` must be checked before attempting to index `data.result.agents`.

2. **Defect 2 (`topology.lua` line 88)**:
   - Observation: Candidate filtering iterates over `agents` using `for _, a in ipairs(agents) do` and performs `if a.agent == target_agent then`.
   - Logic: If `agents` contains any non-table item (e.g. string `"foo"`, number `123`, or boolean `true`), Lua attempts to evaluate `a.agent` on a primitive value outside of any guard clause, throwing an unhandled runtime error (`attempt to index local 'a' (a number value)`).
   - Conclusion: Candidate filtering must check `type(a) == "table"` before indexing `a.agent`.

3. **Defect 3 (`topology.lua` lines 97-144)**:
   - Observation: Candidate tier matching returns `c.pane_id` directly for candidate `c`.
   - Logic: When candidate object `c` has `pane_id = nil` or `pane_id = ""`, the matching tier returns `c.pane_id` directly without validating that it is a valid non-empty string.
   - Result: Returning `nil` pane with `nil` error violates the contract of `discover_target_pane` (which requires `err` to describe failure when `pane_id` is `nil`). Returning `""` causes downstream command dispatchers (`init.dispatch_prompt`) to construct invalid CLI calls (e.g., `herdr agent prompt "" "msg"`).
   - Conclusion: Candidates must be required to have a non-empty string `pane_id` during candidate filtering.

4. **Defect 4 (`topology.lua` line 60)**:
   - Observation: Line 60 checks `if opts.pane_override and opts.pane_override ~= "" then return opts.pane_override, nil, ... end`.
   - Logic: If `opts.pane_override` is passed as a number (e.g., `100`), `opts.pane_override ~= ""` evaluates to `true`. Non-string `100` is returned.
   - Conclusion: `opts.pane_override` should be converted to string via `tostring(opts.pane_override)` or type-checked.

5. **Defect 5 (`notify.lua` lines 28 & 33)**:
   - Observation: Line 28 reads `if opts.notify and opts.notify.enabled == false then`. Line 33 reads `local title = (opts.notify and opts.notify.title) ...`.
   - Logic: If `opts` is a primitive value (`123` or `true`), indexing `opts.notify` crashes. If `opts.notify` is a boolean (`opts = { notify = true }` or `opts = { notify = false }`), `opts.notify` is truthy, so Lua attempts `(true).enabled`, throwing `attempt to index field 'notify' (a boolean value)`.
   - Conclusion: Safely check `type(opts) == "table"` and `type(opts.notify) == "table"` before indexing fields.

---

## 3. Caveats

- Scope of this challenge was limited to M1 modules (`lua/herdr-agy/topology.lua`, `lua/herdr-agy/notify.lua`, `lua/herdr-agy/init.lua`).
- Did not modify implementation code directly, preserving review-only role.
- M2-M5 modules were out of scope for M1 review.

---

## 4. Conclusion

Verdict: **`REQUEST_CHANGES`**

Milestone 1 implementation contains 5 distinct vulnerability categories causing 10 unhandled Lua crashes and contract violations under stress testing. The implementation requires refactoring to handle malformed input data gracefully.

---

## 5. Verification Method

To independently verify all findings and reproduce the 10 failures:

1. Execute the stress test harness:
   ```bash
   nvim --headless -u NONE -c "luafile .agents/teamwork_preview_challenger_m1_1/stress_test.lua"
   ```

2. Confirm test summary output shows:
   ```
   ==========================================================
   STRESS TEST RESULTS: 11 Passed, 10 Failed
   ==========================================================
   ```
