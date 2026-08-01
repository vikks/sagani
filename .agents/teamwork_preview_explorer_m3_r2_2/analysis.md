# Explorer 2 Analysis & Fix Recommendations: LazyVim Spec, `cmd` Table, WhichKey & Visual Keymaps

**Project**: `herdr-agy.nvim`  
**Target File**: `plugins/herdr-agy.lua`  
**Agent**: Explorer 2 (`.agents/teamwork_preview_explorer_m3_r2_2`)  
**Date**: 2026-08-01  

---

## 1. Overview & Objective

This investigation evaluates `plugins/herdr-agy.lua` against LazyVim standard conventions, initial requirements (**R1**, **R2** from `ORIGINAL_REQUEST.md`), interface definitions in `PROJECT.md`, and gate failure status documented in `GATE_STATUS.md`.

The primary focus areas are:
1. Ensuring all 6 user commands registered by `lua/herdr-agy/init.lua` are included in the LazyVim plugin spec `cmd` table for lazy-loading.
2. Auditing WhichKey (`<leader>a` group) registration and keymap specifications (`keys` table) for normal and visual mode bindings (`<leader>as`, `<leader>ac`, `<leader>at`, `<leader>ap`, `<leader>ad`).
3. Formulating actionable, machine-applicable fix recommendations for `plugins/herdr-agy.lua` and associated test files (`tests/test_plugin_spec.lua`, `tests/test_adversarial_m2.lua`).

---

## 2. Audit of Lazy-Loading `cmd` Table

### 2.1 Findings in Source vs. Plugin Spec

In `lua/herdr-agy/init.lua`, six user commands are registered in `M.setup()`:
1. `:HerdrAgyStatus` — `init.lua:27`
2. `:HerdrAgySelectTarget` — `init.lua:46`
3. `:HerdrAgyPrompt` — `init.lua:58`
4. `:HerdrAgySend` — `init.lua:71`
5. `:HerdrAgyContext` — `init.lua:75` (Sends visual selection code context directly to AGY without prompt)
6. `:HerdrAgyDiff` — `init.lua:79`

In `plugins/herdr-agy.lua` (lines 19-25), the `cmd` table is currently defined as:
```lua
    cmd = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyDiff",
    },
```

### 2.2 Identification of Defect

- **Missing Command**: `"HerdrAgyContext"` is omitted from the `cmd` array in `plugins/herdr-agy.lua`.
- **Defect Impact**: In LazyVim, plugin lazy-loading via user command execution relies on Lazy.nvim intercepting registered command names. If a user executes `:HerdrAgyContext` while `herdr-agy.nvim` is un-triggered/lazy-loaded, Lazy.nvim will not trigger plugin loading, causing Neovim to throw `E492: Not an editor command: HerdrAgyContext`.
- **Gate Status Reference**: Documented as **[MEDIUM] Defect #2** in `.agents/orchestrator/GATE_STATUS.md`.

### 2.3 Recommendation for `cmd` Table

Update `cmd` in `plugins/herdr-agy.lua` to explicitly include all 6 commands:
```lua
    cmd = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyContext",
      "HerdrAgyDiff",
    },
```

---

## 3. Audit of WhichKey & Visual Mode Keymaps

### 3.1 WhichKey Menu Group Specification

In `plugins/herdr-agy.lua` (lines 4-12):
```lua
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } },
      },
    },
  },
```
- **Compliance Assessment**: Complies fully with standard LazyVim / WhichKey v3 conventions (`opts.spec`).
- **Mode Coverage**: `mode = { "n", "v" }` correctly sets the WhichKey popup menu label for `<leader>a` ("AGY / Herdr") in both Normal and Visual modes.
- **Optionality**: `optional = true` guarantees no hard dependency error if WhichKey is absent.

### 3.2 Keymap Bindings (`keys` table) Audit

In `plugins/herdr-agy.lua` (lines 26-32):
```lua
    keys = {
      { "<leader>as", "<cmd>HerdrAgyStatus<cr>", desc = "AGY Status" },
      { "<leader>ac", "<cmd>HerdrAgySelectTarget<cr>", desc = "Select AGY Target Pane" },
      { "<leader>ad", "<cmd>HerdrAgyDiff<cr>", desc = "Send Diff Comment to AGY", mode = { "n", "v" } },
      { "<leader>ap", "<cmd>HerdrAgyPrompt<cr>", desc = "Send Prompt to AGY", mode = { "n", "v" } },
      { "<leader>at", "<cmd>HerdrAgySend<cr>", desc = "Send Selection to AGY", mode = "v" },
    },
```

#### Evaluation against R1/R2 & LazyVim Conventions:

1. **R2 Requirement Alignment**:
   Requirement **R2** states: *"Provide visual mode keymaps (`<leader>as` / `<leader>ac`) to send selected code, file path, line numbers, filetype, and user instructions directly to the agy agent in an adjacent herdr right pane via herdr agent prompt."*
2. **Current Mapping Limitations**:
   - `<leader>as` currently only maps to `:HerdrAgyStatus` in Normal mode (default mode).
   - `<leader>ac` currently only maps to `:HerdrAgySelectTarget` in Normal mode (default mode).
   - `:HerdrAgyContext` is not bound to any keymap in `keys`.
3. **LazyVim Multi-Mode Keymap Overloading**:
   In Lazy.nvim spec format, single key combinations can be specified multiple times with distinct `mode` settings. 
   - Normal mode `<leader>as` -> `:HerdrAgyStatus` ("AGY Status")
   - Visual mode `<leader>as` -> `:HerdrAgySend` ("Send Selection to AGY")
   - Normal mode `<leader>ac` -> `:HerdrAgySelectTarget` ("Select AGY Target Pane")
   - Visual mode `<leader>ac` -> `:HerdrAgyContext` ("Send Code Context to AGY")
   - Visual mode `<leader>at` -> `:HerdrAgySend` ("Send Selection to AGY" — kept for backward compatibility with M2 tests)

---

## 4. Recommended Proposed Code Changes

### 4.1 Proposed `plugins/herdr-agy.lua`

```lua
-- LazyVim plugin specification for herdr-agy.nvim
return {
  -- Optional WhichKey integration for AGY / Herdr keymap group
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } },
      },
    },
  },

  -- herdr-agy.nvim main plugin specification
  {
    "herdr-agy.nvim",
    dir = ".",
    name = "herdr-agy.nvim",
    cmd = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyContext",
      "HerdrAgyDiff",
    },
    keys = {
      { "<leader>as", "<cmd>HerdrAgyStatus<cr>", desc = "AGY Status", mode = "n" },
      { "<leader>as", "<cmd>HerdrAgySend<cr>", desc = "Send Selection to AGY", mode = "v" },
      { "<leader>ac", "<cmd>HerdrAgySelectTarget<cr>", desc = "Select AGY Target Pane", mode = "n" },
      { "<leader>ac", "<cmd>HerdrAgyContext<cr>", desc = "Send Code Context to AGY", mode = "v" },
      { "<leader>ad", "<cmd>HerdrAgyDiff<cr>", desc = "Send Diff Comment to AGY", mode = { "n", "v" } },
      { "<leader>ap", "<cmd>HerdrAgyPrompt<cr>", desc = "Send Prompt to AGY", mode = { "n", "v" } },
      { "<leader>at", "<cmd>HerdrAgySend<cr>", desc = "Send Selection to AGY", mode = "v" },
    },
    opts = {
      target_agent = "agy",
      auto_discover = true,
    },
    config = function(_, opts)
      require("herdr-agy").setup(opts)
    end,
  },
}
```

---

## 5. Impact & Recommendations for Test Suites

### 5.1 Updates Required in `tests/test_plugin_spec.lua`

1. **`expected_cmds` Array**:
   Update `expected_cmds` in `test_plugin_spec.lua` (lines 111-120) to expect 6 commands:
   ```lua
    local expected_cmds = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyContext",
      "HerdrAgyDiff",
    }
    assert_eq(#main_spec.cmd, #expected_cmds, "contains exactly 6 commands")
   ```
2. **User Command Registration Assertion**:
   Add `assert_true(vim.fn.exists(":HerdrAgyContext") == 2, ":HerdrAgyContext user command registered")`.
3. **Keymap Assertions**:
   Adjust keymap validation loop in `test_plugin_spec.lua` to index keymaps by `lhs + mode` (e.g. `k[1] .. "_" .. (type(k.mode) == "table" and table.concat(k.mode, ",") or (k.mode or "n"))`) or check array elements directly so multi-mode keymaps for `<leader>as` and `<leader>ac` pass validation cleanly.

### 5.2 Test Runner Blocking Issue in `tests/test_adversarial_m2.lua`

- **Root Cause**: In `tests/test_adversarial_m2.lua` (lines 161-163), `pcall(vim.cmd, "HerdrAgySend")` triggers `selection.send_selection_prompt`, which invokes `vim.ui.input({ prompt = "AGY Instruction: " })`. In headless Neovim test runs without `stdin`, `vim.ui.input` blocks indefinitely.
- **Fix**: In `tests/test_adversarial_m2.lua`, wrap command execution with a mock for `vim.ui.input`:
  ```lua
    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      if cb then cb("test instruction") end
    end
    local ok2 = pcall(vim.cmd, "HerdrAgySend")
    vim.ui.input = orig_input
    assert_true(ok2, "HerdrAgySend executes in normal mode")
  ```

---

## 6. Verification Method

To verify these recommendations once applied:

1. **Lazy Loading Command Spec Verification**:
   Execute `nvim --headless -u NONE -c "luafile tests/test_plugin_spec.lua"` to ensure all 6 commands and keymap specs validate without error.
2. **Master Test Runner Verification**:
   Execute `nvim --headless -u NONE -c "luafile tests/run_tests.lua"` to confirm 100% test completion with 0 hangs, exit code 0, and 0 failures.
