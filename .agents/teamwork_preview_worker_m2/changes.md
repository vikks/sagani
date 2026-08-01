# Milestone 2 Implementation Changes Report

## Overview
Milestone 2 adds LazyVim plugin specification support (`plugins/herdr-agy.lua`) and unit test suite (`tests/test_plugin_spec.lua`) for `herdr-agy.nvim`.

## Files Created & Modified

| File Path | Description | Status |
|-----------|-------------|--------|
| `plugins/herdr-agy.lua` | LazyVim plugin specification exporting WhichKey integration and main plugin spec table | Created |
| `tests/test_plugin_spec.lua` | Unit test suite for plugin spec structure, WhichKey mapping, lazy-load commands/keys, default options, and setup config execution | Created |

## Implementation Details

### 1. `plugins/herdr-agy.lua`
- Exports a table array with two LazyVim plugin specifications:
  1. `folke/which-key.nvim` (optional spec):
     - Adds `{ "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } }` to `opts.spec`.
  2. `herdr-agy.nvim` (main spec):
     - Configures `dir = "."` and `name = "herdr-agy.nvim"`.
     - Configures lazy-loading command triggers (`cmd`): `HerdrAgyStatus`, `HerdrAgySelectTarget`, `HerdrAgyPrompt`, `HerdrAgySend`, `HerdrAgyDiff`.
     - Configures lazy-loading keymaps (`keys`):
       - `<leader>as`: `<cmd>HerdrAgyStatus<cr>` (Normal mode)
       - `<leader>ac`: `<cmd>HerdrAgySelectTarget<cr>` (Normal mode)
       - `<leader>ad`: `<cmd>HerdrAgyDiff<cr>` (Normal + Visual modes)
       - `<leader>ap`: `<cmd>HerdrAgyPrompt<cr>` (Normal + Visual modes)
       - `<leader>at`: `<cmd>HerdrAgySend<cr>` (Visual mode)
     - Configures default options (`opts`): `target_agent = "agy"`, `auto_discover = true`.
     - Configures setup initializer (`config`): `function(_, opts) require("herdr-agy").setup(opts) end`.

### 2. `tests/test_plugin_spec.lua`
- Implements comprehensive headless Neovim test suite following `tests/test_topology.lua` structure.
- Exposes `M.run()` returning `{ passed = number, failed = number, failures = table }`.
- Test scenarios covered:
  - File existence and valid Lua table export (2 spec items).
  - WhichKey spec optional flag, group prefix `<leader>a`, label `"AGY / Herdr"`, and modes `{"n", "v"}`.
  - Command list completeness (`cmd` length 5 and specific command names).
  - Keymap bindings (`keys` array mappings, command strings, descriptions, and modes).
  - Default options (`opts` target_agent and auto_discover).
  - Config setup invocation delegating to `require("herdr-agy").setup(opts)` and verifying user command creation.

## Build and Test Verification

1. Standalone test suite command:
   ```bash
   nvim --headless -u NONE -c "luafile tests/test_plugin_spec.lua"
   ```
   **Result**: 48 Passed, 0 Failed (Exit Code 0).

2. Master test runner command:
   ```bash
   nvim --headless -u NONE -c "luafile tests/run_tests.lua"
   ```
   **Result**: 121 Passed, 0 Failed across 2 test files (Exit Code 0).
