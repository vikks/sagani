## 2026-08-01T06:18:58Z
You are Worker M2 (teamwork_preview_worker) for Milestone 2 of project herdr-agy.nvim.
Working Directory: /Users/vikks/teamwork_projects/nvim_herdr_agy
Your Agent Directory: /Users/vikks/teamwork_projects/nvim_herdr_agy/.agents/teamwork_preview_worker_m2

Tasks:
1. Read `ORIGINAL_REQUEST.md`, `PROJECT.md`, and `.agents/teamwork_preview_explorer_m2/analysis.md`.
2. Implement `plugins/herdr-agy.lua`:
   - Standard LazyVim plugin specification array containing:
     1. Spec for `folke/which-key.nvim`: optional spec adding `{ "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } }` to `opts.spec`.
     2. Spec for `herdr-agy.nvim`: setting `dir = "."`, `name = "herdr-agy.nvim"`, `opts = { target_agent = "agy", auto_discover = true }`, `cmd = { "HerdrAgyStatus", "HerdrAgySelectTarget", "HerdrAgyPrompt", "HerdrAgySend", "HerdrAgyDiff" }`, `keys` array mapping `<leader>as` (Send selection prompt), `<leader>ac` (Send code context), `<leader>ad` (Diff review), `<leader>ap` (Prompt AGY), `<leader>at` (Select target), and `config = function(_, opts) require("herdr-agy").setup(opts) end`.
3. Implement `tests/test_plugin_spec.lua`:
   - Unit test suite testing `plugins/herdr-agy.lua` spec return table, WhichKey group definitions, `cmd` array contents, `keys` array contents, default `opts`, and `config` execution. Must follow `tests/test_topology.lua` structure and expose `run()`.
4. Run test commands:
   `nvim --headless -u NONE -c "luafile tests/test_plugin_spec.lua"`
   `nvim --headless -u NONE -c "luafile tests/run_tests.lua"`
5. Verify 100% tests pass cleanly with exit code 0. Write changes report to `.agents/teamwork_preview_worker_m2/changes.md` and handoff report to `.agents/teamwork_preview_worker_m2/handoff.md`. Send completion message to parent.

DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
