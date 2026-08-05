-- Headless Neovim Adversarial Test Suite for sagani.nvim LazyVim Spec (M2)
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
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
  -- 1. ADVERSARIAL: MISSING WHICHKEY EVALUATION
  -- ==========================================================

  run_test("adversarial_whichkey: plugin spec evaluates when which-key is unloaded", function()
    -- Temporarily ensure which-key is un-required
    package.loaded["which-key"] = nil
    package.loaded["folke/which-key.nvim"] = nil

    local ok, specs = pcall(dofile, plugin_spec_path)
    assert_true(ok, "plugins/sagani.lua executes cleanly without which-key loaded")
    assert_true(type(specs) == "table" and #specs == 2, "returns spec array with 2 entries")

    local wk_spec = find_spec(specs, "folke/which-key.nvim")
    assert_true(wk_spec ~= nil, "which-key spec present in array")
    assert_eq(wk_spec.optional, true, "which-key spec is optional=true")

    -- Ensure lazy.nvim can filter or evaluate specs independently
    local main_spec = find_spec(specs, "sagani.nvim")
    assert_true(main_spec ~= nil, "main spec present independently of which-key")
  end)

  run_test("adversarial_whichkey: which-key spec structure resilience", function()
    local specs = dofile(plugin_spec_path)
    local wk_spec = find_spec(specs, "folke/which-key.nvim")
    assert_true(type(wk_spec.opts) == "table", "wk_spec.opts is a table")
    assert_true(type(wk_spec.opts.spec) == "table", "wk_spec.opts.spec is a table")
    assert_eq(#wk_spec.opts.spec, 1, "wk_spec.opts.spec has 1 item")

    local group_item = wk_spec.opts.spec[1]
    assert_eq(group_item[1], "<leader>a", "group prefix is <leader>a")
    assert_eq(group_item.group, "Sagani", "group name is Sagani")
  end)

  -- ==========================================================
  -- 2. ADVERSARIAL: CUSTOM USER OPTIONS
  -- ==========================================================

  run_test("adversarial_opts: custom options table merging and overrides", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")

    local custom_opts = {
      target_agent = "my_custom_agy",
      auto_discover = false,
      pane_override = "pane_123",
      notify = { enabled = false, title = "Custom AGY Title" },
      extra_unknown_field = 999,
    }

    main_spec.config(main_spec, custom_opts)

    assert_eq(init.options.target_agent, "my_custom_agy", "custom target_agent preserved")
    assert_eq(init.options.auto_discover, false, "custom auto_discover preserved")
    assert_eq(init.options.pane_override, "pane_123", "custom pane_override preserved")
    assert_eq(init.options.notify.enabled, false, "custom notify.enabled preserved")
    assert_eq(init.options.notify.title, "Custom AGY Title", "custom notify.title preserved")
    assert_eq(init.options.extra_unknown_field, 999, "extra unknown field preserved")
  end)

  run_test("adversarial_opts: partial user options leave defaults intact", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")

    main_spec.config(main_spec, { target_agent = "partial_agent" })

    assert_eq(init.options.target_agent, "partial_agent", "target_agent updated")
    assert_eq(init.options.auto_discover, true, "auto_discover defaults to true")
    assert_nil(init.options.pane_override, "pane_override defaults to nil")
    assert_eq(init.options.notify.enabled, true, "notify.enabled defaults to true")
  end)

  -- ==========================================================
  -- 3. ADVERSARIAL: KEYMAP MODE CONFLICTS & COMMAND EXECUTION
  -- ==========================================================

  run_test("adversarial_keymaps: keymap modes in spec and command coverage", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")

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
    local k_as_v = find_key("<leader>as", "v")
    local k_ac_n = find_key("<leader>ac", nil)
    local k_ac_v = find_key("<leader>ac", "v")
    local k_ad = find_key("<leader>ad", "n")
    local k_ap = find_key("<leader>ap", "n")
    local k_at = find_key("<leader>at", "v")

    -- Verify mode assignments
    assert_true(k_as_n ~= nil and k_as_n.mode == nil, "<leader>as has normal mode entry (mode = nil)")
    assert_true(k_as_v ~= nil and k_as_v.mode == "v", "<leader>as has visual mode entry (mode = 'v')")
    assert_true(k_ac_n ~= nil and k_ac_n.mode == nil, "<leader>ac has normal mode entry (mode = nil)")
    assert_true(k_ac_v ~= nil and k_ac_v.mode == "v", "<leader>ac has visual mode entry (mode = 'v')")
    assert_true(vim.tbl_contains(k_ad.mode, "n"), "<leader>ad contains mode 'n'")
    assert_true(vim.tbl_contains(k_ad.mode, "v"), "<leader>ad contains mode 'v'")
    assert_true(vim.tbl_contains(k_ap.mode, "n"), "<leader>ap contains mode 'n'")
    assert_true(vim.tbl_contains(k_ap.mode, "v"), "<leader>ap contains mode 'v'")
    assert_eq(k_at.mode, "v", "<leader>at mode is visual only ('v')")
  end)

  run_test("adversarial_keymaps: user commands execution from normal mode", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")
    main_spec.config(main_spec, { notify = { enabled = false } })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      if type(cb) == "function" then
        cb("test instruction")
      end
    end

    -- Test executing user commands without error
    local ok1 = pcall(vim.cmd, "SaganiStatus")
    assert_true(ok1, "SaganiStatus executes in normal mode")

    local ok2 = pcall(vim.cmd, "SaganiSend")
    assert_true(ok2, "SaganiSend executes in normal mode")

    local ok3 = pcall(vim.cmd, "SaganiContext")
    assert_true(ok3, "SaganiContext executes in normal mode")

    local ok4 = pcall(vim.cmd, "SaganiDiff")
    assert_true(ok4, "SaganiDiff executes in normal mode")

    vim.ui.input = orig_input
  end)

  run_test("adversarial_keymaps: user commands range execution in visual mode", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")
    main_spec.config(main_spec, { notify = { enabled = false } })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      if type(cb) == "function" then
        cb("test instruction")
      end
    end

    -- Create a test buffer and select lines
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
    vim.api.nvim_set_current_buf(buf)

    -- Test range command execution with range
    local ok1 = pcall(vim.cmd, "1,2SaganiSend")
    assert_true(ok1, "1,2SaganiSend with range succeeds (range = true)")

    local ok1_ctx = pcall(vim.cmd, "1,2SaganiContext")
    assert_true(ok1_ctx, "1,2SaganiContext with range succeeds (range = true)")

    -- Test whether SaganiDiff or SaganiPrompt accept ranges
    local ok2, err2 = pcall(vim.cmd, "1,2SaganiDiff")
    -- Note: SaganiDiff lacks range = true, so command mode visual ranges fail with E481
    print("  ℹ Note: 1,2SaganiDiff with range ok=" .. tostring(ok2) .. (err2 and (" err=" .. tostring(err2)) or ""))

    local ok3, err3 = pcall(vim.cmd, "1,2SaganiPrompt Test")
    print("  ℹ Note: 1,2SaganiPrompt with range ok=" .. tostring(ok3) .. (err3 and (" err=" .. tostring(err3)) or ""))

    vim.ui.input = orig_input
  end)

  run_test("adversarial_ask_agent: SaganiAskAgent user command execution in normal and visual modes", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")
    main_spec.config(main_spec, { ask_agent = { target_agent = "agy" }, notify = { enabled = false } })

    local orig_input = vim.ui.input
    vim.ui.input = function(opts, cb)
      if type(cb) == "function" then
        cb("Explain this component")
      end
    end

    local ok_normal = pcall(vim.cmd, "SaganiAskAgent What is this function?")
    assert_true(ok_normal, "SaganiAskAgent with prompt argument in normal mode succeeds")

    local ok_interactive = pcall(vim.cmd, "SaganiAskAgent")
    assert_true(ok_interactive, "SaganiAskAgent without prompt argument (interactive) in normal mode succeeds")

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "line 1", "line 2", "line 3" })
    vim.api.nvim_set_current_buf(buf)
    vim.fn.setpos("'<", { buf, 1, 1, 0 })
    vim.fn.setpos("'>", { buf, 2, 6, 0 })

    local ok_visual = pcall(vim.cmd, "'<,'>SaganiAskAgent Explain range")
    assert_true(ok_visual, "'<,'>SaganiAskAgent with visual range succeeds (range = true)")

    local ok_num_range = pcall(vim.cmd, "1,2SaganiAskAgent Explain range")
    assert_true(ok_num_range, "1,2SaganiAskAgent with numeric range succeeds")

    vim.ui.input = orig_input
  end)

  -- ==========================================================
  -- 4. ADVERSARIAL: INVALID CONFIG CALLBACK PARAMETERS
  -- ==========================================================

  run_test("adversarial_config: handles nil opts without crashing", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")

    local ok = pcall(main_spec.config, main_spec, nil)
    assert_true(ok, "config(spec, nil) executes without exception")
    assert_eq(init.options.tasks.ask, "agy", "options fall back to defaults")
  end)

  run_test("adversarial_config: handles primitive non-table opts without crashing", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")

    local ok_str = pcall(main_spec.config, main_spec, "string_opts")
    assert_true(ok_str, "config(spec, 'string') succeeds")

    local ok_num = pcall(main_spec.config, main_spec, 12345)
    assert_true(ok_num, "config(spec, 12345) succeeds")

    local ok_bool = pcall(main_spec.config, main_spec, false)
    assert_true(ok_bool, "config(spec, false) succeeds")
  end)

  run_test("adversarial_config: handles invalid first argument (nil or dummy)", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")

    local ok = pcall(main_spec.config, nil, { target_agent = "dummy_agent" })
    assert_true(ok, "config(nil, opts) succeeds since first argument is unused")
    assert_eq(init.options.target_agent, "dummy_agent", "opts applied correctly")
  end)

  run_test("adversarial_config: handles invalid types inside opts fields", function()
    local specs = dofile(plugin_spec_path)
    local main_spec = find_spec(specs, "sagani.nvim")

    local invalid_inner_opts = {
      target_agent = nil, -- nil field in table
      auto_discover = "invalid_boolean",
      notify = "not_a_table_or_boolean",
    }

    local ok = pcall(main_spec.config, main_spec, invalid_inner_opts)
    assert_true(ok, "config with invalid inner field types executes without exception")
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
  print(string.format("TEST RESULTS (test_adversarial_m2): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
