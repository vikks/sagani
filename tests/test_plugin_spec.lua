-- Headless Neovim Unit Test Suite for herdr-agy.nvim LazyVim Spec & WhichKey Config
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local init = require("herdr-agy")

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
    for _, s in ipairs(specs) do
      if type(s) == "table" and (s[1] == name or s.name == name) then
        return s
      end
    end
    return nil
  end

  -- ==========================================================
  -- 1. SPEC TABLE STRUCTURE & EXPORTS
  -- ==========================================================

  run_test("plugin_spec: File exists and loads cleanly", function()
    assert_eq(vim.fn.filereadable(plugin_spec_path), 1, "plugins/herdr-agy.lua readable")
    local specs = dofile(plugin_spec_path)
    assert_true(type(specs) == "table", "returns lua table")
    assert_eq(#specs, 2, "spec array contains 2 elements")
  end)

  run_test("plugin_spec: Contains specs for which-key and herdr-agy", function()
    local specs = dofile(plugin_spec_path)
    local wk_spec = find_spec(specs, "folke/which-key.nvim")
    local main_spec = find_spec(specs, "herdr-agy.nvim")

    assert_true(wk_spec ~= nil, "folke/which-key.nvim spec exists")
    assert_true(main_spec ~= nil, "herdr-agy.nvim spec exists")
    assert_true(main_spec.dir ~= nil, "main spec dir is specified")
    assert_eq(main_spec.name, "herdr-agy.nvim", "main spec name is 'herdr-agy.nvim'")
  end)

  -- ==========================================================
  -- 2. WHICHKEY INTEGRATION SPEC
  -- ==========================================================

  run_test("which_key_spec: Registers <leader>a group for AGY / Herdr", function()
    local specs = dofile(plugin_spec_path)
    local wk_spec = find_spec(specs, "folke/which-key.nvim")
    assert_true(wk_spec ~= nil and type(wk_spec.opts) == "table", "which-key opts is table")
    assert_true(type(wk_spec.opts.spec) == "table", "which-key opts.spec is table")
    assert_eq(wk_spec.optional, true, "which-key spec is optional")

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

  -- ==========================================================
  -- 3. LAZY LOADING COMMAND TRIGGERS
  -- ==========================================================

  run_test("main_spec: Defines lazy loading cmd list", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "herdr-agy.nvim")
    assert_true(main_spec ~= nil and type(main_spec.cmd) == "table", "cmd property is table")

    local expected_cmds = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgySelectAgent",
      "HerdrAgySelectHarness",
      "HerdrAgySpawnPane",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyContext",
      "HerdrAgyDiff",
    }
    assert_eq(#main_spec.cmd, #expected_cmds, "contains expected commands count")
    for _, cmd_name in ipairs(expected_cmds) do
      assert_true(vim.tbl_contains(main_spec.cmd, cmd_name), "cmd contains " .. cmd_name)
    end
  end)

  -- ==========================================================
  -- 4. LAZY LOADING KEYMAP BINDINGS
  -- ==========================================================

  run_test("main_spec: Defines lazy loading keys list", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "herdr-agy.nvim")
    assert_true(main_spec ~= nil and type(main_spec.keys) == "table", "keys property is table")

    local function find_key(lhs, mode)
      for _, k in ipairs(main_spec.keys) do
        if k[1] == lhs then
          if mode == nil and k.mode == nil then
            return k
          elseif mode ~= nil and k.mode == mode then
            return k
          elseif mode ~= nil and type(k.mode) == "table" and vim.tbl_contains(k.mode, mode) then
            return k
          end
        end
      end
      return nil
    end

    local k_as_n = find_key("<leader>as", nil)
    assert_true(k_as_n ~= nil, "<leader>as normal keymap defined")
    assert_eq(k_as_n[2], "<cmd>HerdrAgyStatus<cr>", "<leader>as normal command")

    local k_as_v = find_key("<leader>as", "v")
    assert_true(k_as_v ~= nil, "<leader>as visual keymap defined")
    assert_eq(k_as_v[2], "<cmd>HerdrAgySend<cr>", "<leader>as visual command")

    local k_ac_v = find_key("<leader>ac", "v")
    assert_true(k_ac_v ~= nil, "<leader>ac visual keymap defined")
    assert_eq(k_ac_v[2], "<cmd>HerdrAgyContext<cr>", "<leader>ac visual command")

    local k_at = find_key("<leader>at", "v")
    assert_true(k_at ~= nil, "<leader>at keymap defined")
    assert_eq(k_at[2], "<cmd>HerdrAgySend<cr>", "<leader>at command")

    local k_an = find_key("<leader>an", "n")
    assert_true(k_an ~= nil, "<leader>an keymap defined")
    assert_eq(k_an[2], "<cmd>HerdrAgySpawnPane<cr>", "<leader>an command")

    local k_ah = find_key("<leader>ah", "n")
    assert_true(k_ah ~= nil, "<leader>ah keymap defined")
    assert_eq(k_ah[2], "<cmd>HerdrAgySelectAgent<cr>", "<leader>ah command")

    local k_aa = find_key("<leader>aa", "n")
    assert_true(k_aa ~= nil, "<leader>aa keymap defined")
    assert_eq(k_aa[2], "<cmd>HerdrAgySelectAgent<cr>", "<leader>aa command")
  end)

  -- ==========================================================
  -- 5. DEFAULT OPTS & CONFIG FUNCTION SETUP
  -- ==========================================================

  run_test("main_spec: Default opts matches init.defaults", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "herdr-agy.nvim")
    assert_true(main_spec ~= nil and type(main_spec.opts) == "table", "opts is table")

    assert_eq(main_spec.opts.target_agent, "agy", "default target_agent")
    assert_eq(main_spec.opts.auto_discover, true, "default auto_discover")
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
    assert_true(vim.fn.exists(":HerdrAgySelectAgent") == 2, ":HerdrAgySelectAgent user command registered")
    assert_true(vim.fn.exists(":HerdrAgySelectHarness") == 2, ":HerdrAgySelectHarness user command registered")
    assert_true(vim.fn.exists(":HerdrAgyPrompt") == 2, ":HerdrAgyPrompt user command registered")
    assert_true(vim.fn.exists(":HerdrAgySend") == 2, ":HerdrAgySend user command registered")
    assert_true(vim.fn.exists(":HerdrAgyContext") == 2, ":HerdrAgyContext user command registered")
    assert_true(vim.fn.exists(":HerdrAgyDiff") == 2, ":HerdrAgyDiff user command registered")
  end)

  run_test("select_agent_harness: direct argument sets target_agent and choice selection works", function()
    init.setup({ target_agent = "agy" })
    assert_eq(init.options.target_agent, "agy", "initial target_agent is agy")

    init.select_agent_harness("codex")
    assert_eq(init.options.target_agent, "codex", "explicit arg sets target_agent to codex")

    init.select_agent_harness("opencode")
    assert_eq(init.options.target_agent, "opencode", "explicit arg sets target_agent to opencode")

    init.select_agent_harness("hermes")
    assert_eq(init.options.target_agent, "hermes", "explicit arg sets target_agent to hermes")
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
