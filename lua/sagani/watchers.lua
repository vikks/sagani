local diff = require("sagani.diff")

local M = {}

--- Registers autocmd event watchers for edit review auto-open and exit cleanup
--- @param opts table Configuration options
function M.setup_watchers(opts)
  opts = type(opts) == "table" and opts or {}

  -- Register File Change Watcher for Agent Edits
  local group = vim.api.nvim_create_augroup("SaganiReviewWatcher", { clear = true })
  vim.api.nvim_create_autocmd({ "FileChangedShellPost", "BufReadPost" }, {
    group = group,
    callback = function(ev)
      local sagani = require("sagani")
      local current_opts = sagani.options or opts
      local review_opts = type(current_opts.review) == "table" and current_opts.review or {}
      local enabled = (type(current_opts.review) == "boolean" and current_opts.review) or (review_opts.enabled ~= false)
      local auto_open = (type(review_opts) == "table") and review_opts.auto_open or false

      if enabled and auto_open then
        local bufnr = ev.buf
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
          vim.schedule(function()
            local hunks = diff.get_hunks(bufnr)
            if #hunks > 0 then
              diff.open_review(bufnr, current_opts)
            end
          end)
        end
      end
    end,
  })

  -- Register Auto-Cleanup Watcher for Background ACP Servers on Vim Exit
  local cleanup_group = vim.api.nvim_create_augroup("SaganiCleanupWatcher", { clear = true })
  vim.api.nvim_create_autocmd({ "VimLeavePre", "VimLeave", "ExitPre" }, {
    group = cleanup_group,
    callback = function()
      pcall(function()
        require("sagani.protocol.http.opencode").stop_server()
      end)
    end,
  })
end

return M
