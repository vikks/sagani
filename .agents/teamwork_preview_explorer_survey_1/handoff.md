# Handoff Report: Requirements R1 & R4 Analysis

**Agent**: Explorer 1  
**Project**: `herdr-agy.nvim`  
**Date**: 2026-08-01  
**Handoff Type**: Hard (Task Complete)  
**Target Path**: `/Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_explorer_survey_1/handoff.md`

---

## 1. Observation

- **Repository Directory**: `/Users/vikks/teamwork_projects/nvim_herdr_agy`
  - Initial repository state: Greenfield repo containing only `ORIGINAL_REQUEST.md`.
  - System Neovim version: `NVIM v0.12.3` (LuaJIT 2.1.1781602682).
  - Environment binaries:
    - `/opt/homebrew/bin/herdr`
    - `/Users/vikks/.local/bin/agy`
    - `/opt/homebrew/bin/nvim`
- **Live Herdr Environment Inspection**:
  - `HERDR_ENV=1`
  - `HERDR_PANE_ID=w65302a56adf322:p1`
  - `HERDR_TAB_ID=w65302a56adf322:t1`
  - `HERDR_WORKSPACE_ID=w65302a56adf322`
  - `HERDR_SOCKET_PATH=/Users/vikks/.config/herdr/herdr.sock`
- **Herdr CLI Output Verification**:
  - Command: `herdr agent list`
  - Sample Output:
    ```json
    {"id":"cli:agent:list","result":{"agents":[{"agent":"agy","agent_status":"idle","cwd":"/Users/vikks/CreatorSpace/Coder/Languages/Rust/software-fundamentals-with-rust","focused":false,"foreground_cwd":"/Users/vikks/CreatorSpace/Coder/Languages/Rust/software-fundamentals-with-rust","pane_id":"w8:p1","revision":6,"state_change_seq":27,"tab_id":"w8:t1","terminal_id":"term_657ea5c6190b11","terminal_title":"agy","terminal_title_stripped":"agy","workspace_id":"w8"},{"agent":"agy","agent_status":"idle","cwd":"/Users/vikks/CreatorSpace/Configs/Mac.Configs","focused":true,"foreground_cwd":"/Users/vikks/CreatorSpace/Configs/Mac.Configs","pane_id":"w65302a56adf322:p1","revision":96,"state_change_seq":98,"tab_id":"w65302a56adf322:t1","terminal_id":"term_657ea5c61c27d5","terminal_title":"agy","terminal_title_stripped":"agy","workspace_id":"w65302a56adf322"}],"type":"agent_list"}}
    ```
  - Command: `herdr pane list`
    - Returns JSON structure containing array of 13 active panes across workspaces (`type: "pane_list"`).
- **Neovim Lua Compatibility Test**:
  - Command: `nvim --headless -u NONE -c 'lua local out = vim.fn.system({"herdr", "agent", "list"}); local ok, data = pcall(vim.json.decode, out); print("OK:", ok, "Agents count:", ok and #data.result.agents or 0); vim.cmd("q")'`
  - Result: `OK: true Agents count: 2`.

---

## 2. Logic Chain

1. **Observed System Environment**: Neovim 0.12.3 with native `vim.json.decode`, `vim.fn.system`, and `vim.notify` support is available on macOS alongside `herdr` and `agy` binaries.
2. **Analysis of R1 (LazyVim Plugin Specification & Configuration)**:
   - LazyVim standard convention requires single-file plugin specs under `plugins/herdr-agy.lua` returning Lazy plugin tables.
   - Specifying `keys` (`<leader>as`, `<leader>ac`, `<leader>ad`, `<leader>ap`, `<leader>at`) and `cmd` (`HerdrAgySend`, `HerdrAgyPrompt`, etc.) enables lazy-loading automatically.
   - Integrating with WhichKey v3 is achieved via Lazy plugin spec extension (`opts.spec` for `folke/which-key.nvim`) and dynamic registration in `setup()`.
3. **Analysis of R4 (Herdr Environment & Topology Auto-Discovery)**:
   - Environment variables (`HERDR_ENV`, `HERDR_WORKSPACE_ID`, `HERDR_TAB_ID`, `HERDR_PANE_ID`) provide local workspace context.
   - `herdr agent list` provides agent-to-pane mapping in standard JSON.
   - A multi-tiered scoring hierarchy (Tab Match -> Workspace Match -> CWD Match -> Fallback) resolves the target `agy` pane reliably.
   - Missing `HERDR_ENV` or `herdr` executable is handled via non-blocking `vim.notify` / `LazyVim.warn` / `LazyVim.error` calls.

---

## 3. Caveats

- **Visual Context Dispatch (R2) & Diff Review (R3)**: Detailed implementation specs for R2 (Visual Selection & Context Dispatch) and R3 (Diff Review & Comments) are assigned to Explorer 2 / Implementer. R1 and R4 provide the plugin spec, configuration, topology discovery, and notification substrate for them.
- **Multiple `agy` instances in single tab**: If multiple `agy` instances exist in the exact same workspace and tab, the discovery algorithm prioritizes panes that differ from the caller pane (`caller_pane_id`). If ambiguity remains, manual selection (`:HerdrAgySelectTarget`) is provided as a fallback.

---

## 4. Conclusion

Requirements R1 and R4 are fully specified, feasible, and ready for implementation. The proposed architecture establishes:
1. `plugins/herdr-agy.lua` as a standard LazyVim spec with lazy loading and WhichKey integration.
2. `lua/herdr-agy/topology.lua` for robust JSON parsing and multi-tiered Herdr agent auto-discovery.
3. `lua/herdr-agy/notify.lua` for LazyVim-aware notifications and graceful fallback handling.
4. Comprehensive analysis document saved at `/Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_explorer_survey_1/analysis.md`.

---

## 5. Verification Method

To independently verify the findings and analysis:

1. **Inspect Analysis Report**:
   ```bash
   cat /Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_explorer_survey_1/analysis.md
   ```
2. **Verify Herdr CLI Execution & JSON Output**:
   ```bash
   herdr agent list
   herdr pane list
   ```
3. **Verify Neovim Headless Lua JSON Parsing**:
   ```bash
   nvim --headless -u NONE -c 'lua local out = vim.fn.system({"herdr", "agent", "list"}); local ok, data = pcall(vim.json.decode, out); print("JSON valid:", ok, "Agents found:", ok and #data.result.agents or 0); vim.cmd("q")'
   ```
4. **Invalidation Conditions**:
   - If `herdr agent list` format changes away from JSON `result.agents`, the parser logic will require updating.
