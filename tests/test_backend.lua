local backend = require("sagani.backend")

local M = {}

function M.run()
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
      tasks = { ask = false, code = "right-pane" },
      backends = {
        herdr = { ask = false },
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

  test("supports backend-specific task placement overrides and custom task keys", function()
    local original_herdr = vim.env.HERDR_ENV
    vim.env.HERDR_ENV = "1"

    local opts = {
      tasks = {
        review = "right-pane",
        custom_task = "tab",
      },
      backends = {
        herdr = {
          review = "left-pane",
        },
      },
    }

    local _, _, review_place = backend.get_backend(opts, "review")
    assert(review_place == "left-pane", "Expected backend-specific override 'left-pane'")

    local _, _, custom_place = backend.get_backend(opts, "custom_task")
    assert(custom_place == "tab", "Expected shared task default 'tab' for custom task key")

    vim.env.HERDR_ENV = original_herdr
  end)

  return { passed = passed, failed = failed, failures = failures }
end

return M
