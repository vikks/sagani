## 2026-08-01T09:16:44Z
<USER_REQUEST>
You are Worker M4 (teamwork_preview_worker) for Milestone 4 of project herdr-agy.nvim.
Working Directory: /Users/vikks/teamwork_projects/nvim_herdr_agy
Your Agent Directory: /Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_worker_m4_1

Tasks:
1. Read `/Users/vikks/teamwork_projects/nvim_herdr_agy/ORIGINAL_REQUEST.md`, `/Users/vikks/teamwork_projects/nvim_herdr_agy/PROJECT.md`, and Explorer handoff reports in `.agents/teamwork_preview_explorer_m4_1/handoff.md`, `.agents/teamwork_preview_explorer_m4_2/handoff.md`, and `.agents/teamwork_preview_explorer_m4_3/handoff.md`.
2. Implement `lua/herdr-agy/diff.lua`:
   - `diff.get_diff_hunk_at_cursor()`: Detect diff context (`diffview.nvim` active view, `vim.wo.diff` split diffs, or git diff), extract current file path, line numbers, and diff text snippet using `vim.diff()`.
   - `diff.send_diff_comment(opts)`: Prompt user via `vim.ui.input({ prompt = "AGY Diff Comment: " }, callback)`, build diff prompt via `format.build_diff_prompt(user_comment, diff_info)`, discover target AGY pane via `topology.discover_target_pane()`, and dispatch via `init.dispatch_prompt()`.
3. Implement `format.build_diff_prompt(user_comment, diff_info)` in `lua/herdr-agy/format.lua`:
   - Format markdown diff prompt with metadata (File Path, Line Range, Diff Code Block ````diff ````, User Comment).
4. Update `lua/herdr-agy/init.lua` to wire command `:HerdrAgyDiff` to `diff.send_diff_comment()`.
5. Implement `tests/test_diff.lua` and update `tests/run_tests.lua`:
   - Cover `get_diff_hunk_at_cursor()` and `send_diff_comment()` with mock diff buffers and `vim.ui.input` mocking.
6. Run full test suite headlessly to verify 100% pass:
   - `nvim --headless -u NONE -c "luafile tests/test_diff.lua"`
   - `nvim --headless -u NONE -c "luafile tests/test_format.lua"`
   - `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`
   Verify exit code 0 and 0 failures without hanging.
7. Write changes report to `.agents/teamwork_preview_worker_m4_1/changes.md` and handoff report to `.agents/teamwork_preview_worker_m4_1/handoff.md`. Send completion message to parent.

DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
</USER_REQUEST>
