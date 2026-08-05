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
| `<leader>ac` | Normal | `:SaganiSelectTarget` | Set manual target pane ID override |
| `<leader>ac` | Visual | `:SaganiContext` | Send visual selection code context to agent |
| `<leader>ad` | Normal / Visual | `:SaganiDiff` | Send formatted diff review comment & hunk to agent |
| `<leader>ap` | Normal / Visual | `:SaganiPrompt` | Send custom prompt directly to target agent |
| `<leader>an` | Normal | `:SaganiSpawnPane` | Spawn new agent pane in active multiplexer |
| `<leader>ah` | Normal | `:SaganiSelectAgent` | Select target agent harness & model interactively |
| `<leader>ar` | Normal | `:SaganiReview` | Toggle side-by-side agent edit review diff split |
| `<leader>ay` | Normal | `:SaganiAccept` | Accept change hunk under cursor (or all pending edits) |
| `<leader>ax` | Normal | `:SaganiReject` | Reject change hunk under cursor (or revert all edits) |
| `<leader>a]` | Normal | `:SaganiNextHunk` | Navigate cursor to next edit hunk |
| `<leader>a[` | Normal | `:SaganiPrevHunk` | Navigate cursor to previous edit hunk |

---

## 📜 User Commands

| Command | Description |
|---|---|
| `:SaganiToggleBackend [mode]` | Toggle active session backend transport mode between `auto` and `native` (or set explicit backend) |
| `:SaganiBackend [mode]` | Alias for `:SaganiToggleBackend` |
| `:SaganiAskAgent [prompt]` | Ask agent general questions in floating popup or dedicated pane |
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

When asking questions via `:SaganiAskAgent` (`<leader>aa`), the floating popup supports:

- **`p`**: Enter **Single-Keypress Pin Mode**. Press `h`, `l`, `k`, `j`, or `t` to promote the float to a split or new tab page.
- **`<CR>` / `r`**: Send follow-up prompt in multi-turn session.
- **`yr`**: Copy current turn's response to clipboard (`+` register).
- **`q` / `<Esc>`**: Close popup.
