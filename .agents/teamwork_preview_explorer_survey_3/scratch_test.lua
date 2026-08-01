-- Scratch test for diff payload generation
local function format_diff_comment(opts)
  local file_path = opts.file_path or 'unknown'
  local start_line = opts.start_line or 1
  local end_line = opts.end_line or start_line
  local diff_text = opts.diff_text or ''
  local code_snippet = opts.code_snippet or ''
  local user_comment = opts.comment or ''

  local header = string.format('### Diff Feedback: `%s` (lines %d-%d)', file_path, start_line, end_line)
  local block = ''
  if diff_text ~= '' then
    block = '```diff\n' .. diff_text .. '\n```'
  elseif code_snippet ~= '' then
    block = '```' .. (opts.ft or '') .. '\n' .. code_snippet .. '\n```'
  end

  local comment_section = string.format('**Comment / Feedback:**\n%s', user_comment)

  local res = {}
  table.insert(res, header)
  if block ~= '' then
    table.insert(res, block)
  end
  table.insert(res, comment_section)

  return table.concat(res, '\n\n')
end

local payload = format_diff_comment({
  file_path = 'lua/herdr-agy/diff.lua',
  start_line = 10,
  end_line = 15,
  diff_text = '@@ -10,3 +10,5 @@\n- local x = 1\n+ local x = 2\n+ print(x)',
  comment = 'Use local constant instead of variable'
})

print('--- FORMATTED PAYLOAD ---')
print(payload)
