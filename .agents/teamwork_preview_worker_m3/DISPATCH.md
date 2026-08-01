## 2026-08-01T11:53:33Z
You are Worker M3 (teamwork_preview_worker) for Milestone 3 of project herdr-agy.nvim.
Working Directory: /Users/vikks/teamwork_projects/nvim_herdr_agy
Your Agent Directory: /Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_worker_m3

Tasks:
1. Read `ORIGINAL_REQUEST.md`, `PROJECT.md`, and `.agents/teamwork_preview_explorer_m3/analysis.md`.
2. Implement `lua/herdr-agy/format.lua`:
   - `build_context_prompt(user_instruction, selection)`: Format markdown instruction + relative file path + line range (`L<start>` or `L<start>-L<end>`) + fenced filetype codeblock.
   - `build_diff_prompt(user_comment, diff_info)`: Format markdown diff payload + relative file path + line range + fenced `diff` codeblock.
3. Implement `lua/herdr-agy/selection.lua`:
   - `get_visual_selection(bufnr)`: Flush marks via `vim.cmd([[noau normal! \x1b]])`, query `visualmode()`, get `'<` and `'>` positions, normalize start/end bounds for bottom-to-top selection, extract snippet for characterwise (`v`), linewise (`V`), and blockwise (`<C-v>`), extract relative file path and filetype.
   - `send_selection_prompt(opts)` & `send_code_context(opts)`: Prompt user via `vim.ui.input`, format via `format.build_context_prompt`, dispatch via `require("herdr-agy").dispatch_prompt(payload, nil, opts)`.
4. Update `lua/herdr-agy/init.lua` to route `:HerdrAgySend` to `selection.send_selection_prompt()`.
5. Implement `tests/test_format.lua` and `tests/test_selection.lua` unit test suites covering single/multi-line formatting, unnamed buffers, filetype fallbacks, `v`/`V`/`<C-v>` selection extraction, boundary normalizations, and mock `vim.ui.input` prompt dispatches.
6. Run test commands:
   `nvim --headless -u NONE -c "luafile tests/test_format.lua"`
   `nvim --headless -u NONE -c "luafile tests/test_selection.lua"`
   `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`
7. Verify 100% tests pass cleanly with exit code 0. Write changes report to `.agents/teamwork_preview_worker_m3/changes.md` and handoff report to `.agents/teamwork_preview_worker_m3/handoff.md`. Send completion message to parent.
