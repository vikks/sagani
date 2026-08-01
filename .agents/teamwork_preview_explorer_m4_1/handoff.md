# Handoff Report: Milestone 4 Explorer Investigation

## 1. Observation
- **Codebase Audit**:
  - `lua/herdr-agy/format.lua` lines 40-64: `build_diff_prompt(user_comment, diff_info)` is already implemented, expecting `diff_info = { file_path = string, start_line = number, end_line = number, diff_text = string }`.
  - `lua/herdr-agy/init.lua` line 80: `:HerdrAgyDiff` user command currently calls a placeholder notification (`notify.info("HerdrAgyDiff triggered...")`).
  - `plugins/herdr-agy.lua` line 32: `<leader>ad` maps to `:HerdrAgyDiff<cr>`.
  - `lua/herdr-agy/diff.lua`: File does not yet exist.
- **Environment & Tool Verification**:
  - Neovim version observed: `0.12.3` (`vim.version()`).
  - Master test runner command executed: `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`.
  - Result: `205 Passed, 0 Failed across 5 test file(s)`.
  - `vim.diff()` evaluation: `vim.diff(old, new, { result_type = "indices" })` returns `{ { sa, ca, sb, cb }, ... }` with 1-indexed line numbers.
  - `git status` executed in working directory: `fatal: not a git repository`.

## 2. Logic Chain
1. **Observation**: `format.build_diff_prompt` expects a table with `{ file_path, start_line, end_line, diff_text }`.
2. **Logic Step 1**: `diff.get_diff_hunk_at_cursor()` must return a table with matching field keys so that its return value can be directly passed into `format.build_diff_prompt`.
3. **Observation**: Neovim provides `vim.wo.diff` for split diff windows, `diffview.lib` / `diffview://` URI schemes for `diffview.nvim` integration, and `git show HEAD:<file>` for uncommitted changes.
4. **Logic Step 2**: `diff.lua` should implement a 3-tiered context resolution pipeline (`diffview` -> `vim.wo.diff` split -> `git show HEAD` fallback) to extract base/old lines vs target/new lines.
5. **Observation**: `vim.diff(base, target, { result_type = "indices" })` outputs hunk index tuples `{ sa, ca, sb, cb }`.
6. **Logic Step 3**: Mapping cursor line `cur_line` to target range `[sb, sb + math.max(0, cb - 1)]` enables exact or nearest hunk selection around cursor position.
7. **Observation**: `send_diff_comment(opts)` receives user input via `vim.ui.input`, formats the diff prompt via `format.build_diff_prompt`, and dispatches it via `require("herdr-agy").dispatch_prompt`.
8. **Conclusion**: Requirements and function signatures for `lua/herdr-agy/diff.lua` are fully specified and ready for implementation.

## 3. Caveats
- **Non-Git Working Directory**: The current working directory is not a Git repo. The `git show HEAD` fallback logic in `diff.lua` must handle non-zero exit codes (`res.code ~= 0`) gracefully without crashing.
- **Headless Test Environment**: `diffview.nvim` is not installed in the headless Neovim test environment. Unit tests in `tests/test_diff.lua` must mock `pcall(require, "diffview.lib")` or focus on testing `vim.wo.diff` split diffs and index extraction logic.

## 4. Conclusion
The implementation plan for Milestone 4 Requirement R3 (Interactive Diff Review & Inline Commenting) is complete. The function contracts for `diff.get_diff_hunk_at_cursor()` and `diff.send_diff_comment(opts)` adhere to `PROJECT.md § Interface Contracts` and seamlessly integrate with `format.lua`, `topology.lua`, `init.lua`, and `notify.lua`.

## 5. Verification Method
1. Run master test suite:
   ```bash
   nvim --headless -u NONE -c "luafile tests/run_tests.lua"
   ```
2. Verify contract signatures in `PROJECT.md` (lines 86-89):
   - `diff.get_diff_hunk_at_cursor()` -> `{ file_path = string, start_line = number, end_line = number, diff_text = string }|nil`
   - `diff.send_diff_comment(opts)` -> void
3. Inspect `analysis.md` in `.agents/teamwork_preview_explorer_m4_1/analysis.md` for complete technical specifications.
