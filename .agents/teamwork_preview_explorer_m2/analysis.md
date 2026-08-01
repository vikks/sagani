# Milestone 2 Architectural Analysis & Spec Design: herdr-agy.nvim

## Executive Summary
This report presents the architectural analysis and implementation design for Milestone 2 (LazyVim Spec & WhichKey Configuration) of `herdr-agy.nvim`. The objective is to design a standard LazyVim plugin specification file under `plugins/herdr-agy.lua` with lazy loading triggers and WhichKey v3 menu integration, alongside a comprehensive unit test suite in `tests/test_plugin_spec.lua`.

---

## 1. LazyVim Plugin Specification Analysis (`plugins/herdr-agy.lua`)

### 1.1 Specification Architecture & Conventions
LazyVim utilizes `lazy.nvim` as its plugin manager. Multi-spec array exports from plugin configuration files in `plugins/*.lua` allow modular extension of both third-party dependencies (such as `folke/which-key.nvim`) and target plugin specs in a single declarative file.

The proposed `plugins/herdr-agy.lua` exports a table array containing two plugin specifications:
1. **WhichKey Integration Spec**: Extends `folke/which-key.nvim` by appending the `<leader>a` prefix group definition under `opts.spec`.
2. **Main Plugin Spec**: Configures `herdr-agy.nvim` with lazy-loading triggers (`cmd` and `keys`), default options (`opts`), and setup initialization (`config`).

### 1.2 WhichKey Menu Integration (`folke/which-key.nvim`)
WhichKey v3 uses `opts.spec` array format for registering keymap groups and descriptions.

```lua
{
  "folke/which-key.nvim",
  opts = {
    spec = {
      { "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } },
    },
  },
}
```

- **Prefix**: `<leader>a`
- **Group Label**: `"AGY / Herdr"`
- **Modes**: `{ "n", "v" }` (Normal and Visual modes)

### 1.3 Main Plugin Spec (`herdr-agy.nvim`)
```lua
{
  "herdr-agy.nvim",
  cmd = {
    "HerdrAgyStatus",
    "HerdrAgySelectTarget",
    "HerdrAgyPrompt",
    "HerdrAgySend",
    "HerdrAgyDiff",
  },
  keys = {
    { "<leader>as", "<cmd>HerdrAgyStatus<cr>", desc = "AGY Status" },
    { "<leader>ac", "<cmd>HerdrAgySelectTarget<cr>", desc = "Select AGY Target Pane" },
    { "<leader>ad", "<cmd>HerdrAgyDiff<cr>", desc = "Send Diff Comment to AGY", mode = { "n", "v" } },
    { "<leader>ap", "<cmd>HerdrAgyPrompt<cr>", desc = "Send Prompt to AGY", mode = { "n", "v" } },
    { "<leader>at", "<cmd>HerdrAgySend<cr>", desc = "Send Selection to AGY", mode = "v" },
  },
  opts = {
    target_agent = "agy",
    auto_discover = true,
    pane_override = nil,
    notify = {
      enabled = true,
      title = "herdr-agy.nvim",
    },
  },
  config = function(_, opts)
    require("herdr-agy").setup(opts)
  end,
}
```

#### Key Elements & Trigger Mapping
- **Commands (`cmd`)**:
  - `HerdrAgyStatus`: Displays current Herdr topology, session status, and active target AGY pane.
  - `HerdrAgySelectTarget`: Opens prompt for setting a manual pane ID override.
  - `HerdrAgyPrompt`: Prompts user or accepts inline argument to dispatch prompt to AGY.
  - `HerdrAgySend`: Dispatches visual selection context to AGY (M3 visual selection engine).
  - `HerdrAgyDiff`: Dispatches diff review comments to AGY (M4 interactive diff engine).
- **Keymaps (`keys`)**:
  - `<leader>as` -> `<cmd>HerdrAgyStatus<cr>` (Normal mode)
  - `<leader>ac` -> `<cmd>HerdrAgySelectTarget<cr>` (Normal mode)
  - `<leader>ad` -> `<cmd>HerdrAgyDiff<cr>` (Normal + Visual mode)
  - `<leader>ap` -> `<cmd>HerdrAgyPrompt<cr>` (Normal + Visual mode)
  - `<leader>at` -> `<cmd>HerdrAgySend<cr>` (Visual mode only)
- **Options (`opts`)**:
  - Matches default configuration table defined in `lua/herdr-agy/init.lua`.
- **Config (`config`)**:
  - Receives `(self, opts)` and delegates to `require("herdr-agy").setup(opts)`.

---

## 2. Unit Test Suite Specification (`tests/test_plugin_spec.lua`)

### 2.1 Test Execution Architecture
`tests/test_plugin_spec.lua` will follow the existing test runner protocol established in `tests/test_topology.lua`.
- Executable headlessly via `tests/run_tests.lua` (`nvim --headless -u NONE -c "luafile tests/run_tests.lua"`).
- Direct standalone execution support via `dofile` / `luafile`.
- Returns `{ passed = number, failed = number, failures = table }`.

### 2.2 Test Matrix & Case Inventory

| Tier | Category | Test Description | Expected Result |
|------|----------|------------------|-----------------|
| Tier 1 | Spec Return | `plugins/herdr-agy.lua` exists and returns valid table | Returns table containing 2 spec elements |
| Tier 1 | Spec Return | `folke/which-key.nvim` spec present in returned array | Table found with `"folke/which-key.nvim"` |
| Tier 1 | Spec Return | `herdr-agy.nvim` spec present in returned array | Table found with `"herdr-agy.nvim"` |
| Tier 1 | WhichKey | `<leader>a` group registered in `opts.spec` | Group defined with label `"AGY / Herdr"` |
| Tier 1 | WhichKey | Group mode includes `"n"` and `"v"` | `item.mode` contains `"n"` and `"v"` |
| Tier 1 | Lazy Load | `cmd` table contains all 5 user commands | All 5 commands present in `main_spec.cmd` |
| Tier 1 | Lazy Load | `keys` table contains all 5 keymaps | Mappings for `<leader>as`, `ac`, `ad`, `ap`, `at` |
| Tier 1 | Keymaps | Modes for visual-only/dual keymaps match | `<leader>at` is `"v"`, `<leader>ad`/`<leader>ap` are `{ "n", "v" }` |
| Tier 1 | Options | Default `opts` table matches `init.defaults` | `target_agent = "agy"`, `auto_discover = true`, etc. |
| Tier 1 | Setup | `config(plugin, opts)` calls `init.setup(opts)` | User commands created, `init.options` updated |
| Tier 2 | Boundary | `config` called with custom options table | Options deeply merged into `init.options` |
| Tier 2 | Boundary | `config` called with `nil` or primitive `opts` | Handles non-table `opts` gracefully using defaults |
| Tier 3 | Pairwise | Command names in `keys` match names registered in `cmd` | 1:1 mapping between key commands and user commands |
| Tier 4 | Real-World | Execute full `config` setup in Neovim runtime | `:HerdrAgyStatus` command exists in Neovim (`vim.fn.exists`) |

---

## 3. Implementation Code Proposals

### 3.1 Proposed `plugins/herdr-agy.lua`
```lua
-- LazyVim plugin specification for herdr-agy.nvim
return {
  -- WhichKey integration for AGY / Herdr keymap group
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } },
      },
    },
  },

  -- herdr-agy.nvim main plugin specification
  {
    "herdr-agy.nvim",
    cmd = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyDiff",
    },
    keys = {
      { "<leader>as", "<cmd>HerdrAgyStatus<cr>", desc = "AGY Status" },
      { "<leader>ac", "<cmd>HerdrAgySelectTarget<cr>", desc = "Select AGY Target Pane" },
      { "<leader>ad", "<cmd>HerdrAgyDiff<cr>", desc = "Send Diff Comment to AGY", mode = { "n", "v" } },
      { "<leader>ap", "<cmd>HerdrAgyPrompt<cr>", desc = "Send Prompt to AGY", mode = { "n", "v" } },
      { "<leader>at", "<cmd>HerdrAgySend<cr>", desc = "Send Selection to AGY", mode = "v" },
    },
    opts = {
      target_agent = "agy",
      auto_discover = true,
      pane_override = nil,
      notify = {
        enabled = true,
        title = "herdr-agy.nvim",
      },
    },
    config = function(_, opts)
      require("herdr-agy").setup(opts)
    end,
  },
}
```

### 3.2 Proposed `tests/test_plugin_spec.lua`
```lua
-- Headless Neovim Unit Test Suite for herdr-agy.nvim LazyVim Spec & WhichKey Config
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local init = require("herdr-agy.init")

local M = {}

function M.run()
  local passed_count = 0
  local failed_count = 0
  local test_failures = {}

  local function assert_eq(actual, expected, test_name)
    if actual == expected then
      passed_count = passed_count + 1
      print(string.format("  ✓ PASS: %s", test_name))
    else
      failed_count = failed_count + 1
      local msg = string.format("  ✗ FAIL: %s (Expected: %s, Got: %s)", test_name, tostring(expected), tostring(actual))
      print(msg)
      table.insert(test_failures, msg)
    end
  end

  local function assert_true(cond, test_name)
    assert_eq(cond, true, test_name)
  end

  local function assert_nil(val, test_name)
    assert_eq(val, nil, test_name)
  end

  local function run_test(name, fn)
    print("\nRunning Test: " .. name)
    local ok, err = pcall(fn)
    if not ok then
      failed_count = failed_count + 1
      local msg = string.format("  ✗ EXCEPTION: %s error: %s", name, tostring(err))
      print(msg)
      table.insert(test_failures, msg)
    end
  end

  local plugin_spec_path = project_root .. "/plugins/herdr-agy.lua"

  local function find_spec(specs, name)
    if type(specs) ~= "table" then return nil end
    if specs[1] == name or specs.name == name then
      return specs
    end
    for _, s in ipairs(specs) do
      if type(s) == "table" and (s[1] == name or s.name == name) then
        return s
      end
    end
    return nil
  end

  -- 1. SPEC TABLE STRUCTURE & EXPORTS
  run_test("plugin_spec: File exists and loads cleanly", function()
    assert_eq(vim.fn.filereadable(plugin_spec_path), 1, "plugins/herdr-agy.lua readable")
    local specs = dofile(plugin_spec_path)
    assert_true(type(specs) == "table", "returns lua table")
  end)

  run_test("plugin_spec: Contains specs for which-key and herdr-agy", function()
    local specs = dofile(plugin_spec_path)
    local wk_spec = find_spec(specs, "folke/which-key.nvim")
    local main_spec = find_spec(specs, "herdr-agy.nvim")

    assert_true(wk_spec ~= nil, "folke/which-key.nvim spec exists")
    assert_true(main_spec ~= nil, "herdr-agy.nvim spec exists")
  end)

  -- 2. WHICHKEY INTEGRATION SPEC
  run_test("which_key_spec: Registers <leader>a group for AGY / Herdr", function()
    local specs = dofile(plugin_spec_path)
    local wk_spec = find_spec(specs, "folke/which-key.nvim")
    assert_true(wk_spec ~= nil and type(wk_spec.opts) == "table", "which-key opts is table")
    assert_true(type(wk_spec.opts.spec) == "table", "which-key opts.spec is table")

    local group_found = false
    for _, item in ipairs(wk_spec.opts.spec) do
      if item[1] == "<leader>a" and item.group == "AGY / Herdr" then
        group_found = true
        assert_true(type(item.mode) == "table", "mode is table")
        assert_true(vim.tbl_contains(item.mode, "n"), "mode contains 'n'")
        assert_true(vim.tbl_contains(item.mode, "v"), "mode contains 'v'")
      end
    end
    assert_true(group_found, "<leader>a AGY / Herdr group registered")
  end)

  -- 3. LAZY LOADING COMMAND TRIGGERS
  run_test("main_spec: Defines lazy loading cmd list", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "herdr-agy.nvim")
    assert_true(main_spec ~= nil and type(main_spec.cmd) == "table", "cmd property is table")

    local expected_cmds = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyDiff",
    }
    assert_eq(#main_spec.cmd, #expected_cmds, "contains exactly 5 commands")
    for _, cmd_name in ipairs(expected_cmds) do
      assert_true(vim.tbl_contains(main_spec.cmd, cmd_name), "cmd contains " .. cmd_name)
    end
  end)

  -- 4. LAZY LOADING KEYMAP BINDINGS
  run_test("main_spec: Defines lazy loading keys list", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "herdr-agy.nvim")
    assert_true(main_spec ~= nil and type(main_spec.keys) == "table", "keys property is table")

    local key_map = {}
    for _, k in ipairs(main_spec.keys) do
      key_map[k[1]] = k
    end

    assert_true(key_map["<leader>as"] ~= nil, "<leader>as keymap defined")
    assert_eq(key_map["<leader>as"][2], "<cmd>HerdrAgyStatus<cr>", "<leader>as command")
    assert_eq(key_map["<leader>as"].desc, "AGY Status", "<leader>as desc")

    assert_true(key_map["<leader>ac"] ~= nil, "<leader>ac keymap defined")
    assert_eq(key_map["<leader>ac"][2], "<cmd>HerdrAgySelectTarget<cr>", "<leader>ac command")

    assert_true(key_map["<leader>ad"] ~= nil, "<leader>ad keymap defined")
    assert_eq(key_map["<leader>ad"][2], "<cmd>HerdrAgyDiff<cr>", "<leader>ad command")

    assert_true(key_map["<leader>ap"] ~= nil, "<leader>ap keymap defined")
    assert_eq(key_map["<leader>ap"][2], "<cmd>HerdrAgyPrompt<cr>", "<leader>ap command")

    assert_true(key_map["<leader>at"] ~= nil, "<leader>at keymap defined")
    assert_eq(key_map["<leader>at"][2], "<cmd>HerdrAgySend<cr>", "<leader>at command")
  end)

  -- 5. DEFAULT OPTS & CONFIG FUNCTION SETUP
  run_test("main_spec: Default opts matches init.defaults", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "herdr-agy.nvim")
    assert_true(main_spec ~= nil and type(main_spec.opts) == "table", "opts is table")

    assert_eq(main_spec.opts.target_agent, "agy", "default target_agent")
    assert_eq(main_spec.opts.auto_discover, true, "default auto_discover")
    assert_nil(main_spec.opts.pane_override, "default pane_override")
    assert_true(type(main_spec.opts.notify) == "table", "default notify is table")
    assert_eq(main_spec.opts.notify.enabled, true, "default notify.enabled")
    assert_eq(main_spec.opts.notify.title, "herdr-agy.nvim", "default notify.title")
  end)

  run_test("main_spec: config function executes setup(opts) and creates user commands", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "herdr-agy.nvim")
    assert_true(main_spec ~= nil and type(main_spec.config) == "function", "config is function")

    local test_opts = { target_agent = "spec_test_agent" }
    main_spec.config(main_spec, test_opts)

    assert_eq(init.options.target_agent, "spec_test_agent", "setup called with test_opts")
    assert_true(vim.fn.exists(":HerdrAgyStatus") == 2, ":HerdrAgyStatus user command registered")
    assert_true(vim.fn.exists(":HerdrAgySelectTarget") == 2, ":HerdrAgySelectTarget user command registered")
    assert_true(vim.fn.exists(":HerdrAgyPrompt") == 2, ":HerdrAgyPrompt user command registered")
    assert_true(vim.fn.exists(":HerdrAgySend") == 2, ":HerdrAgySend user command registered")
    assert_true(vim.fn.exists(":HerdrAgyDiff") == 2, ":HerdrAgyDiff user command registered")
  end)

  return {
    passed = passed_count,
    failed = failed_count,
    failures = test_failures,
  }
end

if not _G.RUNNING_TEST_SUITE then
  local results = M.run()
  print("\n==========================================================")
  print(string.format("TEST RESULTS (test_plugin_spec): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
```
