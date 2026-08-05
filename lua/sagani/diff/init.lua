--- ==============================================================================
--- Module: sagani.diff
---
--- Description:
---   Diff hunk management, baseline snapshotting, and interactive edit review system
---   for sagani.nvim. Re-exports submodules under lua/sagani/diff/ (baseline, hunks,
---   view, actions, comment) as a clean facade.
---
--- Responsibilities:
---   - Provide 100% backwards-compatible facade interface for diff functionality.
---   - Re-export baseline, hunk, view, action, and comment methods.
--- ==============================================================================

local baseline = require("sagani.diff.baseline")
local hunks = require("sagani.diff.hunks")
local view = require("sagani.diff.view")
local actions = require("sagani.diff.actions")
local comment = require("sagani.diff.comment")

local M = {}

-- Re-export internal state tables for backwards compatibility
M._snapshots = baseline._snapshots
M._review_wins = view._review_wins
M._inline_active = view._inline_active

-- Re-export functions
M.take_snapshot = baseline.take_snapshot
M.get_baseline_lines = baseline.get_baseline_lines

M.split_diff_hunks = hunks.split_diff_hunks
M.get_hunks = hunks.get_hunks
M.next_hunk = hunks.next_hunk
M.prev_hunk = hunks.prev_hunk
M.get_diff_hunk_at_cursor = hunks.get_diff_hunk_at_cursor

M.render_inline_review = view.render_inline_review
M.close_review = view.close_review
M.open_review = view.open_review
M.toggle_review = view.toggle_review

M.accept_change = actions.accept_change
M.reject_change = actions.reject_change

M.send_diff_comment = comment.send_diff_comment

return M
