# Handoff Report — Milestone 3: Visual Selection & Context Dispatch to AGY

**Author:** Explorer M3  
**Target Repository:** `herdr-agy.nvim`  
**Date:** 2026-08-01  

---

## 1. Observation

1. **Original Requirements & Scope**:
   - `ORIGINAL_REQUEST.md`, Requirement R2 (lines 14-16): "Provide visual mode keymaps (`<leader>as` / `<leader>ac`) to send selected code, file path, line numbers, filetype, and user instructions directly to the `agy` agent in an adjacent `herdr` right pane via `herdr agent prompt`."
   - `PROJECT.md`, Feature F5 & F6 (lines 54-56): "F5: Visual Selection Extraction (Robust extraction of visual selection handling characterwise (`v`), linewise (`V`), and blockwise (`<C-v>`) with mark normalization)" and "F6: Context Dispatch to AGY (Format selection context with user input (`vim.ui.input`), dispatch via `vim.system`)".
   - `PROJECT.md`, Interface Contracts (lines 81-84 & 90):
     - `selection.get_visual_selection()` -> `{ snippet = string, start_line = number, end_line = number, start_col = number, end_col = number, mode = string, file_path = string, filetype = string }`
     - `selection.send_selection_prompt(opts)` -> `void`
     - `selection.send_code_context(opts)` -> `void`
     - `format.build_context_prompt(user_instruction, selection)` -> `string`

2. **Existing Implementation Analysis**:
   - `lua/herdr-agy/init.lua` line 67-69 currently contains stub for `HerdrAgySend`:
     ```lua
     vim.api.nvim_create_user_command("HerdrAgySend", function()
       notify.info("HerdrAgySend triggered (Visual selection handler will be active in M3)", M.options)
     end, { range = true, desc = "Send selection to AGY" })
     ```
   - `lua/herdr-agy/format.lua` and `lua/herdr-agy/selection.lua` do not currently exist in `lua/herdr-agy/`.
   - `tests/test_format.lua` and `tests/test_selection.lua` do not currently exist in `tests/`.

3. **Master Test Infrastructure**:
   - `tests/run_tests.lua` executes all `test_*.lua` files in `tests/` directory headlessly via `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`.
   - Existing test suites `tests/test_topology.lua`, `tests/test_plugin_spec.lua`, and `tests/test_adversarial_m2.lua` follow the module pattern returning `{ passed = number, failed = number, failures = table }`.

---

## 2. Logic Chain

1. **Step 1 (Context Prompt Formatting)**:  
   Based on Observation 1 and survey explorer 2 analysis (`.agents/teamwork_preview_explorer_survey_2/analysis.md`), `format.build_context_prompt(user_instruction, selection)` must format the Markdown prompt payload as:
   ```markdown
   <user_instruction>

   Context from `<file_path>` (<line_range>):
   ```<filetype>
   <code_snippet>
   ```
   ```
   Line range must display as `L<start>` when single line and `L<start>-L<end>` when multi-line. Unnamed buffers default to `[No Name]`, empty filetypes default to `text`, and missing snippets default to `""`.

2. **Step 2 (Visual Selection Extraction & Normalization)**:  
   Based on Observation 1, extracting visual selection in Neovim requires:
   - Exiting visual mode with `vim.cmd([[noau normal! \x1b]])` to flush position marks `'<` and `'>`.
   - Reading `vim.fn.visualmode()` to differentiate characterwise (`v`), linewise (`V`), and blockwise (`\22` / `<C-v>`).
   - Normalizing positions so `start_line` <= `end_line` and `start_col` <= `end_col` (for single line / blockwise rectangle).
   - Fetching buffer lines with `vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)` and applying character/block slicing routines.
   - Reading buffer path with `fnamemodify(..., ":~:.")` and buffer filetype with `vim.bo[bufnr].filetype`.

3. **Step 3 (Interactive User Prompt & Context Dispatch)**:  
   Based on Observation 1 & 2, `send_selection_prompt(opts)` prompts the user asynchronously using `vim.ui.input({ prompt = "AGY Instruction: " })`. If the user submits non-empty text, it builds the formatted payload using `format.build_context_prompt` and invokes `require("herdr-agy").dispatch_prompt(payload, nil, opts)`. `send_code_context(opts)` dispatches directly using `"Context snippet for review:"` as the default prompt.

4. **Step 4 (Command Routing)**:  
   Based on Observation 2, `:HerdrAgySend` in `lua/herdr-agy/init.lua` must be updated from its M3 stub to call `require("herdr-agy.selection").send_selection_prompt(M.options)`.

5. **Step 5 (Testing & Verification)**:  
   Based on Observation 3, creating `tests/test_format.lua` (8 test cases) and `tests/test_selection.lua` (10 test cases) ensures complete test coverage across Tier 1 (Feature), Tier 2 (Boundary), and Tier 4 (Real-World) scenarios.

---

## 3. Caveats

- **Headless Visual Mode Simulation**: In headless Neovim unit test execution without an active GUI or terminal window, visual mode marks `'<` and `'>` must be set via `vim.fn.setpos()` or simulated by setting buffer cursor positions and visual mode overrides.
- **Multibyte Character Slicing**: Column position marks from `getpos()` return byte indices rather than UTF-32 character offsets. Lua's `string.sub` works directly on byte indices, which matches Neovim's byte position marks.

---

## 4. Conclusion

The technical design and implementation blueprint for Milestone 3 (Visual Selection & Context Dispatch to AGY) is fully specified and documented in `.agents/teamwork_preview_explorer_m3/analysis.md`. The design fulfills all requirements of R2, F5, and F6 with complete code implementations for `format.lua`, `selection.lua`, `init.lua` updates, `test_format.lua`, and `test_selection.lua`.

---

## 5. Verification Method

To verify the proposed implementation after implementer deployment:

1. **Inspect Analysis Blueprint**:
   - Inspect `.agents/teamwork_preview_explorer_m3/analysis.md` for complete Lua module implementations and test specifications.

2. **Run Headless Test Runner**:
   ```bash
   nvim --headless -u NONE -c "luafile tests/run_tests.lua"
   ```
   - **Verification Pass Criteria**: All test suites pass with 0 failures.

3. **Invalidation Conditions**:
   - `build_context_prompt` failing to produce `L<start>-L<end>` line range formatting.
   - Reverse selection (bottom-to-top) throwing negative index or out-of-range errors during `string.sub`.
   - `send_selection_prompt` attempting to dispatch when `vim.ui.input` is cancelled with `nil` or empty input.
