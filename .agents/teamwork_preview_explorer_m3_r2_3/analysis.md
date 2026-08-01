# Analysis & Recommendation Report: Milestone 3 (Iteration 2)

**Project**: `herdr-agy.nvim`  
**Agent**: Explorer 3 (`teamwork_preview_explorer_m3_r2_3`)  
**Scope**: Deep-dive analysis of `lua/herdr-agy/selection.lua` and `lua/herdr-agy/format.lua` (Visual Selection, Context Dispatch, Prompt Formatting, Notification Integration & Fallback Handling).

---

## Executive Summary

`herdr-agy.nvim` provides Neovim integration with the `herdr` terminal multiplexer and `antigravity-cli` (`agy`). Milestone 3 focuses on **Visual Selection & Context Dispatch** (`lua/herdr-agy/selection.lua` and `lua/herdr-agy/format.lua`).

Our investigation confirmed that:
1. **Visual Selection Extraction (`selection.lua`)** successfully handles characterwise (`v`), linewise (`V`), and blockwise (`<C-v>`) visual modes, normalizes top-to-bottom and bottom-to-top mark order, and safely falls back to cursor position when visual marks are uninitialized.
2. **Prompt Formatting (`format.lua`)** constructs clean markdown code blocks with explicit context headers (file path, line range `L<start>-L<end>`, filetype syntax highlighting, and user instruction).
3. **Notification & Fallback Integration (`notify.lua`, `init.lua`, `topology.lua`)** gracefully handles missing panes, missing `herdr` CLI binary, empty prompts, and non-zero exit codes with LazyVim-aware notifications (`lazyvim.util`) and standard `vim.notify` fallbacks.
4. **Identified Defects**:
   - **[HIGH] Headless Test Hang**: `test_adversarial_m2.lua` executes `:HerdrAgySend` unmocked in headless mode, triggering `vim.ui.input`, which blocks indefinitely waiting for `stdin`.
   - **[MEDIUM] Missing Command Spec**: `plugins/herdr-agy.lua` omits `"HerdrAgyContext"` from its `cmd` list, preventing lazy-loading when `:HerdrAgyContext` is invoked directly.

---

## Technical Analysis

### 1. Visual Selection Extraction (`lua/herdr-agy/selection.lua`)

#### Architecture & Lifecycle
`M.get_visual_selection(bufnr)` extracts the selected snippet and buffer metadata:
```lua
function M.get_visual_selection(bufnr)
  bufnr = (type(bufnr) == "number" and bufnr >= 0) and bufnr or 0
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- Exit visual mode cleanly to flush '< and '> position marks
  local cur_mode = vim.fn.mode()
  if cur_mode:find("[vV\22]") then
    vim.cmd([[noau normal! \x1b]])
  end
  ...
```

#### Selection Modes Supported
| Visual Mode | Identifiers | Extraction Strategy |
|-------------|-------------|---------------------|
| **Linewise** | `V` | `table.concat(lines, "\n")` over lines `start_line` to `end_line`. |
| **Blockwise** | `\22`, `<C-v>` | Iterates lines from `start_line` to `end_line`, slicing byte range `string.sub(line, min_col, max_col)`. |
| **Characterwise** | `v` | Slices start line from `start_col`, ending line to `end_col`, keeping intermediate lines whole. |

#### Key Features & Safety Guardrails
- **Mark Flushing**: Exits visual mode cleanly with `noau normal! \x1b` before retrieving `'<` and `'>` to ensure positions are up-to-date.
- **Boundary Normalization**: Automatically flips inverted selections (e.g. bottom-to-top or right-to-left):
  ```lua
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end
  ```
- **Uninitialized Mark Fallback**: If marks return line `0`, falls back to current cursor line (`vim.api.nvim_win_get_cursor(0)`).
- **Buffer Metadata**:
  - `file_path`: Formatted via `vim.fn.fnamemodify(full_name, ":~:.")` (relative to cwd or home). Falls back to `[No Name]` if buffer has no name.
  - `filetype`: Reads `vim.bo[bufnr].filetype`. Defaults to `"text"` if empty/nil.

#### Dispatch Wrappers
- **`M.send_selection_prompt(opts)`**: Interactively prompts user with `vim.ui.input({ prompt = "AGY Instruction: " }, callback)` and dispatches formatted payload to AGY via `init.dispatch_prompt`.
- **`M.send_code_context(opts)`**: Directly dispatches selection with default prompt `"Context snippet for review:"` without blocking for user instruction input.

---

### 2. Context Prompt Formatting (`lua/herdr-agy/format.lua`)

#### `M.build_context_prompt(user_instruction, selection)`
Constructs structured markdown strings consumable by AGY agents:
```lua
return string.format(
  "%s\n\nContext from `%s` (%s):\n```%s\n%s\n```",
  instruction,
  file_path,
  line_range,
  filetype,
  snippet
)
```

#### Formatting Output Matrix
| Scenario | Line Range Format | Resulting Payload Header |
|----------|-------------------|--------------------------|
| Single line | `L10` | `Context from lua/herdr-agy/init.lua (L10):` |
| Multi-line | `L10-L25` | `Context from src/main.rs (L10-L25):` |
| Unnamed Buffer | `L1-L5` | `Context from [No Name] (L1-L5):` |
| Empty Filetype | `L1` | ````text\n...``` ` |

#### Defensive Input Handling
- Defaults `selection` to `{}` if `nil` or non-table.
- Defaults `file_path` to `"[No Name]"`.
- Defaults `filetype` to `"text"`.
- Defaults `user_instruction` to `"Context snippet for review:"`.

---

### 3. Notification & Error Fallback Handling

#### Notification Bridge (`lua/herdr-agy/notify.lua`)
- Inspects `opts.notify`: respects `opts.notify = false` or `opts.notify.enabled = false`.
- Uses `pcall(require, "lazyvim.util")`. If available, delegates to `LazyVim.info`, `LazyVim.warn`, or `LazyVim.error` for native LazyVim UI toasts.
- Fallback to standard Neovim `vim.notify(msg, level, { title = opts.title or "herdr-agy.nvim" })`.

#### Dispatch Fallback Flow (`lua/herdr-agy/init.lua`)
When sending prompts to `herdr`:
1. Validates prompt text (rejects empty strings).
2. Resolves target pane: priority `opts.pane_override` -> `topology.discover_target_pane(opts)`.
3. If no pane discovered: displays `notify.error("Cannot dispatch prompt: Target pane not found")`.
4. Checks `vim.fn.executable("herdr") == 0`: displays `notify.error("'herdr' CLI binary not found in PATH")`.
5. Executes `herdr agent prompt <pane_id> "<msg>"` via `vim.system` (or `vim.fn.system`).
6. Non-zero exit status handling: displays `notify.error("Failed to prompt agent pane '<pane_id>' (exit code %d): ...")`.

---

## Detailed Findings & Defects

### Defect 1: Master Test Suite Hang on `vim.ui.input` (HIGH)
- **Symptom**: Executing `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` hangs indefinitely during `test_adversarial_m2.lua`.
- **Root Cause**: `test_adversarial_m2.lua` executes `:HerdrAgySend` in visual mode. In `init.lua`, `HerdrAgySend` calls `selection.send_selection_prompt`, which invokes `vim.ui.input({ prompt = "AGY Instruction: " })`. In headless Neovim, `vim.ui.input` blocks waiting for terminal `stdin`.
- **Remediation**:
  1. In `tests/test_adversarial_m2.lua`: Mock `vim.ui.input` during command execution tests so it resolves asynchronously without waiting for `stdin`.
  2. In `lua/herdr-agy/selection.lua`: Add headless test guard: if `_G.RUNNING_TEST_SUITE` is set and `vim.ui.input` is unmocked / non-interactive, handle input cleanly or pass default instruction.

### Defect 2: Missing `"HerdrAgyContext"` in LazyVim Spec Command Table (MEDIUM)
- **Symptom**: Calling `:HerdrAgyContext` in a fresh LazyVim session before lazy-loading `herdr-agy.nvim` fails to trigger plugin loading.
- **Root Cause**: `plugins/herdr-agy.lua` specifies `cmd = { "HerdrAgyStatus", "HerdrAgySelectTarget", "HerdrAgyPrompt", "HerdrAgySend", "HerdrAgyDiff" }`, omitting `"HerdrAgyContext"`.
- **Remediation**: Add `"HerdrAgyContext"` to the `cmd` table in `plugins/herdr-agy.lua`.

---

## Recommendations & Next Steps

1. **Implementer Action**: Apply remediation for Defect 1 (`test_adversarial_m2.lua` mocking) and Defect 2 (`plugins/herdr-agy.lua` command list).
2. **Verification**: Run `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` to ensure 100% test completion with zero hangs and exit code 0.
