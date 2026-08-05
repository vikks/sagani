local M = {}

--- Registers default keymap bindings and WhichKey integration
--- @param opts table Sagani configuration options
function M.setup_keymaps(opts)
  opts = type(opts) == "table" and opts or {}

  -- Register Default Keymaps
  if opts.default_keymaps then
    local set = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
    end
    set("n", "<leader>as", "<cmd>SaganiStatus<cr>", "Sagani Status")
    set("v", "<leader>as", "<cmd>SaganiSend<cr>", "Send Selection to Sagani")
    set("n", "<leader>ac", "<cmd>SaganiSelectTarget<cr>", "Select Sagani Target Pane")
    set("v", "<leader>ac", "<cmd>SaganiContext<cr>", "Send Context to Sagani")
    set({ "n", "v" }, "<leader>ad", "<cmd>SaganiDiff<cr>", "Send Diff Comment to Sagani")
    set({ "n", "v" }, "<leader>ap", "<cmd>SaganiPrompt<cr>", "Send Prompt to Sagani")
    set("v", "<leader>at", "<cmd>SaganiSend<cr>", "Send Selection to Sagani")
    set("n", "<leader>an", "<cmd>SaganiSpawnPane<cr>", "Spawn New Sagani Pane")
    set("n", "<leader>ah", "<cmd>SaganiSelectAgent<cr>", "Select Agent Harness")
    set("n", "<leader>ab", "<cmd>SaganiToggleBackend<cr>", "Toggle Native/Auto Backend Mode")
    set({ "n", "v" }, "<leader>aa", "<cmd>SaganiAskAgent<cr>", "Ask Agent (Herdr Popup)")
    set("n", "<leader>ar", "<cmd>SaganiReview<cr>", "Review Agent Edits Diff")
    set("n", "<leader>ay", "<cmd>SaganiAccept<cr>", "Accept Edit Hunk/File")
    set("n", "<leader>ax", "<cmd>SaganiReject<cr>", "Reject Edit Hunk/File")
    set("n", "<leader>a]", "<cmd>SaganiNextHunk<cr>", "Next Agent Edit Hunk")
    set("n", "<leader>a[", "<cmd>SaganiPrevHunk<cr>", "Previous Agent Edit Hunk")
  end

  -- Register WhichKey Menu Group
  if opts.which_key then
    local ok, wk = pcall(require, "which-key")
    if ok then
      if type(wk.add) == "function" then
        pcall(wk.add, {
          { "<leader>a", group = "Sagani", mode = { "n", "v" } },
        })
      elseif type(wk.register) == "function" then
        pcall(wk.register, {
          ["<leader>a"] = { name = "+Sagani" },
        }, { mode = { "n", "v" } })
      end
    end
  end
end

return M
