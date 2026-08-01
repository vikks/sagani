local plugin_dir = vim.fn.expand("~/CreatorSpace/Coder/OpenSource/NeovimPlugins/herdr-agy.nvim")
if vim.fn.isdirectory(plugin_dir) == 0 then
  plugin_dir = vim.fn.expand("~/teamwork_projects/nvim_herdr_agy")
end
if vim.fn.isdirectory(plugin_dir) == 0 then
  plugin_dir = "."
end

return {
  -- Optional WhichKey integration for AGY / Herdr keymap group
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } },
      },
    },
  },

  -- herdr-agy.nvim main plugin specification
  {
    "herdr-agy.nvim",
    dir = plugin_dir,
    name = "herdr-agy.nvim",
    cmd = {
      "HerdrAgyStatus",
      "HerdrAgySelectTarget",
      "HerdrAgySpawnPane",
      "HerdrAgyPrompt",
      "HerdrAgySend",
      "HerdrAgyContext",
      "HerdrAgyDiff",
    },
    keys = {
      { "<leader>as", "<cmd>HerdrAgyStatus<cr>", desc = "AGY Status" },
      { "<leader>as", "<cmd>HerdrAgySend<cr>", desc = "Send Selection to AGY", mode = "v" },
      { "<leader>ac", "<cmd>HerdrAgySelectTarget<cr>", desc = "Select AGY Target Pane" },
      { "<leader>ac", "<cmd>HerdrAgyContext<cr>", desc = "Send Context to AGY", mode = "v" },
      { "<leader>ad", "<cmd>HerdrAgyDiff<cr>", desc = "Send Diff Comment to AGY", mode = { "n", "v" } },
      { "<leader>ap", "<cmd>HerdrAgyPrompt<cr>", desc = "Send Prompt to AGY", mode = { "n", "v" } },
      { "<leader>at", "<cmd>HerdrAgySend<cr>", desc = "Send Selection to AGY", mode = "v" },
      { "<leader>an", "<cmd>HerdrAgySpawnPane<cr>", desc = "Spawn New AGY Pane", mode = "n" },
    },
    opts = {
      target_agent = "agy",
      auto_discover = true,
      startup_delay = 5000,
      auto_spawn = "left", -- Options: "right", "bottom", "down", "left", false, true
    },
    config = function(_, opts)
      require("herdr-agy").setup(opts)
    end,
  },
}
