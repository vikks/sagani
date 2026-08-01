## 2026-08-01T11:52:32Z
You are Explorer M3 for Milestone 3 (Visual Selection & Context Dispatch to AGY) of project herdr-agy.nvim.
Working Directory: /Users/vikks/teamwork_projects/nvim_herdr_agy
Your Agent Directory: /Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_explorer_m3

Tasks:
1. Read `ORIGINAL_REQUEST.md`, `PROJECT.md`, and survey explorer 2 analysis at `.agents/teamwork_preview_explorer_survey_2/analysis.md`.
2. Provide implementation details and test blueprints for:
   - `lua/herdr-agy/format.lua`:
     - `build_context_prompt(user_instruction, selection)` -> string format: `<user_instruction>\n\nContext from \`<file_path>\` (<line_range>):\n\`\`\`<filetype>\n<code_snippet>\n\`\`\``
   - `lua/herdr-agy/selection.lua`:
     - `get_visual_selection(bufnr)`: Exits visual mode cleanly (`vim.cmd([[noau normal! \x1b]])`), queries `vim.fn.visualmode()`, gets position tuples for `'<` and `'>`, normalizes boundaries for bottom-to-top selection, extracts snippet for characterwise (`v`), linewise (`V`), and blockwise (`<C-v>`), extracts relative file path and filetype.
     - `send_selection_prompt(opts)` & `send_code_context(opts)`: Retrieve selection, prompt user via `vim.ui.input({ prompt = "AGY Instruction: " }, callback)`, build formatted payload via `format.build_context_prompt`, and dispatch via `require("herdr-agy").dispatch_prompt(payload, nil, opts)`.
   - Update `lua/herdr-agy/init.lua` to route `:HerdrAgySend` to `selection.send_selection_prompt()`.
   - `tests/test_format.lua` & `tests/test_selection.lua`: Unit test suites for formatting and visual selection mechanics (with headless buffer creation and mock `vim.ui.input` callbacks).
3. Write detailed analysis to `.agents/teamwork_preview_explorer_m3/analysis.md` and handoff report to `.agents/teamwork_preview_explorer_m3/handoff.md`. Send completion message to parent.
