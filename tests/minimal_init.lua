-- Minimal init for Plenary test harness and headless test execution for sagani.nvim
vim.opt.rtp:append('.')

-- Add plenary.nvim path if present in stdpath("data") or site/pack paths
local std_data = vim.fn.stdpath("data")
local candidate_paths = {
  std_data .. "/lazy/plenary.nvim",
  std_data .. "/site/pack/packer/start/plenary.nvim",
  std_data .. "/site/pack/packer/opt/plenary.nvim",
  std_data .. "/site/pack/plugins/start/plenary.nvim",
  std_data .. "/site/pack/plugins/opt/plenary.nvim",
  std_data .. "/site/pack/vendor/start/plenary.nvim",
  std_data .. "/site/pack/deps/start/plenary.nvim",
}

local plenary_found = false
for _, path in ipairs(candidate_paths) do
  if vim.fn.isdirectory(path) == 1 then
    vim.opt.rtp:append(path)
    plenary_found = true
    break
  end
end

if not plenary_found then
  local glob_matches = vim.fn.glob(std_data .. "/**/plenary.nvim", false, true)
  if type(glob_matches) == "table" and #glob_matches > 0 then
    for _, path in ipairs(glob_matches) do
      if vim.fn.isdirectory(path) == 1 then
        vim.opt.rtp:append(path)
        break
      end
    end
  end
end

_G.RUNNING_TEST_SUITE = true
