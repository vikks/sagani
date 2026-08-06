-- Headless Neovim Unit Test Suite for sagani.nvim LazyVim Spec & WhichKey Config
local project_root = _G.SAGANI_PROJECT_ROOT or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local init = require("sagani")

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

  local plugin_spec_path = project_root .. "/plugins/sagani.lua"

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
    assert_eq(vim.fn.filereadable(plugin_spec_path), 1, "plugins/sagani.lua readable")
    local specs = dofile(plugin_spec_path)
    assert_true(type(specs) == "table", "returns lua table")
    assert_eq(#specs, 2, "spec array contains 2 elements")
  end)

  run_test("plugin_spec: Contains specs for which-key and sagani", function()
    local specs = dofile(plugin_spec_path)
    local wk_spec = find_spec(specs, "folke/which-key.nvim")
    local main_spec = find_spec(specs, "sagani.nvim")

    assert_true(wk_spec ~= nil, "folke/which-key.nvim spec exists")
    assert_true(main_spec ~= nil, "sagani.nvim spec exists")
    assert_true(main_spec.dir ~= nil, "main spec dir is specified")
    assert_eq(main_spec.name, "sagani.nvim", "main spec name is 'sagani.nvim'")
  end)

  -- ==========================================================
  -- 2. WHICHKEY INTEGRATION SPEC
  -- ==========================================================

  run_test("which_key_spec: Registers <leader>a group for Sagani", function()
    local specs = dofile(plugin_spec_path)
    local wk_spec = find_spec(specs, "folke/which-key.nvim")
    assert_true(wk_spec ~= nil and type(wk_spec.opts) == "table", "which-key opts is table")
    assert_true(type(wk_spec.opts.spec) == "table", "which-key opts.spec is table")
    assert_eq(wk_spec.optional, true, "which-key spec is optional")

    local group_found = false
    for _, item in ipairs(wk_spec.opts.spec) do
      if item[1] == "<leader>a" and item.group == "Sagani" then
        group_found = true
        assert_true(type(item.mode) == "table", "mode is table")
        assert_true(vim.tbl_contains(item.mode, "n"), "mode contains 'n'")
        assert_true(vim.tbl_contains(item.mode, "v"), "mode contains 'v'")
      end
    end
    assert_true(group_found, "<leader>a Sagani group registered")
  end)

  -- ==========================================================
  -- 3. LAZY LOADING COMMAND TRIGGERS
  -- ==========================================================

  run_test("main_spec: Defines lazy loading cmd list", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")
    assert_true(main_spec ~= nil and type(main_spec.cmd) == "table", "cmd property is table")

    local expected_cmds = {
      "SaganiStatus",
      "SaganiSelectTarget",
      "SaganiSelectAgent",
      "SaganiAskAgent",
      "SaganiSelectHarness",
      "SaganiSpawnPane",
      "SaganiPrompt",
      "SaganiSend",
      "SaganiContext",
      "SaganiDiff",
      "SaganiReview",
      "SaganiReviewToggle",
      "SaganiAccept",
      "SaganiAcceptHunk",
      "SaganiAcceptAll",
      "SaganiReject",
      "SaganiRejectHunk",
      "SaganiRejectAll",
      "SaganiNextHunk",
      "SaganiPrevHunk",
      "SaganiReload",
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
    local main_spec = find_spec(specs, "sagani.nvim")
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
    assert_eq(k_as_n[2], "<cmd>SaganiStatus<cr>", "<leader>as normal command")

    local k_as_v = find_key("<leader>as", "v")
    assert_true(k_as_v ~= nil, "<leader>as visual keymap defined")
    assert_eq(k_as_v[2], "<cmd>SaganiSend<cr>", "<leader>as visual command")

    local k_ac_v = find_key("<leader>ac", "v")
    assert_true(k_ac_v ~= nil, "<leader>ac visual keymap defined")
    assert_eq(k_ac_v[2], "<cmd>SaganiContext<cr>", "<leader>ac visual command")

    local k_at = find_key("<leader>at", "v")
    assert_true(k_at ~= nil, "<leader>at keymap defined")
    assert_eq(k_at[2], "<cmd>SaganiSend<cr>", "<leader>at command")

    local k_an = find_key("<leader>an", "n")
    assert_true(k_an ~= nil, "<leader>an keymap defined")
    assert_eq(k_an[2], "<cmd>SaganiSpawnPane<cr>", "<leader>an command")

    local k_ah = find_key("<leader>ah", "n")
    assert_true(k_ah ~= nil, "<leader>ah keymap defined")
    assert_eq(k_ah[2], "<cmd>SaganiSelectAgent<cr>", "<leader>ah command")

    local k_aa = find_key("<leader>aa", "n")
    assert_true(k_aa ~= nil, "<leader>aa keymap defined")
    assert_eq(k_aa[2], "<cmd>SaganiAskAgent<cr>", "<leader>aa command")
  end)

  -- ==========================================================
  -- 5. DEFAULT OPTS & CONFIG FUNCTION SETUP
  -- ==========================================================

  run_test("main_spec: Default opts matches init.defaults", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")
    assert_true(main_spec ~= nil and type(main_spec.opts) == "table", "opts is table")

    assert_eq(main_spec.opts.tasks.ask.agent, "agy", "default task ask agy")
    assert_eq(main_spec.opts.auto_discover, true, "default auto_discover")
  end)

  run_test("main_spec: config function executes setup(opts) and creates user commands", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")
    assert_true(main_spec ~= nil and type(main_spec.config) == "function", "config is function")

    local test_opts = { tasks = { ask = "spec_test_agent" } }
    main_spec.config(main_spec, test_opts)

    assert_eq(init.options.tasks.ask, "spec_test_agent", "setup called with test_opts")
    assert_true(vim.fn.exists(":SaganiStatus") == 2, ":SaganiStatus user command registered")
    assert_true(vim.fn.exists(":SaganiSelectTarget") == 2, ":SaganiSelectTarget user command registered")
    assert_true(vim.fn.exists(":SaganiSelectAgent") == 2, ":SaganiSelectAgent user command registered")
    assert_true(vim.fn.exists(":SaganiSelectHarness") == 2, ":SaganiSelectHarness user command registered")
    assert_true(vim.fn.exists(":SaganiPrompt") == 2, ":SaganiPrompt user command registered")
    assert_true(vim.fn.exists(":SaganiSend") == 2, ":SaganiSend user command registered")
    assert_true(vim.fn.exists(":SaganiContext") == 2, ":SaganiContext user command registered")
    assert_true(vim.fn.exists(":SaganiDiff") == 2, ":SaganiDiff user command registered")
  end)

  run_test("minimal_setup: setup({}) registers default keymaps and user commands cleanly", function()
    init.setup({})
    assert_eq(init.options.tasks.ask.agent, "agy", "minimal setup retains default task ask agy")
    assert_eq(init.options.default_keymaps, true, "default_keymaps enabled")

    local maps = vim.api.nvim_get_keymap("n")
    local found_as_map = false
    for _, map in ipairs(maps) do
      if map.rhs and map.rhs:find("SaganiStatus", 1, true) then
        found_as_map = true
      end
    end
    assert_true(found_as_map, "default <leader>as keymap registered in normal mode")
  end)

  run_test("custom_setup: setup(user_opts) merges custom settings and propagates to options table", function()
    init.setup({
      tasks = { ask = "hermes" },
      auto_spawn = false,
      startup_delay = 9999,
      pane_override = "w3:p12",
      notify = { enabled = false, title = "custom title" },
    })

    assert_eq(init.options.tasks.ask, "hermes", "tasks.ask overridden to hermes")
    assert_eq(init.options.auto_spawn, false, "auto_spawn overridden to false")
    assert_eq(init.options.startup_delay, 9999, "startup_delay overridden to 9999")
    assert_eq(init.options.pane_override, "w3:p12", "pane_override set to w3:p12")
    assert_eq(init.options.notify.enabled, false, "notify.enabled set to false")
    assert_eq(init.options.notify.title, "custom title", "notify.title overridden to custom title")
  end)

  run_test("select_agent_harness: direct argument sets _session_harness and choice selection works", function()
    init.setup({ tasks = { ask = "agy" } })
    assert_eq(init._session_harness, nil, "initial session harness is nil")

    init.select_agent_harness("codex")
    assert_eq(init._session_harness, "codex", "explicit arg sets _session_harness to codex")

    init.select_agent_harness("opencode")
    assert_eq(init._session_harness, "opencode", "explicit arg sets _session_harness to opencode")

    init.select_agent_harness("hermes")
    assert_eq(init._session_harness, "hermes", "explicit arg sets _session_harness to hermes")

    local backend_lib = require("sagani.backend")
    local _, _, _, _, agent_opts = backend_lib.get_backend(init.options, "chat")
    assert_eq(agent_opts.harness, "hermes", "backend.get_backend resolves target_agent hermes for chat task")
  end)

  run_test("ask_agent_config: setup() merges tasks.ask defaults and user overrides", function()
    init.setup({})
    local task_agent = require("sagani.backend").resolve_task_agent(init.options, "ask")
    assert_eq(task_agent.agent, "agy", "default tasks.ask agent is agy")

    init.setup({
      tasks = {
        ask = {
          agent = "opencode",
        },
      },
    })
    local overridden_task_agent = require("sagani.backend").resolve_task_agent(init.options, "ask")
    assert_eq(overridden_task_agent.agent, "opencode", "user override tasks.ask agent set to opencode")
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
