--- ==============================================================================
--- Module: sagani.format.output.popup
---
--- Description:
---   Output Markdown popup UI formatter for sagani.nvim. Formats floating Markdown
---   popup headers, multi-turn session turn banners, and action footers.
---
--- Responsibilities:
---   - Format Markdown popup headers (`build_popup_header`).
---   - Format turn banners (`build_turn_banner`).
---   - Format keymap action footers (`build_action_footer`).
--- ==============================================================================

local M = {}

--- Formats a floating Markdown popup session header
--- @param agent_name string Agent identifier name (e.g. "OPENCODE", "AGY")
--- @return string Formatted markdown header string
function M.build_popup_header(agent_name)
  agent_name = (type(agent_name) == "string" and agent_name ~= "") and agent_name:upper() or "AGENT"
  return string.format(
    "### 💬 Sagani Agent Session (%s)\n\n> *Type your prompt in the box below and press <CR> to send.*\n\n---\n",
    agent_name
  )
end

--- Formats a multi-turn conversation turn banner
--- @param role string Role ("user" or "agent")
--- @param agent_name string Agent identifier name
--- @return string Formatted markdown turn banner string
function M.build_turn_banner(role, agent_name)
  agent_name = (type(agent_name) == "string" and agent_name ~= "") and agent_name:upper() or "AGENT"
  if role == "user" then
    return string.format("\n### 👤 Follow-up Prompt (%s)\n\n", agent_name)
  else
    return string.format("\n### 🤖 Agent Response (%s)\n\n", agent_name)
  end
end

--- Formats an action footer for floating Markdown popups
--- @return string Formatted markdown action footer string
function M.build_action_footer()
  return "\n> 💡 *Press <CR> or 'r' to reply | 'p' to pin window | 'yr' to copy | 'q' to close*\n"
end

return M
