# Handoff Report: Explorer 3 Survey (R3 & Testing Setup)
**Project**: `herdr-agy.nvim`
**Agent**: Explorer 3 (`teamwork_preview_explorer_survey_3`)
**Date**: 2026-08-01

---

## 1. Observation

1. **Original Request File**:
   - Path: `/Users/vikks/teamwork_projects/nvim_herdr_agy/ORIGINAL_REQUEST.md`
   - Key requirement R3 (lines 17-18): "Provide diff review integration with `diffview.nvim` or LazyVim's built-in diff views, allowing the user to select diff ranges, add comments, and send structured diff feedback back to `agy`."
   - Acceptance criteria (line 29): "Diff comments format cleanly as markdown diff blocks sent to `agy`."

2. **System Environment Binaries & Tooling**:
   - Executed `which nvim herdr agy lua luarocks busted pytest`:
     - Neovim: `/opt/homebrew/bin/nvim` (NVIM v0.12.3, LuaJIT 2.1)
     - Herdr: `/opt/homebrew/bin/herdr` (herdr 0.7.5)
     - AGY: `/Users/vikks/.local/bin/agy` (1.1.9)
     - Plenary: Installed at `/Users/vikks/.local/share/nvim/lazy/plenary.nvim`

3. **Neovim API Capabilities**:
   - Built-in unified diff generation via `vim.diff(s1, s2, { result_type = "unified" })` tested successfully in headless Neovim v0.12.3.
   - Buffer line retrieval via `vim.api.nvim_buf_get_lines()` and visual position capture via `vim.fn.getpos("v")` / `vim.fn.getpos(".")` confirmed working.

4. **Testing Setup Capabilities**:
   - `nvim --headless` executes inline Lua and script files natively.
   - `plenary.nvim` is available at `/Users/vikks/.local/share/nvim/lazy/plenary.nvim` and loads via `require("plenary.busted")`.

---

## 2. Logic Chain

1. **From Observation 1 & 3**: Requirement R3 demands interactive diff review, inline commenting, markdown payload formatting, and dispatching.
   - `diffview.nvim` provides tab/window context accessible via `require("diffview.lib").get_current_view()`.
   - Neovim built-in diff split views use `vim.wo.diff = true` across split windows.
   - Using Neovim's `vim.diff()`, unified diff hunks can be computed dynamically for any line range or buffer pair, ensuring compatibility with `diffview.nvim`, `gitsigns.nvim`, and built-in Neovim diff views.

2. **From Observation 3**: Formatting diff feedback as structured markdown:
   - Header with file path and line numbers.
   - Code block with ````diff ```` fencing.
   - User comment section captured via `vim.ui.input` (which integrates with LazyVim's `dressing.nvim` / `snacks.input`).
   - The formatted string is passed to `herdr agent prompt --pane <target> "<payload>"`.

3. **From Observation 2 & 4**: For testing setup:
   - Headless Neovim (`nvim --headless`) supports executing unit and integration tests cleanly in CI / CLI.
   - `plenary.nvim` is pre-installed in `/Users/vikks/.local/share/nvim/lazy/plenary.nvim`.
   - A standalone headless test script (`tests/run_tests.lua`) provides zero-dependency execution, while `tests/minimal_init.lua` enables standard `PlenaryBustedDirectory` test suites.

---

## 3. Caveats

- `diffview.nvim` is an optional plugin in LazyVim installations; therefore, `herdr-agy.nvim` must check `package.loaded["diffview"]` dynamically and fall back gracefully to `vim.wo.diff` or normal buffer line extraction.
- In headless CLI mode, `vim.ui.input` requires mocking or direct argument passing in unit tests since interactive user prompts cannot run headless.

---

## 4. Conclusion

- **R3 Architecture**: Can be implemented in `lua/herdr-agy/diff.lua` and `lua/herdr-agy/format.lua`, supporting `diffview.nvim`, `gitsigns.nvim`, and Neovim split diff views with a unified fallback to single-buffer code comments.
- **Testing Architecture**: Recommend a dual testing harness supporting both `plenary.nvim` (`PlenaryBustedDirectory`) and zero-dependency headless Neovim test scripts (`nvim --headless -u NONE -c "luafile tests/run_tests.lua"`).
- Detailed analysis has been saved to `.agents/teamwork_preview_explorer_survey_3/analysis.md`.

---

## 5. Verification Method

1. **Inspect Analysis Report**:
   ```bash
   cat /Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_explorer_survey_3/analysis.md
   ```
2. **Verify Headless Neovim Execution**:
   ```bash
   nvim --headless -u NONE -c "lua print(vim.diff('a\n', 'b\n'))" -c "q"
   ```
3. **Verify Plenary Loading**:
   ```bash
   nvim --headless -c "set rtp+=~/.local/share/nvim/lazy/plenary.nvim" -c "lua require('plenary.busted')" -c "q"
   ```
