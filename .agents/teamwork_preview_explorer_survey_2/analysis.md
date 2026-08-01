# Technical Analysis: Visual Selection & Context Dispatch to AGY (Requirement R2)

**Author:** Explorer 2  
**Target Plugin:** `herdr-agy.nvim`  
**Date:** 2026-08-01  

---

## 1. Executive Summary

Requirement R2 requires providing visual mode keymaps (`<leader>as` and `<leader>ac`) to extract visual selection in Neovim, collect buffer metadata (file path, line range, filetype), construct a structured prompt, interact with the user via non-blocking `vim.ui.input`, and dispatch the complete payload to the target `agy` agent in an adjacent `herdr` pane using `herdr agent prompt`.

This analysis specifies:
- Reliable Neovim visual selection extraction handling all 3 visual modes (`v` characterwise, `V` linewise, `<C-v>` blockwise).
- Proper mark synchronization (`'<` and `'>`) by exiting visual mode before reading range bounds.
- Full context payload structure (file path, line range, filetype, code snippet).
- Asynchronous UI prompt handling (`vim.ui.input`) ensuring non-blocking user interaction.
- Command-line execution via `vim.system` or `vim.fn.jobstart` with array-table arguments to prevent shell-escaping bugs and security risks.
- LazyVim spec integration with WhichKey mapping.

---

## 2. Neovim Visual Selection Extraction Mechanics

### 2.1 Visual Mode State & Mark Synchronization
When a user makes a selection in visual mode and triggers a keymap, Neovim remains in visual mode until explicitly exited. The marks `'<` (start of visual area) and `'>` (end of visual area) are updated **only after** leaving visual mode.

To ensure `'<` and `'>` reflect the exact user selection:
1. Explicitly exit visual mode programmatically before querying marks:
   ```lua
   vim.cmd([[noau normal! \x1b]]) -- Exits visual mode without triggering CursorMoved autocmds
   ```
2. Retrieve the visual mode type recorded prior to exit:
   ```lua
   local mode = vim.fn.visualmode() -- Returns 'v', 'V', or '\22' (Ctrl-V blockwise)
   ```
3. Retrieve position tuples `[bufnum, lnum, col, off]`:
   ```lua
   local start_pos = vim.fn.getpos("'<")
   local end_pos = vim.fn.getpos("'>")
   ```

### 2.2 Boundary Normalization & Indexing
Neovim line numbers returned by `getpos()` are **1-indexed**, while `vim.api.nvim_buf_get_lines()` expects **0-indexed** start lines (inclusive) and end lines (exclusive). Furthermore, if a user selects backwards (bottom-to-top or right-to-left), `start_pos` line/col may exceed `end_pos` line/col.

Normalization logic:
```lua
local start_line, start_col = start_pos[2], start_pos[3]
local end_line, end_col = end_pos[2], end_pos[3]

if start_line > end_line or (start_line == end_line and start_col > end_col) then
  start_line, end_line = end_line, start_line
  start_col, end_col = end_col, start_col
end
```

### 2.3 Visual Selection Mode Handling

#### A. Linewise Visual Mode (`V`)
Extracts full lines from `start_line` to `end_line` without column slicing:
```lua
local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
local snippet = table.concat(lines, "\n")
```

#### B. Characterwise Visual Mode (`v`)
Slices sub-strings from the first and last lines based on column positions:
```lua
local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
if #lines == 0 then
  return "", start_line, end_line
end

if #lines == 1 then
  lines[1] = string.sub(lines[1], start_col, end_col)
else
  lines[1] = string.sub(lines[1], start_col)
  lines[#lines] = string.sub(lines[#lines], 1, end_col)
end
local snippet = table.concat(lines, "\n")
```

#### C. Blockwise Visual Mode (`\22` or `<C-v>`)
Slices `start_col` to `end_col` across every line in the range:
```lua
local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
for i, line in ipairs(lines) do
  lines[i] = string.sub(line, start_col, end_col)
end
local snippet = table.concat(lines, "\n")
```

---

## 3. Buffer Metadata Extraction & Context Payload

### 3.1 Metadata Fields
- **File Path:** Relative path preferred for readability, relative to current working directory:
  ```lua
  local full_path = vim.api.nvim_buf_get_name(bufnr)
  local rel_path = vim.fn.fnamemodify(full_path, ":~:.")
  if rel_path == "" then rel_path = "[No Name]" end
  ```
- **Line Range:**
  ```lua
  local line_range_str = (start_line == end_line) and ("L" .. start_line) or ("L" .. start_line .. "-L" .. end_line)
  ```
- **Filetype:**
  ```lua
  local filetype = vim.bo[bufnr].filetype
  if not filetype or filetype == "" then filetype = "text" end
  ```

---

## 4. Prompt Formatting & Markdown Construction

The prompt constructed for AGY combines user input with structured markdown context blocks.

### 4.1 Structure Format
```markdown
<USER_INSTRUCTION>

Context from `<FILE_PATH>` (<LINE_RANGE>):
```<FILETYPE>
<CODE_SNIPPET>
```
```

### 4.2 Keymap Behavior Matrix (`<leader>as` vs `<leader>ac`)

| Keymap | Action Name | Interactive Input | Default Prompt Prefix |
| :--- | :--- | :--- | :--- |
| `<leader>as` | Send Selection with Instruction | Prompts user via `vim.ui.input` | User prompt entered in `vim.ui.input` |
| `<leader>ac` | Send Code Context | Direct send or default prompt | `"Context snippet for review:"` |

---

## 5. Non-Blocking User Interaction (`vim.ui.input`)

Neovim's `vim.ui.input` provides an asynchronous, non-blocking input modal compatible with UI enhancements like `dressing.nvim` or `noice.nvim`.

### 5.1 Callback Flow
```lua
function M.send_selection_with_prompt(target_agent)
  local selection = M.get_visual_selection()
  if not selection.snippet or selection.snippet == "" then
    vim.notify("No text selected", vim.log.levels.WARN, { title = "herdr-agy" })
    return
  end

  vim.ui.input({
    prompt = "AGY Instruction: ",
    default = "",
  }, function(user_input)
    -- User pressed Esc or entered empty string
    if user_input == nil or user_input == "" then
      vim.notify("Dispatch cancelled", vim.log.levels.INFO, { title = "herdr-agy" })
      return
    end

    M.dispatch_prompt(target_agent, user_input, selection)
  end)
end
```

---

## 6. CLI Execution & Escaping (`herdr agent prompt`)

### 6.1 CLI Syntax & Target Specification
Command format verified on `herdr`:
```bash
herdr agent prompt <TARGET> <TEXT>
```
Where `<TARGET>` is either the target agent name (e.g. `agy`) or target pane ID (`w65302a56adf322:p1`).

### 6.2 Preventing Shell Escaping Bugs
Instead of building a single shell command string (e.g. `system("herdr agent prompt " .. target .. " '" .. text .. "'")`), which is vulnerable to double quotes, single quotes, backticks, newlines, and variable expansion, **direct process execution with argument lists** must be used.

#### Recommended Execution: `vim.system` (Neovim 0.10+) or `vim.fn.jobstart`
```lua
local cmd = { "herdr", "agent", "prompt", target, formatted_prompt }

-- Using vim.system (async process execution):
vim.system(cmd, { text = true }, function(out)
  vim.schedule(function()
    if out.code == 0 then
      vim.notify("Successfully sent prompt to AGY (" .. target .. ")", vim.log.levels.INFO, { title = "herdr-agy" })
    else
      vim.notify("Failed to send prompt to AGY: " .. (out.stderr or "unknown error"), vim.log.levels.ERROR, { title = "herdr-agy" })
    end
  end)
end)
```

**Why this is robust:**
- Arguments are passed as an array directly to `execve()`.
- No shell interpreter is spawned; special characters in code snippets (e.g., `$`, `"`, `'`, `` ` ``, `\n`) are preserved verbatim without requiring escaping routines.
- `vim.schedule()` ensures Neovim API calls (like `vim.notify`) execute safely on the main Lua thread.

---

## 7. LazyVim Spec & WhichKey Keymap Registration

Keymaps registered under `<leader>a` in `plugins/herdr-agy.lua`:

```lua
return {
  "folke/which-key.nvim",
  optional = true,
  opts = {
    spec = {
      { "<leader>a", group = "AGY / Herdr", mode = { "n", "v" } },
    },
  },
},
{
  -- herdr-agy plugin configuration
  keys = {
    {
      "<leader>as",
      function() require("herdr-agy.selection").send_selection_prompt() end,
      mode = "v",
      desc = "Send selection with prompt to AGY",
    },
    {
      "<leader>ac",
      function() require("herdr-agy.selection").send_code_context() end,
      mode = "v",
      desc = "Send code context to AGY",
    },
  },
}
```

---

## 8. Summary of Technical Recommendations for Implementers

1. Implement module `lua/herdr-agy/selection.lua` containing:
   - `get_visual_selection()`: Mark normalization, exit visual mode (`noau normal! \x1b`), handle `v`, `V`, `<C-v>`.
   - `build_prompt_payload(user_input, selection)`: Format relative file path, line range `L<start>-L<end>`, filetype codeblock.
   - `send_selection_prompt()` & `send_code_context()`: Trigger `vim.ui.input` and dispatch via `vim.system`.
2. Use array tables for CLI process invocation to avoid shell escaping issues.
3. Schedule notifications on main thread via `vim.schedule()`.
