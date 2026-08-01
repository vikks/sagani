# Handoff Report — Explorer M2 (Milestone 2: LazyVim Spec & WhichKey Configuration)

## 1. Observation
- **Workspace Location**: `/Users/vikks/teamwork_projects/nvim_herdr_agy`
- **Existing Project Structure**:
  - `lua/herdr-agy/init.lua` (136 lines): Provides `setup(user_opts)` and registers user commands (`HerdrAgyStatus`, `HerdrAgySelectTarget`, `HerdrAgyPrompt`, `HerdrAgySend`, `HerdrAgyDiff`). Defaults defined at lines 6-14 (`target_agent = "agy"`, `auto_discover = true`, `pane_override = nil`, `notify = { enabled = true, title = "herdr-agy.nvim" }`).
  - `lua/herdr-agy/topology.lua` & `lua/herdr-agy/notify.lua`: Core discovery and notification modules implemented in M1.
  - `tests/run_tests.lua` (66 lines): Master test runner iterating over `tests/test_*.lua` files, checking `mod.run()`.
  - `tests/test_topology.lua` (465 lines): Unit test suite for M1 modules using custom assertion helpers (`assert_eq`, `assert_true`, `assert_nil`).
- **Target Files for M2 Implementation**:
  - `plugins/herdr-agy.lua` (Not yet created): Required to export LazyVim plugin spec array.
  - `tests/test_plugin_spec.lua` (Not yet created): Required unit test suite for M2.

## 2. Logic Chain
1. **Observation**: `ORIGINAL_REQUEST.md` (R1) and `PROJECT.md` (F3, F4) require `plugins/herdr-agy.lua` to define a standard LazyVim spec with `opts`, `keys`, `cmd`, `config`, and WhichKey v3 integration for `<leader>a`.
2. **Observation**: WhichKey v3 standard in LazyVim defines menu group headers via `opts.spec` in `folke/which-key.nvim`.
3. **Logic**: Exporting a multi-spec Lua array from `plugins/herdr-agy.lua` containing both `{ "folke/which-key.nvim", opts = { spec = { { "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } } } } }` and `{ "herdr-agy.nvim", cmd = { ... }, keys = { ... }, opts = { ... }, config = ... }` allows LazyVim to register the menu title and lazy-load `herdr-agy.nvim` seamlessly.
4. **Observation**: `init.setup(user_opts)` registers 5 user commands: `HerdrAgyStatus`, `HerdrAgySelectTarget`, `HerdrAgyPrompt`, `HerdrAgySend`, `HerdrAgyDiff`.
5. **Logic**: The `cmd` property of `herdr-agy.nvim` spec must list all 5 commands, and `keys` must map `<leader>as`, `<leader>ac`, `<leader>ad`, `<leader>ap`, `<leader>at` to their respective commands with correct mode specifications (`"v"` for `HerdrAgySend`, `{ "n", "v" }` for `HerdrAgyDiff`/`HerdrAgyPrompt`).
6. **Observation**: `tests/run_tests.lua` executes all files matching `test_*.lua` in `tests/` by calling `dofile(file_path)` and invoking `mod.run()`.
7. **Logic**: Creating `tests/test_plugin_spec.lua` with a `run()` method following `tests/test_topology.lua` structure will allow seamless headless unit test execution via `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`.

## 3. Caveats
- `plugins/herdr-agy.lua` will be evaluated outside a full LazyVim environment during unit testing via `dofile`. The test suite verifies the returned specification table structure, keymap bindings, command triggers, and `config` callback execution directly.

## 4. Conclusion
The architectural design and test specification for Milestone 2 are complete.
- Proposed specification: `plugins/herdr-agy.lua` containing WhichKey v3 group spec and `herdr-agy.nvim` lazy spec table.
- Proposed unit test suite: `tests/test_plugin_spec.lua` covering 10 unit test cases across Tier 1, Tier 2, Tier 3, and Tier 4.

## 5. Verification Method
1. Inspect proposed implementation files in `.agents/teamwork_preview_explorer_m2/analysis.md`.
2. Once implemented by Worker M2, run the master test runner from project root:
   `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`
3. Invalidation condition: `run_tests.lua` fails or `test_plugin_spec.lua` fails to validate `opts`, `keys`, `cmd`, or `config`.
