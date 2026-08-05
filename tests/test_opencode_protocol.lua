-- Headless Neovim Unit Test Suite for sagani.nvim opencode HTTP protocol module
local project_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. package.path

local opencode_http = require("sagani.protocol.http.opencode")

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
  -- 1. HTTP RESPONSE PARSING TESTS
  -- ==========================================================

  run_test("opencode.send_message: handles curl connection error (code != 0) with stderr message", function()
    local orig_system = vim.system
    vim.system = function(cmd, opts, cb)
      if cb then
        cb({ code = 7, stdout = "", stderr = "curl: (7) Connection refused" })
      end
      return { wait = function() return { code = 7, stdout = "", stderr = "curl: (7) Connection refused" } end }
    end

    local received_text, received_err
    opencode_http.send_message("http://127.0.0.1:4096", "sess_123", "hi", function(resp, err)
      received_text = resp
      received_err = err
    end)

    vim.wait(500, function() return received_err ~= nil end)
    vim.system = orig_system

    assert_eq(received_text, nil, "received_text is nil on connection error")
    assert_true(received_err ~= nil, "received_err is captured from stderr")
  end)

  run_test("opencode.send_message: parses standard JSON parts response", function()
    local mock_stdout = vim.json.encode({
      parts = { { type = "text", text = "Hello from OpenCode ACP" } },
    })

    local orig_system = vim.system
    vim.system = function(cmd, opts, cb)
      if cb then
        cb({ code = 0, stdout = mock_stdout, stderr = "" })
      end
      return { wait = function() return { code = 0, stdout = mock_stdout } end }
    end

    local resp_text, resp_err
    opencode_http.send_message("http://127.0.0.1:4096", "sess_123", "hi", function(resp, err)
      resp_text = resp
      resp_err = err
    end)

    vim.wait(500, function() return resp_text ~= nil end)
    vim.system = orig_system

    assert_eq(resp_text, "Hello from OpenCode ACP", "parses parts text response")
    assert_eq(resp_err, nil, "no error on valid response")
  end)

  run_test("opencode.send_message: parses direct text JSON response fields (content, text, response)", function()
    local mock_stdout = vim.json.encode({ content = "Direct content text" })

    local orig_system = vim.system
    vim.system = function(cmd, opts, cb)
      if cb then
        cb({ code = 0, stdout = mock_stdout, stderr = "" })
      end
      return { wait = function() return { code = 0, stdout = mock_stdout } end }
    end

    local resp_text, resp_err
    opencode_http.send_message("http://127.0.0.1:4096", "sess_123", "hi", function(resp, err)
      resp_text = resp
      resp_err = err
    end)

    vim.wait(500, function() return resp_text ~= nil end)
    vim.system = orig_system

    assert_eq(resp_text, "Direct content text", "parses direct content text response")
    assert_eq(resp_err, nil, "no error on valid response")
  end)

  run_test("opencode.send_message: parses nested result/message JSON response fields", function()
    local mock_stdout = vim.json.encode({ result = { text = "Nested result text" } })

    local orig_system = vim.system
    vim.system = function(cmd, opts, cb)
      if cb then
        cb({ code = 0, stdout = mock_stdout, stderr = "" })
      end
      return { wait = function() return { code = 0, stdout = mock_stdout } end }
    end

    local resp_text, resp_err
    opencode_http.send_message("http://127.0.0.1:4096", "sess_123", "hi", function(resp, err)
      resp_text = resp
      resp_err = err
    end)

    vim.wait(500, function() return resp_text ~= nil end)
    vim.system = orig_system

    assert_eq(resp_text, "Nested result text", "parses nested result text response")
    assert_eq(resp_err, nil, "no error on valid response")
  end)

  run_test("opencode.send_message: extracts server error field from JSON ({ error = ... })", function()
    local mock_stdout = vim.json.encode({ error = "OpenCode model overloaded" })

    local orig_system = vim.system
    vim.system = function(cmd, opts, cb)
      if cb then
        cb({ code = 0, stdout = mock_stdout, stderr = "" })
      end
      return { wait = function() return { code = 0, stdout = mock_stdout } end }
    end

    local resp_text, resp_err
    opencode_http.send_message("http://127.0.0.1:4096", "sess_123", "hi", function(resp, err)
      resp_text = resp
      resp_err = err
    end)

    vim.wait(500, function() return resp_err ~= nil end)
    vim.system = orig_system

    assert_eq(resp_text, nil, "resp_text is nil when server returns error object")
    assert_true(resp_err ~= nil and resp_err:find("OpenCode model overloaded") ~= nil, "error message extracted from server JSON error field")
  end)

  -- ==========================================================
  -- 2. FAST-PATH & RETRY RECOVERY TESTS
  -- ==========================================================

  run_test("opencode.ensure_server_async: in-memory fast-path returns true instantly", function()
    opencode_http._server_proc = { kill = function() end }
    opencode_http._server_port = 4096

    local is_ready = nil
    _G.RUNNING_TEST_SUITE = false
    opencode_http.ensure_server_async(4096, nil, function(ready)
      is_ready = ready
    end)
    _G.RUNNING_TEST_SUITE = true

    assert_eq(is_ready, true, "in-memory fast-path returns ready = true")
    opencode_http._server_proc = nil
    opencode_http._server_port = nil
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
  print(string.format("TEST RESULTS (test_opencode_protocol): %d Passed, %d Failed", results.passed, results.failed))
  print("==========================================================")
  if results.failed > 0 then
    vim.cmd("cquit 1")
  else
    vim.cmd("qall!")
  end
end

return M
