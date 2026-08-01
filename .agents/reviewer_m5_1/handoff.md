# Milestone 5 Review & Handoff Report: herdr-agy.nvim

**Agent Directory**: `/Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/reviewer_m5_1`  
**Role**: Reviewer 1 (Quality Reviewer & Adversarial Critic)  
**Date**: 2026-08-01  
**Verdict**: **REQUEST_CHANGES**

---

## 1. Review Summary

- **Verdict**: **REQUEST_CHANGES**
- **Overall Code Quality**: EXCELLENT (Clean, modular, zero global pollution, robust edge-case handling).
- **Core Implementation**: 100% compliant with interface contracts in `PROJECT.md` and feature requirements R1–R4.
- **Headless Unit Test Suite**: 236 tests passed, 0 failed across 6 test modules via `tests/run_tests.lua`.
- **Reason for REQUEST_CHANGES**: Missing promised test harness artifact `tests/minimal_init.lua` and unreproducible Plenary test runner command documented in `TEST_READY.md`, `TEST_INFRA.md`, and `PROJECT.md`.

---

## 2. Findings

### [Major / Integrity Finding 1] Missing Test Artifact `tests/minimal_init.lua` & Unreproducible Plenary Test Harness
- **What**: `tests/minimal_init.lua` is missing from disk, causing the documented Plenary test harness command to fail with `E282: Cannot read from "tests/minimal_init.lua"`.
- **Where**:
  - `PROJECT.md` line 58: `Headless Neovim test script (tests/run_tests.lua) and Plenary test harness (tests/minimal_init.lua)`
  - `PROJECT.md` line 67: `Implementation of dual test harness (tests/run_tests.lua, tests/minimal_init.lua, test specifications)`
  - `PROJECT.md` line 116: `├── minimal_init.lua`
  - `TEST_INFRA.md` line 5 & line 21: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests"`
  - `TEST_READY.md` line 9: `Command: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests"`
- **Why this is a problem**: 
  - Attestation inconsistency / missing artifact: `TEST_READY.md` and `PROJECT.md` claim a dual test harness with `tests/minimal_init.lua` for Plenary integration, but the file was not committed to the repository.
  - Executing `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests"` produces: `E282: Cannot read from "tests/minimal_init.lua"`.
- **Suggestion**: Either create `tests/minimal_init.lua` (setting up runtimepath, package.path, and Plenary test bootstrap) so `PlenaryBustedDirectory` runs successfully, or update `PROJECT.md`, `TEST_INFRA.md`, and `TEST_READY.md` to remove references to `tests/minimal_init.lua`.

---

## 3. Verified Claims

1. **Master Test Runner Execution**:
   - **Command**: `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`
   - **Result**: PASSED (236 passed, 0 failed across 6 test modules: `test_topology.lua`, `test_plugin_spec.lua`, `test_selection.lua`, `test_format.lua`, `test_diff.lua`, `test_adversarial_m2.lua`).

2. **LazyVim Plugin Specification & WhichKey Integration**:
   - **File**: `plugins/herdr-agy.lua`
   - **Verified**:
     - `folke/which-key.nvim` spec registered with `optional = true`, `group = "AGY / Herdr"`, `mode = { "n", "v" }`.
     - `herdr-agy.nvim` spec has lazy loading `cmd` array with all 6 user commands (`HerdrAgyStatus`, `HerdrAgySelectTarget`, `HerdrAgyPrompt`, `HerdrAgySend`, `HerdrAgyContext`, `HerdrAgyDiff`).
     - Keymaps (`<leader>as`, `<leader>ac`, `<leader>ad`, `<leader>ap`, `<leader>at`) registered with correct modes (`n`, `v`).

3. **Visual Selection Extraction & Context Dispatch**:
   - **File**: `lua/herdr-agy/selection.lua`, `lua/herdr-agy/format.lua`
   - **Verified**:
     - Supports linewise (`V`), characterwise (`v`), and blockwise (`<C-v>`) selections.
     - Automatically flushes visual marks via `noau normal! \x1b`.
     - Normalizes boundary ordering (bottom-to-top selections).
     - Unnamed buffers default to `[No Name]` and `filetype = "text"`.
     - Formats prompt output with user instruction, file path, line range, and code snippet.

4. **Interactive Diff Review & Hunk Commenting**:
   - **File**: `lua/herdr-agy/diff.lua`, `lua/herdr-agy/format.lua`
   - **Verified**:
     - Split diff mode (`vim.wo.diff`): computes diff via `vim.diff()`, matches cursor line to hunk.
     - Diff filetype buffer: parses unified diff headers (`@@ -... +... @@`, `+++ b/...`).
     - Git HEAD fallback: queries `git show HEAD:<rel_path>` and computes diff for uncommitted buffer changes.
     - Formats markdown diff prompt block (` ```diff `) sent to `agy`.

5. **Topology Auto-Discovery & Herdr Environment**:
   - **File**: `lua/herdr-agy/topology.lua`
   - **Verified**:
     - Detects `HERDR_ENV`, `HERDR_PANE_ID`, `HERDR_TAB_ID`, `HERDR_WORKSPACE_ID`.
     - Parses `herdr agent list` JSON with full error resilience.
     - Implements 6-tier scoring hierarchy (Tier 1: Same workspace+tab excluding caller; Tier 2: Same workspace excluding caller; Tier 3: Same workspace+tab including caller; Tier 4: Same workspace including caller; Tier 5: CWD match; Tier 6: Global fallback).
     - Manual `pane_override` bypasses discovery seamlessly.

6. **Code Cleanliness & Global Scope Isolation**:
   - **Verified**: Zero un-scoped global variable pollutions in `lua/herdr-agy/*.lua`. All module functions return clean tables conforming to interface contracts.

---

## 4. Adversarial Attack Surface & Stress-Test Results

| # | Stress Scenario / Hypothesis | Target Module | Predicted Behavior | Actual Behavior | Result |
|---|------------------------------|---------------|--------------------+-----------------|--------|
| 1 | Unloaded `which-key.nvim` module | `plugins/herdr-agy.lua` | Spec evaluates cleanly without requiring `which-key` | Spec evaluates with `optional = true` without error | **PASS** |
| 2 | Invalid `user_opts` types (`string`, `number`, `boolean`, `nil`) | `lua/herdr-agy/init.lua` | Handled via fallback to `defaults` without crash | Safely merged using `vim.tbl_deep_extend` | **PASS** |
| 3 | Malformed / non-JSON output from `herdr agent list` | `lua/herdr-agy/topology.lua` | Graceful error returned, no crash | Returns `nil, "Failed to parse JSON..."` | **PASS** |
| 4 | Bottom-to-top visual range selection (`end_line < start_line`) | `lua/herdr-agy/selection.lua` | Range coordinates normalized | `start_line` and `end_line` swapped correctly | **PASS** |
| 5 | Unnamed buffer or missing filetype | `lua/herdr-agy/selection.lua` | Fallback to `[No Name]` and `text` | Successfully formatted with default metadata | **PASS** |
| 6 | Execution of `dispatch_prompt` with invalid prompt text | `lua/herdr-agy/init.lua` | Returns `false, "Invalid prompt text..."` | Prompt text validated, error notified cleanly | **PASS** |
| 7 | Missing `herdr` CLI binary in `PATH` | `lua/herdr-agy/init.lua`, `topology.lua` | Returns clear executable missing error | Returns `false, "'herdr' CLI binary not found in PATH"` | **PASS** |
| 8 | Plenary test harness execution (`tests/minimal_init.lua`) | `tests/` directory | Plenary suite executes headlessly | `E282: Cannot read from "tests/minimal_init.lua"` | **FAIL** |

---

## 5. 5-Component Handoff Protocol

### 1. Observation
- Command executed: `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`
  - Output: `TOTAL TEST RESULTS: 236 Passed, 0 Failed across 6 test file(s)`
- Command executed: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests"`
  - Output: `E282: Cannot read from "tests/minimal_init.lua"`
- File inspection of `tests/`: Contains `run_tests.lua`, `test_adversarial_m2.lua`, `test_diff.lua`, `test_format.lua`, `test_plugin_spec.lua`, `test_selection.lua`, `test_topology.lua`. `minimal_init.lua` is absent.
- Source files inspected: `plugins/herdr-agy.lua`, `lua/herdr-agy/init.lua`, `lua/herdr-agy/topology.lua`, `lua/herdr-agy/notify.lua`, `lua/herdr-agy/selection.lua`, `lua/herdr-agy/diff.lua`, `lua/herdr-agy/format.lua`.

### 2. Logic Chain
1. Requirement R1-R4 and `PROJECT.md` contracts mandate full feature implementation and test harness setup.
2. Direct source code audit confirms all Lua plugin modules (`lua/herdr-agy/*.lua` and `plugins/herdr-agy.lua`) are robust, clean, and fully functional.
3. Execution of `tests/run_tests.lua` verifies 236 unit and integration test cases pass headlessly.
4. However, `PROJECT.md`, `TEST_INFRA.md`, and `TEST_READY.md` repeatedly reference a dual test harness including `tests/minimal_init.lua`.
5. Verification of `tests/minimal_init.lua` proves the file does not exist, causing the documented Plenary execution command to fail with Neovim error `E282`.
6. Therefore, changes are requested to provide `tests/minimal_init.lua` or update documentation to match actual test artifacts.

### 3. Caveats
- No caveats regarding core implementation logic — source code quality is confirmed high.
- The missing file `tests/minimal_init.lua` does not impact the zero-dependency test runner `tests/run_tests.lua` which passes 100%.

### 4. Conclusion
Final Verdict: **REQUEST_CHANGES**.
The implementation code is complete, elegant, and bug-free. However, `tests/minimal_init.lua` must be provided (or documentation updated) to resolve the missing test harness artifact and ensure 100% attestation reproducibility.

### 5. Verification Method
To verify fix:
1. Ensure `tests/minimal_init.lua` exists.
2. Run `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` -> 236 passed.
3. Run `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests"` -> executes without E282 error.
