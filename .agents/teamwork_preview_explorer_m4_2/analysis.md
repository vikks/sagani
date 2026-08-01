# Milestone 4 Analysis Report: Requirement R3 & Feature F8 (Structured Diff Formatting & Command Wiring)

## 1. Executive Summary

This report presents a comprehensive technical analysis for **Milestone 4 Requirement R3 (Interactive Diff Review & Inline Commenting)** and **Feature F8 (Structured Diff Formatting & Command Wiring)** in `herdr-agy.nvim`.

The investigation evaluated:
1. `lua/herdr-agy/format.lua`: `format.build_diff_prompt(user_comment, diff_info)` formatting logic, markdown diff block structure (` ```diff ``), metadata parsing (`file_path`, `line_range`), and default fallback handling.
2. `lua/herdr-agy/init.lua`: `:HerdrAgyDiff` user command creation, target pane dispatch integration, and option forwarding.
3. `plugins/herdr-agy.lua`: LazyVim plugin spec, `<leader>ad` keymap registration for Normal (`n`) and Visual (`v`) modes, and WhichKey integration.
4. Workflow interaction: `vim.ui.input` prompt dialog (`"AGY Diff Comment: "`), user cancellation handling (`input == nil`), default comment substitution, and prompt dispatch to `herdr` target pane.

---

## 2. Structured Diff Formatting (`lua/herdr-agy/format.lua`)

### 2.1 Function Signature & Contract
`format.build_diff_prompt(user_comment, diff_info)` -> `string`

- **Parameters**:
  - `user_comment` (`string|nil`): Commentary provided by the user via `vim.ui.input`.
  - `diff_info` (`table|nil`): Diff hunk metadata containing:
    - `file_path` (`string`): Relative or absolute path to the buffer file.
    - `start_line` (`number`): 1-indexed starting line number of hunk.
    - `end_line` (`number`): 1-indexed ending line number of hunk.
    - `diff_text` (`string`): Unified diff snippet string.

### 2.2 Formatting Implementation Analysis
In `lua/herdr-agy/format.lua` (lines 40-64):

```lua
function M.build_diff_prompt(user_comment, diff_info)
  diff_info = type(diff_info) == "table" and diff_info or {}

  local file_path = (type(diff_info.file_path) == "string" and diff_info.file_path ~= "") and diff_info.file_path or "[No Name]"
  local start_line = type(diff_info.start_line) == "number" and diff_info.start_line or 1
  local end_line = type(diff_info.end_line) == "number" and diff_info.end_line or start_line
  local diff_text = type(diff_info.diff_text) == "string" and diff_text or ""

  local line_range
  if start_line == end_line then
    line_range = "L" .. tostring(start_line)
  else
    line_range = string.format("L%d-L%d", start_line, end_line)
  end

  local comment = (type(user_comment) == "string" and user_comment ~= "") and user_comment or "Diff review comment:"

  return string.format(
    "%s\n\nDiff Context from `%s` (%s):\n```diff\n%s\n```",
    comment,
    file_path,
    line_range,
    diff_text
  )
end
```

### 2.3 Key Strengths & Validation
1. **Line Range Normalization**: Correctly outputs single-line format (`L12`) when `start_line == end_line`, and range format (`L12-L15`) when `start_line ~= end_line`.
2. **Markdown Block Syntax**: Wraps diff text inside a fenced code block with `diff` language identifier (` ```diff\n...\n``` `), ensuring clean syntax highlighting when rendered in AGY terminal panes.
3. **Fallback Safety**: Safely handles empty string/nil `user_comment` by falling back to `"Diff review comment:"`. Safely handles missing `file_path` by falling back to `"[No Name]"`.
4. **Existing Unit Test Coverage**: Verified in `tests/test_format.lua` lines 131-153:
   - `build_diff_prompt: Formats diff comment prompt correctly` (PASSED)
   - `build_diff_prompt: Single line diff and nil comment fallbacks` (PASSED)

---

## 3. Command Wiring & Keymaps (`init.lua` & `plugins/herdr-agy.lua`)

### 3.1 LazyVim Plugin Spec (`plugins/herdr-agy.lua`)
In `plugins/herdr-agy.lua` (lines 25, 32):
- Command registration array `cmd`: includes `"HerdrAgyDiff"`.
- Keymap definition in `keys`:
  ```lua
  { "<leader>ad", "<cmd>HerdrAgyDiff<cr>", desc = "Send Diff Comment to AGY", mode = { "n", "v" } }
  ```
- WhichKey registration in `opts.spec`:
  ```lua
  { "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } }
  ```

### 3.2 User Command Definition (`lua/herdr-agy/init.lua`)
Currently in `lua/herdr-agy/init.lua` (lines 79-81):
```lua
vim.api.nvim_create_user_command("HerdrAgyDiff", function()
  notify.info("HerdrAgyDiff triggered (Diff review handler will be active in M4)", M.options)
end, { desc = "Send diff review comment to AGY" })
```

#### Proposed M4 Code Modification for `init.lua`:
Update `HerdrAgyDiff` command registration in `init.lua` to invoke `diff.send_diff_comment`:
```lua
vim.api.nvim_create_user_command("HerdrAgyDiff", function()
  local diff = require("herdr-agy.diff")
  diff.send_diff_comment(M.options)
end, { range = true, desc = "Send diff review comment to AGY" })
```
Note: Adding `{ range = true }` ensures Neovim permits `:HerdrAgyDiff` execution when invoked from visual mode or with line range prefixes without failing with `E481`.

---

## 4. Interactive Dialog (`vim.ui.input`) & Workflow Design

### 4.1 Orchestration in `lua/herdr-agy/diff.lua`
The function `diff.send_diff_comment(opts)` acts as the primary entry point for diff comment interactions.

#### Blueprint Implementation Sequence:
```lua
function M.send_diff_comment(opts)
  opts = type(opts) == "table" and opts or M.options or {}

  -- 1. Extract diff hunk context at cursor
  local diff_info = M.get_diff_hunk_at_cursor()
  if not diff_info or not diff_info.diff_text or diff_info.diff_text == "" then
    notify.warn("No diff hunk found under cursor", opts)
    return false
  end

  -- 2. Prompt user asynchronously for review commentary
  vim.ui.input({ prompt = "AGY Diff Comment: ", default = "" }, function(input)
    -- User cancelled input dialog (ESC)
    if input == nil then
      notify.info("Diff comment cancelled", opts)
      return
    end

    -- 3. Format payload using format.build_diff_prompt
    local payload = format.build_diff_prompt(input, diff_info)

    -- 4. Dispatch payload to target Herdr AGY pane
    local main = require("herdr-agy")
    main.dispatch_prompt(payload, nil, opts)
  end)
end
```

### 4.2 Step-by-Step Flow Matrix

| Step | Action | Logic / Condition | Output / Side Effect |
|------|--------|------------------|----------------------|
| 1 | Trigger `:HerdrAgyDiff` or `<leader>ad` | User action in Neovim | Calls `diff.send_diff_comment(opts)` |
| 2 | Extract diff hunk | `diff.get_diff_hunk_at_cursor()` | Returns `diff_info` or `nil` |
| 3 | Hunk validation check | If `diff_info == nil` | Displays `notify.warn("No diff hunk found under cursor")` and aborts |
| 4 | Open prompt dialog | `vim.ui.input({ prompt = "AGY Diff Comment: " })` | Opens input field for user |
| 5 | Handle input result | If `input == nil` | User cancelled (ESC); displays info notification and exits cleanly |
| 6 | Format markdown payload | `format.build_diff_prompt(input, diff_info)` | Generates formatted markdown string with diff block |
| 7 | Dispatch prompt | `init.dispatch_prompt(payload, nil, opts)` | Executes `herdr agent prompt <pane_id> "<payload>"` via `vim.system` |

---

## 5. Edge Cases & Defensive Measures

1. **User Cancellation (`input == nil`)**:
   - `vim.ui.input` passes `nil` to the callback when cancelled via ESC.
   - The handler must check `if input == nil then return end` to prevent sending empty or malformed prompts to AGY.
2. **Empty Input (`input == ""`)**:
   - Pressing Enter with an empty input string passes `""`.
   - `format.build_diff_prompt("", diff_info)` automatically substitutes `"Diff review comment:"`, which is valid and expected.
3. **No Diff View Active / Cursor on Unchanged Line**:
   - `get_diff_hunk_at_cursor()` returns `nil`.
   - `send_diff_comment` checks `diff_info` before calling `vim.ui.input` and issues a warning notification.
4. **Visual Mode Range Parameter**:
   - Adding `{ range = true }` to `nvim_create_user_command("HerdrAgyDiff", ...)` prevents Neovim from raising `E481: No range allowed` when invoked via `<leader>ad` in visual mode.
5. **Missing Herdr Binary or Target Pane**:
   - `init.dispatch_prompt` handles CLI missing errors (`'herdr' CLI binary not found in PATH`) and target pane missing errors cleanly via `notify.error`.

---

## 6. Recommendations for Implementer

1. Update `lua/herdr-agy/init.lua` to wire `:HerdrAgyDiff` directly to `require("herdr-agy.diff").send_diff_comment(M.options)` with `{ range = true }`.
2. Ensure `lua/herdr-agy/diff.lua` defines `send_diff_comment(opts)` using `vim.ui.input` with exact prompt `"AGY Diff Comment: "`.
3. Verify that `format.build_diff_prompt` remains intact and passes all tests in `tests/test_format.lua`.
