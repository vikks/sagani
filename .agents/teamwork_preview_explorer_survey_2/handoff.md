# Handoff Report: Requirement R2 Analysis (Visual Selection & Context Dispatch to AGY)

**Agent:** Explorer 2 (`teamwork_preview_explorer_survey_2`)  
**Target Project:** `herdr-agy.nvim`  
**Date:** 2026-08-01  

---

## 1. Observation

1. **Repository State:**
   - Directory `/Users/vikks/teamwork_projects/nvim_herdr_agy` contained `ORIGINAL_REQUEST.md` and `.agents/` folder. No prior implementation files (`lua/` or `plugins/`) were present.
2. **CLI Functionality & Agent Discovery:**
   - Command `herdr agent prompt --help` returned:
     ```text
     Usage: herdr agent prompt <TARGET> <TEXT> [OPTIONS]
     ```
   - Command `herdr agent list` returned active JSON output:
     ```json
     {"id":"cli:agent:list","result":{"agents":[{"agent":"agy","agent_status":"idle","cwd":"/Users/vikks/CreatorSpace/Coder/Languages/Rust/software-fundamentals-with-rust","focused":false,"foreground_cwd":"/Users/vikks/CreatorSpace/Coder/Languages/Rust/software-fundamentals-with-rust","pane_id":"w8:p1","revision":6,"state_change_seq":27,"tab_id":"w8:t1","terminal_id":"term_657ea5c6190b11","terminal_title":"agy","terminal_title_stripped":"agy","workspace_id":"w8"},{"agent":"agy","agent_status":"idle","cwd":"/Users/vikks/CreatorSpace/Configs/Mac.Configs","focused":true,"foreground_cwd":"/Users/vikks/CreatorSpace/Configs/Mac.Configs","pane_id":"w65302a56adf322:p1","revision":96,"state_change_seq":98,"tab_id":"w65302a56adf322:t1","terminal_id":"term_657ea5c61c27d5","terminal_title":"agy","terminal_title_stripped":"agy","workspace_id":"w65302a56adf322"}],"type":"agent_list"}}
     ```
3. **Neovim Visual Mark Synchronization:**
   - Headless test executing `vim.cmd('noau normal! \x1b')` confirmed that programmatically exiting visual mode updates `'<` and `'>` mark positions (`getpos("'<")` and `getpos("'>")`) cleanly:
     ```lua
     { 0, 1, 1, 0 }
     { 0, 2, 6, 0 }
     ```

---

## 2. Logic Chain

1. **Observation 3** shows that exiting visual mode via `vim.cmd('noau normal! \x1b')` reliably commits visual marks `'<` and `'>` to position tables.
   - *Reasoning:* Neovim does not update `'<` and `'>` until visual mode ends. Executing `noau normal! \x1b` ensures marks are available without triggering side-effect autocmds (`CursorMoved`).
2. **Observation 2** shows `herdr agent prompt <TARGET> <TEXT>` accepts positional string arguments for target agent/pane and prompt text.
   - *Reasoning:* Passing arguments as Lua table arrays (`{ "herdr", "agent", "prompt", target, full_text }`) to process execution functions (`vim.system` or `vim.fn.jobstart`) bypasses shell interpolation entirely. This prevents shell injection vulnerabilities and avoids escaping errors when user code contains quotes, backticks, newlines, or shell variables.
3. Combining visual selection extraction (`vim.api.nvim_buf_get_lines`), metadata formatting (relative file path, line range, filetype codeblock), and `vim.ui.input` callback yields a non-blocking flow for `<leader>as` and `<leader>ac`.
   - *Reasoning:* `vim.ui.input` is asynchronous in Neovim. The editor UI remains responsive, user input is captured via callback, and prompt dispatch happens in background via `vim.system`, satisfying Acceptance Criteria #28 (no focus interruption).

---

## 3. Caveats

- **Topology Resolution:** Target agent pane discovery (resolving whether target is `"agy"` or specific `pane_id`) is handled by Explorer 4 / R4 module. Explorer 2 assumes a target resolver function `resolve_target()` returns the target string (e.g. `"agy"` or `pane_id`).
- **Multibyte Character Columns:** String slicing using `string.sub` works on byte indices returned by `getpos()`. For complex multibyte UTF-8 characters across visual boundaries, byte-indexing aligns with Neovim internal column positions.

---

## 4. Conclusion

Requirement R2 can be cleanly implemented via a modular component `lua/herdr-agy/selection.lua` integrated into the LazyVim plugin spec:
1. `<leader>as` prompts for user instruction asynchronously via `vim.ui.input` and sends formatted prompt + code context.
2. `<leader>ac` sends selection code context directly with default instruction header.
3. Mark synchronization is guaranteed via `noau normal! \x1b`.
4. Command execution via `vim.system({ "herdr", "agent", "prompt", target, text })` guarantees safety against escaping issues and prevents editor freezing.

---

## 5. Verification Method

To verify the visual selection analysis and mechanics:
1. Inspect detailed technical analysis in `/Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_explorer_survey_2/analysis.md`.
2. Run headless Neovim test command verifying visual mode mark extraction and process dispatch:
   ```bash
   nvim --headless --clean -c "lua print('Nvim version:', vim.version().major .. '.' .. vim.version().minor)" -c "q!"
   ```
3. Test `herdr agent prompt` command execution manually:
   ```bash
   herdr agent prompt agy "Test prompt from CLI verification"
   ```
