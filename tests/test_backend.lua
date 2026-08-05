local backend = require("sagani.backend")

local M = {}

function M.run()
  local sagani = pcall(require, "sagani") and require("sagani") or {}
  sagani._session_harness = nil
  sagani._session_model = nil
  sagani._session_effort = nil

  local passed = 0
  local failed = 0
  local failures = {}

  local function test(desc, fn)
    local ok, err = pcall(fn)
    if ok then
      passed = passed + 1
      print("Running Test: " .. desc .. "  ✓ PASS")
    else
      failed = failed + 1
      table.insert(failures, desc .. " - " .. tostring(err))
      print("Running Test: " .. desc .. "  ✗ FAIL: " .. tostring(err))
    end
  end

  test("registers and retrieves custom backend adapters", function()
    local custom_adapter = {
      name = "dummy",
      detect_env = function() return { active = true, id = "d1" } end,
      discover_target = function() return "d1", nil, {} end,
      spawn_pane = function() return "d1", nil, {} end,
      spawn_popup = function() return "d1_pop", nil, {} end,
      prompt_target = function() return true, nil end,
    }

    backend.register("dummy", custom_adapter)
    local retrieved, name = backend.get_backend({ backend = "dummy" })
    assert(name == "dummy", "Expected name dummy")
    assert(retrieved == custom_adapter, "Expected custom_adapter")
  end)

  test("auto-detects native backend when outside Herdr/Tmux/Zellij", function()
    local original_herdr = vim.env.HERDR_ENV
    local original_tmux = vim.env.TMUX
    local original_zellij = vim.env.ZELLIJ
    vim.env.HERDR_ENV = nil
    vim.env.TMUX = nil
    vim.env.ZELLIJ = nil

    local adapter, name = backend.get_backend({ backend = "auto" })
    assert(name == "native", "Expected native backend auto-detected")
    assert(adapter ~= nil, "Adapter should not be nil")

    vim.env.HERDR_ENV = original_herdr
    vim.env.TMUX = original_tmux
    vim.env.ZELLIJ = original_zellij
  end)

  test("detects tmux backend when TMUX env is active", function()
    local original_tmux = vim.env.TMUX
    local original_herdr = vim.env.HERDR_ENV
    vim.env.HERDR_ENV = nil
    vim.env.TMUX = "/tmp/tmux-1000/default,1234,0"

    local adapter, name = backend.get_backend({ backend = "auto" })
    assert(name == "tmux", "Expected tmux backend auto-detected")
    assert(adapter ~= nil, "Adapter should not be nil")

    vim.env.TMUX = original_tmux
    vim.env.HERDR_ENV = original_herdr
  end)

  test("detects zellij backend when ZELLIJ env is active", function()
    local original_herdr = vim.env.HERDR_ENV
    local original_tmux = vim.env.TMUX
    local original_zellij = vim.env.ZELLIJ
    vim.env.HERDR_ENV = nil
    vim.env.TMUX = nil
    vim.env.ZELLIJ = "1"

    local adapter, name = backend.get_backend({ backend = "auto" })
    assert(name == "zellij", "Expected zellij backend auto-detected")
    assert(adapter ~= nil, "Adapter should not be nil")

    vim.env.HERDR_ENV = original_herdr
    vim.env.TMUX = original_tmux
    vim.env.ZELLIJ = original_zellij
  end)

  test("falls back from Herdr to native for 'ask' task when herdr.ask is false", function()
    local original_herdr = vim.env.HERDR_ENV
    vim.env.HERDR_ENV = "1"

    local opts = {
      backends = {
        herdr = { ask = false, code = "right-pane" },
        native = { ask = "popup" },
      },
    }

    local adapter, name, placement = backend.get_backend(opts, "ask")
    assert(name == "native", "Expected fallback to native for ask task")
    assert(placement == "popup", "Expected native popup placement")

    -- For code task, Herdr should be used
    local code_adapter, code_name, code_placement = backend.get_backend(opts, "code")
    assert(code_name == "herdr", "Expected herdr backend for code task")
    assert(code_placement == "right-pane", "Expected right-pane placement")

    vim.env.HERDR_ENV = original_herdr
  end)

  test("resolves short-form task string harness names and flat UI window_opts overrides", function()
    local original_herdr = vim.env.HERDR_ENV
    vim.env.HERDR_ENV = "1"

    local opts = {
      tasks = {
        code = "opencode",
        ask = { harness = "agy", provider = "google", model = "pro", effort = "high" },
      },
      window_opts = {
        width = 0.85,
        border = "double",
      },
      backends = {
        herdr = {
          review = "left-pane",
          ratio = 0.25,
        },
      },
    }

    local _, _, review_place, ui_opts, agent_opts = backend.get_backend(opts, "code")
    assert(agent_opts.harness == "opencode", "Expected task harness 'opencode' from short-form string")

    local _, _, _, ask_ui, ask_agent = backend.get_backend(opts, "ask")
    assert(ask_agent.harness == "agy", "Expected harness agy")
    assert(ask_agent.provider == "google", "Expected provider google")
    assert(ask_agent.model == "pro", "Expected model pro")
    assert(ask_agent.effort == "high", "Expected effort high")

    assert(ask_ui.width == 0.85, "Expected window_opts width 0.85")
    assert(ask_ui.border == "double", "Expected window_opts border double")
    local _, _, _, code_ui, _ = backend.get_backend(opts, "code")
    assert(code_ui.ratio == 0.25, "Expected herdr flat ratio override 0.25")

    vim.env.HERDR_ENV = original_herdr
  end)

  test("built-in backend adapters implement wait_for_ready contract", function()
    local names = { "native", "herdr", "tmux", "zellij" }
    for _, bname in ipairs(names) do
      local adapter = backend.backends[bname]
      assert(adapter ~= nil, "Adapter " .. bname .. " exists")
      assert(type(adapter.wait_for_ready) == "function", "Adapter " .. bname .. " implements wait_for_ready")
      local ok = adapter.wait_for_ready("p1", { timeout_ms = 100 })
      assert(ok == true or ok == false, "wait_for_ready returns boolean")
    end
  end)

  test("resolve_task_agent resolves from opts.agents registry", function()
    local test_opts = {
      agents = {
        codex_fast = {
          harness = "codex",
          cmd = { "codex", "--model", "gpt-4o-mini" },
          name = "Codex Fast",
        },
      },
      tasks = {
        review = { agent = "codex_fast" },
      },
    }
    local res = backend.resolve_task_agent(test_opts, "review")
    assert(res.harness == "codex", "harness resolved to codex")
    assert(res.alias == "Codex Fast", "alias resolved to Codex Fast")
    assert(res.cmd[1] == "codex" and res.cmd[2] == "--model", "cmd array preserved")
    assert(backend.resolve_agent_cmd(res) == "codex --model gpt-4o-mini", "resolve_agent_cmd produces string")
  end)

  test("resolve_task_agent resolves inline agent table with custom cmd", function()
    local test_opts = {
      tasks = {
        code = {
          agent = {
            harness = "opencode",
            cmd = { "opencode", "--port", "4096", "--model", "deepseek-r1" },
            name = "Opencode DeepSeek",
          },
        },
      },
    }
    local res = backend.resolve_task_agent(test_opts, "code")
    assert(res.harness == "opencode", "harness resolved to opencode")
    assert(res.alias == "Opencode DeepSeek", "alias resolved to Opencode DeepSeek")
    assert(backend.resolve_agent_cmd(res) == "opencode --port 4096 --model deepseek-r1", "resolve_agent_cmd produces string")
  end)

  test("resolves task-level backend override and obtains placement from backend table", function()
    local original_herdr = vim.env.HERDR_ENV
    vim.env.HERDR_ENV = "1"

    local opts = {
      tasks = {
        ask = { agent = "opencode", backend = "native" },
        review = { agent = "codex", backend = "herdr" },
        code = { agent = "opencode" }, -- Omitted backend defaults to "auto"
      },
      backends = {
        native = { ask = "popup" },
        herdr = { review = "right-pane", code = "right-pane" },
      },
    }

    local _, ask_name, ask_place = backend.get_backend(opts, "ask")
    assert(ask_name == "native", "Expected explicit task backend 'native' for ask")
    assert(ask_place == "popup", "Expected native backend placement 'popup' for ask")

    local _, rev_name, rev_place = backend.get_backend(opts, "review")
    assert(rev_name == "herdr", "Expected explicit task backend 'herdr' for review")
    assert(rev_place == "right-pane", "Expected herdr backend placement 'right-pane' for review")

    local _, code_name = backend.get_backend(opts, "code")
    assert(code_name == "herdr", "Expected auto-detected herdr for code task")

    vim.env.HERDR_ENV = original_herdr
  end)

  return { passed = passed, failed = failed, failures = failures }
end

return M
