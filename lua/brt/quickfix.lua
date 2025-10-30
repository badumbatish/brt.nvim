local M = {}
M.patterns = {
  "%(lldb%) bt"
}
M.errorformat = vim.o.errorformat
M.errorformat = '%-GTimestamp:%.%#,' .. M.errorformat .. ',%-G%\\d\\+%%%\\ \\[.*ETA:.*'

M.tail_lines_from_end = function(path, patterns)
  local f = assert(io.open(path, "rb"))
  if not patterns then
    patterns = M.patterns
  end
  local function match_any(line)
    for _, pat in ipairs(patterns) do
      if line:find(pat) then return true end
    end
    return false
  end

  local pos = f:seek("end")
  local buffer = {}
  local current = {}

  while pos > 0 do
    pos = pos - 1
    f:seek("set", pos)
    local byte = f:read(1)

    if byte == "\n" then
      -- complete line found, reverse it
      local line = table.concat(current):reverse()
      current = {}
      if match_any(line) then
        -- hit a stopping pattern: drop line and quit
        f:close()
        -- lines currently in `buffer` are reversed in order
        -- so fix ordering
        local out = {}
        for i = #buffer, 1, -1 do
          table.insert(out, buffer[i])
        end
        return out
      else
        table.insert(buffer, line)
      end
    else
      table.insert(current, byte)
    end
  end

  -- reached BOF without a match
  f:close()
  return nil
end

M.test_helper = function()
  local x = M.tail_lines_from_end("/Users/jjasmine/.local/share/nvim/brt.log")
  if not x then
    vim.print("Nothing extracted")
    return
  end

  -- Clear quickfix list first
  vim.fn.setqflist({}, 'r')

  -- Manually parse lldb backtrace format: "frame #N: address binary`function at file:line:column"
  local qf_entries = {}
  for _, line in ipairs(x) do
    -- Match pattern: "at filename:line:column" or "at filename:line"
    local filename, lnum, col = line:match("at ([^:]+):(%d+):(%d+)")
    if not filename then
      filename, lnum = line:match("at ([^:]+):(%d+)")
      col = nil
    end

    if filename and lnum then
      table.insert(qf_entries, {
        filename = filename,
        lnum = tonumber(lnum),
        col = col and tonumber(col) or 1,
        text = line:match("frame #%d+: .+`(.+)") or line,
      })
    end
  end

  -- Set quickfix list with parsed entries
  vim.fn.setqflist(qf_entries, 'r')

  vim.print("Parsed " .. #qf_entries .. " entries")

  -- Open quickfix window
  vim.cmd('copen')
end

M.set_quickfix_from_output = function(output_clean)
  local lines = {}
  vim.iter({ output_clean })
      :filter(function(s) return s and s ~= "" end)
      :each(function(s)
        vim.list_extend(lines, vim.split(s, "\n", { trimempty = true }))
      end)

  vim.fn.setqflist({}, 'r', { lines = lines, efm = M.errorformat })

  local filtered = {}
  for _, e in ipairs(vim.fn.getqflist()) do
    if e.valid == 1 then
      table.insert(filtered, e)
    end
  end

  vim.fn.setqflist(filtered, 'r')
  if #filtered > 0 then
    vim.cmd('vertical rightbelow copen')
    vim.cmd('wincmd =')
  end
end

vim.keymap.set("n", "<leader>ld", M.test_helper, { desc = "help test"})

return M
