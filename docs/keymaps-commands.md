# Keymaps & Commands Reference — sagani.nvim

This document lists all default keymaps and user commands available in **sagani.nvim**.

---

## ⌨️ Default Keymaps (`<leader>a`)

| Keymap | Mode | User Command | Description |
|---|---|---|---|
| `<leader>aa` | Normal / Visual | `:SaganiAskAgent` | Ask general question in floating popup or dedicated pane |
| `<leader>ab` | Normal | `:SaganiToggleBackend` | Toggle backend mode between `auto` multiplexer detection & `native` Neovim |
| `<leader>as` | Normal | `:SaganiStatus` | Display active backend topology and target pane status |
| `<leader>as` | Visual | `:SaganiSend` | Send visual selection with prompt instruction to agent |
| `<leader>ac` | Normal | `:SaganiSelectTarget` | Interactively select target agent pane from running multiplexer & native panes (or clear override) |
| `<leader>ac` | Visual | `:SaganiContext` | Send visual selection code context to agent |
| `<leader>ad` | Normal / Visual | `:SaganiDiff` | Send formatted diff review comment & hunk to agent |
| `<leader>ap` | Normal / Visual | `:SaganiPrompt` | Send custom prompt directly to target agent |
| `<leader>an` | Normal | `:SaganiSpawnPane` | Spawn new agent pane in active multiplexer |
| `<leader>ah` | Normal | `:SaganiSelectAgent` | Select target agent harness & model interactively |
| `<leader>ar` | Normal | `:SaganiReview` | Toggle side-by-side agent edit review diff split |
| `<leader>am` | Normal | `:SaganiMode` | Open interactive mode switcher menu |
| `<leader>amr` | Normal | `:SaganiReview` | Toggle Review Mode (edit review diff inspection) |
| `<leader>aml` | Normal | `:SaganiLearn` | Toggle Learn Mode (pedagogical AI assistant explanations) |
| `<leader>ay` | Normal | `:SaganiAccept` | Accept change hunk under cursor (or all pending edits) |
| `<leader>ax` | Normal | `:SaganiReject` | Reject change hunk under cursor (or revert all edits) |
| `<leader>a]` | Normal | `:SaganiNextHunk` | Navigate cursor to next edit hunk |
| `<leader>a[` | Normal | `:SaganiPrevHunk` | Navigate cursor to previous edit hunk |

---

## 📜 User Commands

| Command | Description |
|---|---|
| `:SaganiMode [mode]` | Set or toggle active operating mode (`review`, `learn`, `off`) |
| `:SaganiLearn` | Toggle Learn Mode (pedagogical AI assistant explanations) |
| `:SaganiToggleBackend [mode]` | Toggle active session backend transport mode between `auto` and `native` (or set explicit backend) |
| `:SaganiBackend [mode]` | Alias for `:SaganiToggleBackend` |
| `:SaganiAskAgent [prompt]` | Ask agent general questions in floating popup or dedicated pane |
| `:SaganiSelectTarget [pane]` | Open interactive target pane picker querying running agent panes across Herdr, Tmux, Zellij, and Native Neovim (or clear override) |
| `:SaganiSelectAgent [harness]` | Select active agent harness & model dynamically |
| `:SaganiPromote [placement]` | Promote active floating popup to split (`left`, `right`, `top`, `bottom`, `tab`) |
| `:SaganiStatus` | Display multiplexer topology and target pane status |
| `:SaganiSend` | Capture visual selection (`v`, `V`, `<C-v>`) and send with prompt instruction |
| `:SaganiContext` | Capture visual selection code context and send directly to agent |
| `:SaganiDiff` | Capture active diff hunk and send formatted review comment |
| `:SaganiReview` | Toggle side-by-side agent edit review diff split against baseline |
| `:SaganiAccept [hunk\|all]` | Accept edit hunk at cursor (or all pending edits in buffer) |
| `:SaganiReject [hunk\|all]` | Reject edit hunk at cursor (or revert all edits to baseline) |
| `:SaganiNextHunk` | Navigate cursor to next edit hunk in buffer |
| `:SaganiPrevHunk` | Navigate cursor to previous edit hunk in buffer |
| `:SaganiClearCache` | Flush persistent disk model cache (`stdpath('state')/sagani/models.json`) |
| `:SaganiReload` | Hot-reload all `sagani.*` Lua modules without restarting Neovim |

---

## 📌 Floating Window Keybindings (Markdown Popup)

When asking questions via `:SaganiAskAgent` (`<leader>aa`) in ACP mode, Sagani presents a persistent multi-turn floating layout with an attached prompt input box:

### Attached Input Sub-Window Controls
- **`<CR>` / `<C-m>`**: Submit prompt to agent, append turn to main Markdown buffer, and stream response.
- **`<Esc>`**: Exit Insert mode and switch focus to main Markdown response window in Normal mode.
- **`q` / `<C-c>`**: Close both floating windows (preserves conversation history in session buffer).

### Main Markdown Response Window Controls
- **`i` / `r` / `<CR>`**: Focus attached prompt input box in Insert mode.
- **`yr`**: Copy complete response to clipboard (`+` register).
- **`p`**: Enter **Single-Keypress Pin Mode**. Press `h`, `l`, `k`, `j`, or `t` to promote float to a split or new tab page.
- **`q` / `<Esc>`**: Close both floating windows (preserves conversation history in session buffer).
