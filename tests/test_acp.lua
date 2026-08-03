-- Headless Neovim Unit Test Suite for sagani.nvim ACP Protocol & Markdown Popup UI
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local init = require("sagani")
local acp = require("sagani.protocol.acp")
local markdown_popup = require("sagani.ui.markdown_popup")

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

  -- ==========================================================
  -- 1. ACP COMMAND BUILDER & TRANSPORT TESTS
  -- ==========================================================

  run_test("acp.build_acp_command: builds command arrays for agy, codex, opencode, hermes", function()
    local cmd_agy = acp.build_acp_command("agy", "test prompt", { model = "pro" })
    assert_eq(cmd_agy[1], "agy", "agy binary name")
    assert_eq(cmd_agy[2], "prompt", "agy subcommand")
    assert_eq(cmd_agy[3], "test prompt", "agy prompt text")
    assert_eq(cmd_agy[4], "--non-interactive", "agy non-interactive flag")
    assert_eq(cmd_agy[5], "--model", "agy model flag")
    assert_eq(cmd_agy[6], "pro", "agy model pro")

    local cmd_codex = acp.build_acp_command("codex", "codex prompt")
    assert_eq(cmd_codex[1], "codex", "codex binary name")
    assert_eq(cmd_codex[2], "exec", "codex subcommand")

    local cmd_opencode = acp.build_acp_command("opencode", "opencode prompt")
    assert_eq(cmd_opencode[1], "opencode", "opencode binary name")
    assert_eq(cmd_opencode[2], "run", "opencode subcommand")
  end)

  run_test("acp.execute_prompt: mock runner execution returns response text", function()
    local mock_runner = function(cmd)
      assert_eq(cmd[1], "agy", "cmd binary agy")
      return "Hello from ACP mock agent!", 0
    end

    local result_text = nil
    local result_err = nil

    acp.execute_prompt("agy", "Hello", {}, function(resp, err)
      result_text = resp
      result_err = err
    end, { runner = mock_runner })

    assert_eq(result_text, "Hello from ACP mock agent!", "ACP response text captured")
    assert_eq(result_err, nil, "ACP error is nil on success")
  end)

  -- ==========================================================
  -- 2. MARKDOWN POPUP UI TESTS
  -- ==========================================================

  run_test("markdown_popup.open: creates markdown floating buffer with keymaps", function()
    local win, buf = markdown_popup.open("Test Popup", { ui_opts = { width = 0.7, height = 0.7, border = "double" } })
    assert_true(vim.api.nvim_win_is_valid(win), "window handle valid")
    assert_true(vim.api.nvim_buf_is_valid(buf), "buffer handle valid")
    assert_eq(vim.bo[buf].filetype, "markdown", "buffer filetype is markdown")
    assert_eq(vim.bo[buf].buftype, "nofile", "buffer buftype is nofile")

    markdown_popup.set_prompt_header(buf, "What is Rust ownership?", "agy")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    assert_true(text:find("User Prompt") ~= nil, "prompt header contains User Prompt")
    assert_true(text:find("What is Rust ownership?") ~= nil, "prompt header contains question")

    markdown_popup.set_response(buf, "Ownership is Rust's memory management feature.")
    local updated_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local updated_text = table.concat(updated_lines, "\n")
    assert_true(updated_text:find("Ownership is Rust's memory management feature.") ~= nil, "response text updated")

    pcall(vim.api.nvim_win_close, win, true)
  end)

  -- ==========================================================
  -- 3. ASK_AGENT ACP INTEGRATION TEST
  -- ==========================================================

  run_test("ask_agent_prompt: routes acp protocol tasks through markdown_popup", function()
    init.setup({
      tasks = {
        ask = { protocol = "acp" },
      },
      notify = { enabled = false },
    })

    local mock_runner = function(cmd)
      return "ACP response content for ask_agent_prompt", 0
    end

    init.ask_agent_prompt("Test ACP question", { runner = mock_runner, notify = { enabled = false } })

    local active_buf = nil
    for buf_handle, _ in pairs(markdown_popup._active_wins) do
      if vim.api.nvim_buf_is_valid(buf_handle) then
        active_buf = buf_handle
        break
      end
    end

    assert_true(active_buf ~= nil, "active markdown buffer created")
    assert_eq(vim.bo[active_buf].filetype, "markdown", "ACP ask_agent_prompt opens markdown buffer")

    local text = table.concat(vim.api.nvim_buf_get_lines(active_buf, 0, -1, false), "\n")
    assert_true(text:find("ACP response content for ask_agent_prompt") ~= nil, "buffer contains ACP response text")

    pcall(vim.api.nvim_win_close, current_win, true)
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
  print(string.format("TEST RESULTS (test_acp): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
