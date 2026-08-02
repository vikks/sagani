-- Auto-initialize sagani.nvim when loaded via Neovim runtimepath
if vim.g.loaded_sagani then
  return
end
vim.g.loaded_sagani = true

require("sagani").setup({})
