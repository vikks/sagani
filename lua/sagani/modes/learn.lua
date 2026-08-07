--- ==============================================================================
--- Module: sagani.modes.learn
---
--- Description:
---   Learn Operational Mode strategy for sagani.nvim. Controls the pedagogical
---   learning mode workflow, auto-opening educational explanation split views or popups
---   when agent responds.
---
--- Responsibilities:
---   - Expose Learn Operational Mode metadata contract (id, name, icon, description).
--- ==============================================================================

local M = {
  id = "learn",
  name = "Learn Mode",
  icon = "🎓",
  description = "Pedagogical learning mode (auto-opens educational explanation split views or popups when agent responds)",
}

return M
