--- ==============================================================================
--- Module: sagani.protocol.init
---
--- Description:
---   Master facade module for the sagani.protocol package. Aggregates all IPC & protocol
---   driver adapters (acp, cli, http, json_rpc).
---
--- Submodules:
---   - acp:      Agent Communication Protocol (JSON-RPC 2.0 over stdio).
---   - cli:      CLI subshell command builder & dynamic model discovery.
---   - http:     REST / HTTP API transport driver.
---   - json_rpc: Stdio JSON-RPC transport driver.
--- ==============================================================================

local acp = require("sagani.protocol.acp")
local cli = require("sagani.protocol.cli")
local http = require("sagani.protocol.http")
local json_rpc = require("sagani.protocol.json_rpc")

local M = {
  acp = acp,
  cli = cli,
  http = http,
  json_rpc = json_rpc,
}

return M
