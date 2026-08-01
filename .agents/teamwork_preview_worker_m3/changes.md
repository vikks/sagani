# Milestone 3 Changes Report

## Overview of Changes

Milestone 3 implements Requirement R2 of `herdr-agy.nvim`: Visual Selection & Context Dispatch to AGY.

### Modified & Created Files

1. **`lua/herdr-agy/format.lua`** (Created)
   - Implemented `format.build_context_prompt(user_instruction, selection)`:
     - Transforms visual selection metadata into formatted Markdown context blocks.
     - Formats line ranges as `L<line>` (single line) or `L<start>-L<end>` (multi-line).
     - Handles default fallbacks for `file_path` (`"[No Name]"`), `filetype` (`"text"`), `user_instruction` (`"Context snippet for review:"`), and `snippet` (`""`).
   - Implemented `format.build_diff_prompt(user_comment, diff_info)`:
     - Formats diff metadata into formatted Markdown diff blocks (` ```diff `).
     - Handles default fallbacks for `file_path` (`"[No Name]"`), `user_comment` (`"Diff review comment:"`), and `diff_text` (`""`).

2. **`lua/herdr-agy/selection.lua`** (Created)
   - Implemented `selection.get_visual_selection(bufnr)`:
     - Flushes position marks `'<` and `'>` by executing `vim.cmd([[noau normal! \x1b]])`.
     - Queries `vim.fn.visualmode()`.
     - Retrieves position marks `getpos("'<")` and `getpos("'>")` with cursor position fallbacks.
     - Normalizes boundary ordering for bottom-to-top and right-to-left visual selections.
     - Extracts snippet text according to visual mode:
       - Linewise (`V`): Joins full lines without column clipping.
       - Characterwise (`v`): Slices start line from `start_col`, end line to `end_col`, joins lines with `\n`.
       - Blockwise (`<C-v>` / `\22`): Slices rectangle between `min_col` and `max_col` across lines.
     - Extracts relative file path (`vim.fn.fnamemodify(..., ":~:.")`) and buffer filetype (`vim.bo[bufnr].filetype`).
   - Implemented `selection.send_selection_prompt(opts)`:
     - Queries current visual selection.
     - Prompts user via non-blocking `vim.ui.input({ prompt = "AGY Instruction: " })`.
     - Formats prompt with `format.build_context_prompt` and dispatches via `herdr-agy.dispatch_prompt`.
     - Gracefully handles empty input or cancellation.
   - Implemented `selection.send_code_context(opts)`:
     - Queries visual selection and dispatches with default context review prompt.

3. **`lua/herdr-agy/init.lua`** (Updated)
   - Required `herdr-agy.format` and `herdr-agy.selection`.
   - Routed `:HerdrAgySend` to `selection.send_selection_prompt(M.options)`.
   - Added `:HerdrAgyContext` command routing to `selection.send_code_context(M.options)`.
   - Exposed `M.format` and `M.selection` on the main module export table.

4. **`tests/test_format.lua`** (Created)
   - Unit test suite testing single-line formatting (`L10`), multi-line formatting (`L10-L25`), unnamed buffers (`[No Name]`), empty filetype fallback (`text`), verbatim special character preserving, nil instruction defaults, nil table safety, and diff prompt formatting.

5. **`tests/test_selection.lua`** (Created)
   - Unit test suite testing visual selection extraction across all 3 visual modes (`v`, `V`, `<C-v>`), bottom-to-top boundary normalization, unnamed buffers, user prompt dispatches with mock `vim.ui.input`, prompt cancellation, and direct context dispatches.

## Verification Results

Executed:
1. `nvim --headless -u NONE -c "luafile tests/test_format.lua"` -> 10 Passed, 0 Failed
2. `nvim --headless -u NONE -c "luafile tests/test_selection.lua"` -> 23 Passed, 0 Failed
3. `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` -> 193 Passed, 0 Failed across 5 test suites.
