# Original User Request

## Initial Request — 2026-08-01T05:52:13Z

Design and build a LazyVim plugin / Lua module (`herdr-agy.nvim`) tailored for LazyVim users that integrates Neovim with `herdr` terminal multiplexer and `antigravity-cli` (`agy`).

Working directory: ~/teamwork_projects/nvim_herdr_agy

## Requirements

### R1. LazyVim Plugin Specification & Configuration
Provide a single-file LazyVim plugin spec (`plugins/herdr-agy.lua`) with seamless WhichKey menu integration (`<leader>a` group for AGY actions), lazy-loading capabilities, and configurable keymaps.

### R2. Visual Selection & Context Dispatch to AGY
Provide visual mode keymaps (`<leader>as` / `<leader>ac`) to send selected code, file path, line numbers, filetype, and user instructions directly to the `agy` agent in an adjacent `herdr` right pane via `herdr agent prompt`.

### R3. Interactive Diff Review & Inline Commenting
Provide diff review integration with `diffview.nvim` or LazyVim's built-in diff views, allowing the user to select diff ranges, add comments, and send structured diff feedback back to `agy`.

### R4. Herdr Environment & Topology Auto-Discovery
Automatically detect `HERDR_ENV`, query `herdr pane list` / `herdr agent list` to find the target `agy` right-side pane, and handle missing panes or non-Herdr environments cleanly with `lazyvim.util` / `vim.notify`.

## Acceptance Criteria

### LazyVim Integration
- [ ] Plugin spec follows LazyVim standard conventions and registers smoothly under `~/.config/nvim/lua/plugins/herdr-agy.lua`.
- [ ] `WhichKey` keymap descriptions register under the `<leader>a` (AGY) prefix.
- [ ] Visual selection dispatches path, range, code snippet, and query to the target `herdr` agent without interrupting Neovim focus.
- [ ] Diff comments format cleanly as markdown diff blocks sent to `agy`.
