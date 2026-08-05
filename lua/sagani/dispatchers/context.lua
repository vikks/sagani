--- ==============================================================================
--- Module: sagani.dispatchers.context
---
--- Description:
---   Provides buffer context inspection and file path reference injection (@[abs_path])
---   for agent prompts. Automatically appends the active file's absolute path to user
---   questions unless an explicit path reference (@[...]) is already present.
---
--- Responsibilities:
---   - Inspect current active buffer filename via Neovim API.
---   - Detect pre-existing @[...] reference tags in prompt text.
---   - Format and append @[abs_path] string to prompt payloads.
--- ==============================================================================

local M = {}

--- Injects absolute file reference (@[abs_path]) into prompt text if not already present
--- @param text string User prompt text
--- @param bufnr number|nil Target buffer number (defaults to current buffer 0)
--- @return string text Prompt text with injected file reference
function M.inject_file_reference(text, bufnr)
	if type(text) ~= "string" or text == "" then
		return text
	end

	bufnr = bufnr or 0
	local full_name = vim.api.nvim_buf_get_name(bufnr)
	if full_name and full_name ~= "" and not text:find("@%[") then
		local abs_path = vim.fn.fnamemodify(full_name, ":p")
		if abs_path and abs_path ~= "" then
			return string.format("%s @[%s]", text, abs_path)
		end
	end

	return text
end

return M
