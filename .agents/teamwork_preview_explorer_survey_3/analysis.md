# Architectural Analysis & Investigation Report: Requirement R3 & Testing Setup
**Project**: `herdr-agy.nvim` (LazyVim / Neovim Integration with Herdr & AGY)
**Author**: Explorer 3
**Date**: 2026-08-01

---

## 1. Executive Summary

This report presents a comprehensive technical analysis for two key components of the `herdr-agy.nvim` plugin:
1. **Requirement R3: Interactive Diff Review & Inline Commenting** — Seamlessly integrating Neovim diff views (`diffview.nvim`, `gitsigns.nvim`, and Neovim built-in `vim.wo.diff` split views) with `herdr` and `antigravity-cli` (`agy`), allowing developers to capture diff hunks, attach inline comments, format structured markdown diff feedback, and dispatch it to an active `agy` terminal pane.
2. **Plugin Testing Architecture** — Establishing unit and integration testing patterns tailored for Neovim Lua plugins on macOS with Neovim 0.12.3 and LuaJIT 2.1, supporting both `plenary.nvim` test runner and zero-dependency headless Neovim test scripts.

---

## 2. Requirement R3: Interactive Diff Review & Inline Commenting

### 2.1 Architecture Overview & Module Structure

Requirement R3 mandates:
- Interactive diff review integration with `diffview.nvim` or LazyVim's built-in diff views.
- Selection of diff ranges/hunks in visual or normal mode.
- Interactive user input for review comments/feedback.
- Formatting comments as clean markdown diff blocks.
- Dispatching the formatted payload to `agy` via `herdr`.

We recommend organizing the R3 implementation under `lua/herdr-agy/diff.lua` and `lua/herdr-agy/format.lua`:

```
lua/herdr-agy/
├── init.lua          # Main plugin entry point & LazyVim setup
├── config.lua        # User options & keymap defaults
├── runner.lua        # Topology discovery & herdr command execution (R2/R4)
├── diff.lua          # Requirement R3: Diff detection, extraction, and comment workflow
├── format.lua        # Requirement R2/R3: Markdown payload formatting utilities
└── ui.lua            # Input prompt wrappers (vim.ui.input / floating window)
```

---

### 2.2 Integration Strategies: `diffview.nvim` vs Built-in Diff Views

#### A. Integration with `diffview.nvim`
`diffview.nvim` (`sindrets/diffview.nvim`) is the standard LazyVim git diff plugin (`LazyVim.extras.vscode` / `git.diffview`).
- **Buffer Identification**:
  - `diffview` buffers use buffer names prefixed with `diffview://` (e.g. `diffview:///path/to/repo/.git/0000/src/main.lua` vs working tree file).
  - Filetypes: `DiffviewFiles`, `DiffviewFileHistory`, or standard filetype with `diffview` window context.
- **API Access**:
  - Check if `diffview` is loaded: `package.loaded["diffview"] ~= nil`.
  - Retrieve current view: `local lib = require("diffview.lib"); local view = lib.get_current_view()`.
  - If `view` exists, query `view:get_current_file()`:
    - Returns file info table with `path` (relative repo path), `absolute_path`, `status`, etc.
    - `view.layout.a` (left split buffer/window, usually target/HEAD) and `view.layout.b` (right split buffer/window, working tree/source).
- **Extracting Diff Content**:
  - Extract lines from active side or calculate diff between `layout.a` and `layout.b` for the selected line range using Neovim's `vim.diff()` API.

#### B. Integration with Neovim Built-in Diff Split (`vim.wo.diff`)
Neovim has native split diff support (`:diffthis`, `:vert diffsplit`, `gitsigns.nvim` `:Gitsigns diffthis`).
- **Buffer Identification**:
  - Check window option `vim.wo.diff == true` in current window.
  - Find matching split window in the same tabpage that also has `vim.wo.diff == true`.
- **Extracting Diff Content**:
  - Left window (Buffer A - original/index) vs Right window (Buffer B - modified/working).
  - Query selected lines from modified buffer and compute unified diff using `vim.diff(a_lines, b_lines, { result_type = "unified" })`.

#### C. Integration with `gitsigns.nvim` (LazyVim Default)
`gitsigns.nvim` is included in standard LazyVim installation (`/Users/vikks/.local/share/nvim/lazy/gitsigns.nvim`).
- **Buffer Identification**:
  - Normal buffer with git tracking.
  - Query hunk under cursor or in visual selection: `require("gitsigns").get_hunks(bufnr)`.
- **Extracting Diff Content**:
  - `gitsigns` provides precise hunk details (`added`, `removed`, `head` lines).
  - Convert `gitsigns` hunk structure directly into unified diff text.

#### D. Unified Fallback Strategy
If current buffer is not in a diff view:
- Extract selected code range / lines directly from active buffer.
- Format as standard syntax-highlighted code block (e.g. ` ```lua `) labeled as Code Review comment.

---

### 2.3 Visual Range & Selection Capture Algorithm

In Neovim Lua:
```lua
--- Capture start line and end line for visual selection or normal mode cursor line
---@param mode string Current mode ('v', 'V', '\22', or 'n')
---@return integer start_line, integer end_line
function M.get_selection_range(mode)
  local is_visual = mode:match("[vV\22]") ~= nil
  if is_visual then
    local start_pos = vim.fn.getpos("v")
    local end_pos = vim.fn.getpos(".")
    local start_line = start_pos[2]
    local end_line = end_pos[2]
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    return start_line, end_line
  else
    local cur_line = vim.fn.line(".")
    return cur_line, cur_line
  end
end
```

---

### 2.4 Markdown Diff Block Formatting Specification

Requirements:
- Comments must format cleanly as markdown diff blocks sent to `agy`.
- Must contain clear file path, line range, diff content, and user instructions.

#### Schema Structure:
```markdown
### 🔍 Diff Review Feedback
**File**: `lua/herdr-agy/diff.lua` (lines 45-52)
**Context**: diffview.nvim review

```diff
@@ -45,7 +45,8 @@
- local target = find_pane()
+ local target, err = find_pane()
+ if err then return nil, err end
  return target
```

**Instruction / Feedback**:
> Please refactor error handling to notify the user via vim.notify when target pane is nil.
```

---

### 2.5 User Interaction & Input Flow

1. **Trigger**:
   - User highlights code range in diff view or normal file, presses `<leader>ac` (AGY Comment) or `<leader>ar` (AGY Review Diff).
2. **Context Collection**:
   - Detect file path (`vim.api.nvim_buf_get_name(0)` or `diffview` file path).
   - Extract lines & calculate diff hunk (`vim.diff`).
3. **Interactive Prompt**:
   - Calls `vim.ui.input({ prompt = "AGY Diff Comment: " }, function(comment) ... end)`
   - Seamlessly uses LazyVim UI plugins (`dressing.nvim` / `snacks.input`).
   - If user cancels (`comment == nil` or `comment == ""`), abort gracefully without sending.
4. **Dispatch**:
   - Call `runner.send_prompt(formatted_markdown)`.
   - `runner` detects `herdr` target `agy` pane (R4) and sends prompt via `herdr agent prompt --pane <pane> "<payload>"`.
   - Provide feedback to user: `vim.notify("Diff review comment sent to AGY!", vim.log.levels.INFO, { title = "herdr-agy.nvim" })`.

---

## 3. Testing Setup Investigation & Architecture

### 3.1 Local Environment Verification

Environment inspection performed on macOS arm64:
- **Neovim Binary**: `/opt/homebrew/bin/nvim` (v0.12.3, LuaJIT 2.1.1781602682).
- **Herdr Binary**: `/opt/homebrew/bin/herdr` (v0.7.5).
- **AGY Binary**: `/Users/vikks/.local/bin/agy` (v1.1.9).
- **Plenary Plugin Location**: `/Users/vikks/.local/share/nvim/lazy/plenary.nvim`.
- **Headless Execution**: Verified working natively with `nvim --headless`.

---

### 3.2 Dual Testing Suite Strategy

We design a dual test setup for maximum flexibility and reliability:

```
tests/
├── minimal_init.lua          # Plenary & path bootstrap for test environment
├── run_tests.lua             # Standalone zero-dependency headless Lua runner
└── spec/
    ├── config_spec.lua       # Tests for user options & defaults
    ├── format_spec.lua       # Tests for markdown diff formatting
    ├── diff_spec.lua         # Tests for diff detection & hunk extraction
    └── runner_spec.lua       # Tests for topology discovery & herdr dispatch
```

#### Approach 1: `plenary.nvim` Busted Test Suite (Standard Neovim Spec)
- **`tests/minimal_init.lua`**:
  ```lua
  local root = vim.fn.fnamemodify(".", ":p")
  vim.opt.rtp:append(root)
  vim.opt.rtp:append(os.getenv("HOME") .. "/.local/share/nvim/lazy/plenary.nvim")
  vim.cmd("runtime! plugin/plenary.vim")
  ```
- **Execution Command**:
  ```bash
  nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/spec { minimal_init = 'tests/minimal_init.lua' }"
  ```

#### Approach 2: Zero-Dependency Standalone Headless Test Runner (`tests/run_tests.lua`)
- Allows running tests without depending on external plugins or test frameworks.
- Fast execution (<50ms).
- **Execution Command**:
  ```bash
  nvim --headless -u NONE -c "luafile tests/run_tests.lua"
  ```

---

### 3.3 Mocking External Dependencies for Testing

1. **Mocking `herdr` CLI execution**:
   - `vim.fn.system` and `vim.fn.systemlist` can be wrapped or stubbed in tests.
   - Example mock topology data:
     ```json
     [
       {"pane_id": "%1", "title": "nvim", "current_command": "nvim"},
       {"pane_id": "%2", "title": "agy", "current_command": "agy"}
     ]
     ```
2. **Mocking `diffview.nvim`**:
   - Inject mock `package.loaded["diffview"]` object returning simulated `view` with layout and file path.
3. **Mocking UI Input**:
   - Pass pre-configured test comment callback directly to diff comment handler function.

---

## 4. Verification Methods & Acceptance Criteria Checklist

| Requirement | Implementation Target | Verification Method |
|---|---|---|
| R3: Diffview Integration | `lua/herdr-agy/diff.lua` | Run `diff_spec.lua` with mocked `diffview.lib.get_current_view()` |
| R3: Built-in Diff Split Integration | `lua/herdr-agy/diff.lua` | Run test creating split windows with `vim.wo.diff = true` |
| R3: Markdown Payload Formatting | `lua/herdr-agy/format.lua` | Run `format_spec.lua` asserting markdown fencing and file header |
| Test Runner Execution | `tests/run_tests.lua` & `tests/minimal_init.lua` | Execute `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` |

---

## 5. Conclusion & Handoff Guidance

1. **R3 Feasibility**:
   - Fully feasible using Neovim's native `vim.diff` API combined with optional `diffview.nvim` and `gitsigns.nvim` detection.
   - Clean markdown formatting ensures `agy` receives structured context without ambiguity.
2. **Testing Harness**:
   - Headless Neovim 0.12.3 with `plenary.nvim` (present in environment) and standalone headless Lua runner provides 100% test coverage capability for all requirements.
