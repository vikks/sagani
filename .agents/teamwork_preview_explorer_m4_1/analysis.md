# Analysis Report: Milestone 4 Requirement R3 (Interactive Diff Review & Inline Commenting)

## Executive Summary
This analysis details the design and implementation strategy for **Milestone 4 Requirement R3: Interactive Diff Review & Inline Commenting** in `herdr-agy.nvim`. The feature centers on `lua/herdr-agy/diff.lua` and enables Neovim users to review diffs across `diffview.nvim` active views, standard Neovim split diffs (`vim.wo.diff`), or single buffer Git HEAD comparisons. It captures diff hunks surrounding the cursor position, formats structured markdown diff blocks via `lua/herdr-agy/format.lua`, and dispatches inline review feedback to the target `antigravity-cli` (`agy`) agent pane managed by `herdr`.

---

## 1. Codebase Audit & Current State

### 1.1 Existing Files and Module Roles
- **`lua/herdr-agy/init.lua`**: Main entrypoint. Currently contains a placeholder for `:HerdrAgyDiff`:
  ```lua
  vim.api.nvim_create_user_command("HerdrAgyDiff", function()
    notify.info("HerdrAgyDiff triggered (Diff review handler will be active in M4)", M.options)
  end, { desc = "Send diff review comment to AGY" })
  ```
- **`lua/herdr-agy/format.lua`**: Formatter module. Already implements `M.build_diff_prompt(user_comment, diff_info)`:
  ```lua
  function M.build_diff_prompt(user_comment, diff_info)
    -- Expects diff_info = { file_path, start_line, end_line, diff_text }
    -- Returns formatted markdown with ```diff ... ``` codeblock
  end
  ```
- **`lua/herdr-agy/topology.lua` & `notify.lua`**: Provide target AGY pane auto-discovery and LazyVim notification fallback.
- **`plugins/herdr-agy.lua`**: LazyVim plugin specification binding `<leader>ad` to `:HerdrAgyDiff`.
- **`lua/herdr-agy/diff.lua`**: **Does not exist yet**. To be created in Milestone 4.

---

## 2. Diff Context Detection Architecture

To support diff review in diverse Neovim workflows, `diff.lua` must support a 3-tiered context resolution pipeline:

```
                      +-------------------------------+
                      | diff.get_diff_hunk_at_cursor()|
                      +---------------+---------------+
                                      |
         +----------------------------+----------------------------+
         | Tier 1                     | Tier 2                     | Tier 3
         v                            v                            v
+------------------+         +------------------+         +------------------+
|  diffview.nvim   |         |  Neovim Split    |         | Git HEAD Buffer  |
|  Active View     |         |  Diff (vim.wo)   |         | Comparison       |
+--------+---------+         +--------+---------+         +--------+---------+
         |                            |                            |
         +----------------------------+----------------------------+
                                      |
                                      v
                      +---------------+---------------+
                      |  Hunk Extraction & Formatting |
                      |       (via vim.diff)          |
                      +---------------+---------------+
                                      |
                                      v
                      +---------------+---------------+
                      | { file_path, start_line,      |
                      |   end_line, diff_text }       |
                      +-------------------------------+
```

### 2.1 Tier 1: `diffview.nvim` Active View Detection
`diffview.nvim` is the standard diff plugin in LazyVim.
- **API Inspection**: `local has_dv, dv_lib = pcall(require, "diffview.lib")`
  - `dv_lib.get_current_view()` returns the active `DiffView` instance if the cursor is within a `diffview` tab page.
- **Buffer Name Parsing (`diffview://`)**:
  - `diffview` buffers use custom URIs: `diffview:///path/to/repo/.git/HEAD:lua/herdr-agy/diff.lua`.
  - When detected, the real repository file path can be extracted by stripping the `diffview://.../.git/[ref]:` URI scheme prefix.
- **Buffer Line Extraction**:
  - Base buffer (left window): HEAD/commit revision text.
  - Target buffer (right window): Working tree modified text.

### 2.2 Tier 2: Standard Neovim Split Diff (`vim.wo.diff`)
Neovim native diff mode sets window-local option `vim.wo.diff = true` (or `vim.wo[win].diff = true`).
- **Detection Algorithm**:
  1. Inspect current tabpage windows: `local wins = vim.api.nvim_tabpage_list_wins(0)`.
  2. Filter windows where `vim.wo[w].diff == true`.
  3. Differentiate current window (`cur_win`) and comparison window (`other_win`).
  4. Fetch text content of both buffers:
     - `text_cur` = `table.concat(vim.api.nvim_buf_get_lines(cur_buf, 0, -1, false), "\n")`
     - `text_other` = `table.concat(vim.api.nvim_buf_get_lines(other_buf, 0, -1, false), "\n")`
  5. Set `text_base = text_other` and `text_new = text_cur`.

### 2.3 Tier 3: Git HEAD Buffer Comparison (Fallback)
If the user invokes `:HerdrAgyDiff` in a regular buffer where no split diff or `diffview` is open:
- **Detection Algorithm**:
  1. Get current buffer file path: `local full_path = vim.api.nvim_buf_get_name(bufnr)`.
  2. If file path is valid, get relative path: `local rel_path = vim.fn.fnamemodify(full_path, ":~:.")`.
  3. Execute `git show HEAD:<rel_path>` via `vim.system`:
     ```lua
     local res = vim.system({ "git", "show", "HEAD:" .. rel_path }, { text = true }):wait()
     ```
  4. If `res.code == 0`: `text_base = res.stdout`, `text_new = current_buffer_text`.
  5. If `res.code ~= 0` (e.g., untracked file or non-git repo), fall back to creating a pseudo-diff hunk using the cursor/selection line range and buffer text.

---

## 3. Hunk Extraction & Hunk Diff Formatting Logic

### 3.1 `vim.diff()` Hunk Index Calculation
Neovim's `vim.diff(text_a, text_b, { result_type = "indices" })` returns a array of hunk tuples:
```lua
{
  { start_a, count_a, start_b, count_b },
  ...
}
```
*Note*: `start_a` and `start_b` are 1-indexed line numbers. `count_a` and `count_b` indicate the number of lines deleted from `a` and added/modified in `b`.

### 3.2 Cursor & Visual Selection Mapping
Given cursor line `cur_line` (or visual selection range `[start_line, end_line]`):
1. **Target Range in Buffer B**: `hunk_start = start_b`, `hunk_end = start_b + math.max(0, count_b - 1)`.
2. **Exact Hunk Match**: A hunk matches if `cur_line >= hunk_start` and `cur_line <= hunk_end`.
3. **Nearest Hunk Fallback**: If `cur_line` is outside all hunks (on unchanged context lines), find the hunk with minimum line distance: `math.abs(cur_line - (hunk_start + hunk_end) / 2)`.
4. **Range Normalization**: Return `start_line = hunk_start` and `end_line = math.max(hunk_start, hunk_end)`.

### 3.3 Hunk Diff Snippet Generation (`diff_text`)
For the selected hunk `{ sa, ca, sb, cb }`, generate a unified diff block:
- Header: `@@ -sa,ca +sb,cb @@`
- Context padding (e.g., 2 lines before `sa`/`sb` and 2 lines after `sa+ca`/`sb+cb`).
- Deletions prefixed with `-` (from `base_lines[sa .. sa+ca-1]`).
- Additions prefixed with `+` (from `new_lines[sb .. sb+cb-1]`).
- Output: A string formatted as a standard unified diff snippet.

---

## 4. Interface Contracts & Function Signatures

Per `PROJECT.md § Interface Contracts`:

### 4.1 `diff.get_diff_hunk_at_cursor(bufnr_or_win)`
- **Parameters**: `bufnr_or_win` (optional number, defaults to 0 / current window).
- **Return Value**:
  - `table` matching `{ file_path = string, start_line = number, end_line = number, diff_text = string }`
  - `nil` if no diff context or hunk can be determined.

### 4.2 `diff.send_diff_comment(opts)`
- **Parameters**: `opts` (optional table, default options).
- **Return Value**: `void`
- **Behavior**:
  1. Calls `diff.get_diff_hunk_at_cursor()`.
  2. If `nil`, calls `notify.warn("No diff hunk found at cursor position", opts)` and returns.
  3. Prompts user via `vim.ui.input({ prompt = "AGY Diff Comment: ", default = "" }, callback)`.
  4. If callback receives non-empty string, builds payload via `format.build_diff_prompt(user_comment, hunk_info)`.
  5. Dispatches prompt via `require("herdr-agy").dispatch_prompt(payload, nil, opts)`.

---

## 5. Integration Plan for Implementer

1. Create `lua/herdr-agy/diff.lua` implementing `get_diff_hunk_at_cursor()` and `send_diff_comment(opts)`.
2. Update `lua/herdr-agy/init.lua`:
   ```lua
   local diff = require("herdr-agy.diff")
   M.diff = diff

   -- In setup():
   vim.api.nvim_create_user_command("HerdrAgyDiff", function()
     diff.send_diff_comment(M.options)
   end, { range = true, desc = "Send diff review comment to AGY" })
   ```
3. Create unit test suite `tests/test_diff.lua` in `tests/run_tests.lua`.
