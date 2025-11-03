local M = {}
M.patterns = {
  "%(lldb%)"
}
M.errorformat = vim.o.errorformat
M.errorformat = '%-GTimestamp:%.%#,' .. M.errorformat .. ',%-G%\\d\\+%%%\\ \\[.*ETA:.*'

M.scan_until = function(bufnr, patterns)
  -- default to current buffer
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  patterns = patterns or M.patterns

  local n = vim.api.nvim_buf_line_count(bufnr)
  local out = {}

  local start_line = n
  -- find the last '(lldb)' prompt line
  for i = n, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if line and line:match("^%s*%(%s*lldb%)") then
      start_line = i
      break
    end
  end

  -- scan backwards from the lldb prompt
  for i = start_line - 1, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if not line then break end

    table.insert(out, 1, line)

    for _, pat in ipairs(patterns) do
      if line:find(pat) then
        return out
      end
    end
  end

  return nil -- pattern not found
end

M.lsp_to_quickfix = function(severity_filter, is_silent)
  local buffer_scope = nil
  local severities_by_filter = {
    E = { min = vim.diagnostic.severity.ERROR, max = vim.diagnostic.severity.ERROR },
    W = { min = vim.diagnostic.severity.WARN, max = vim.diagnostic.severity.HINT },
  }
  if severity_filter == 'E' then
    buffer_scope = nil
  elseif severity_filter == 'W' then
    buffer_scope = 0
  end

  local sev_range = severities_by_filter[severity_filter]

  -- Debug: Get ALL diagnostics first to see what's available
  local all_diagnostics = vim.diagnostic.get(buffer_scope)
  vim.print("Total diagnostics in buffer: " .. #all_diagnostics)
  for _, d in ipairs(all_diagnostics) do
    local sev_name = ({ "ERROR", "WARN", "INFO", "HINT" })[d.severity] or "UNKNOWN"
    vim.print(string.format("  [%s] %s", sev_name, d.message:sub(1, 60)))
  end

  local diagnostics = vim.diagnostic.get(buffer_scope, sev_range and { severity = sev_range } or nil)
  vim.print("Filtered diagnostics: " .. #diagnostics)
  local qf_list = {}

  for _, diagnostic in ipairs(diagnostics) do
    local bufnr = diagnostic.bufnr or 0
    local filename = vim.api.nvim_buf_get_name(bufnr)

    -- Since we're filtering by severity, we know the type
    local sev = diagnostic.severity
    local type = ({
      [vim.diagnostic.severity.ERROR] = 'E',
      [vim.diagnostic.severity.WARN]  = 'W',
      [vim.diagnostic.severity.INFO]  = 'I',
      [vim.diagnostic.severity.HINT]  = 'H',
    })[sev] or 'I'

    table.insert(qf_list, {
      filename = filename,
      lnum = diagnostic.lnum + 1, -- LSP is 0-indexed, quickfix is 1-indexed
      col = diagnostic.col + 1,
      type = type,
      text = diagnostic.message,
    })
  end

  -- Set the quickfix list
  if #qf_list > 0 then
    vim.fn.setqflist(qf_list, 'r')
    if (not is_silent) then
      vim.cmd('copen')
    elseif (severity_filter == 'E') then
      vim.print("Populated quickfix list of all errors")
    else
      vim.print("Populated quickfix list of current buffer warnings")
    end
  else
    local filter_msg = severity_filter and (" " .. (severity_filter == 'E' and "errors" or "warnings")) or "s"
    vim.notify("No LSP diagnostic" .. filter_msg .. " found", vim.log.levels.INFO)
  end
end

M.set_quickfix_from_debug = function(output_clean)
  local lines = {}
  vim.iter({ output_clean })
      :filter(function(s) return s and s ~= "" end)
      :each(function(s)
        vim.list_extend(lines, vim.split(s, "\n", { trimempty = true }))
      end)

  vim.fn.setqflist({}, 'r', { lines = lines })

  -- Join wrapped lines before parsing
  local all_lines = vim.split(output_clean, "\n", { trimempty = false })
  local joined_lines = {}
  local current_line = ""

  for _, line in ipairs(all_lines) do
    -- If line starts with "frame #" (with optional * or whitespace prefix), it's a new frame
    if line:match("^%s*%*?%s*frame #") then
      if current_line ~= "" then
        table.insert(joined_lines, current_line)
      end
      current_line = line
    else
      -- Continuation of previous line
      current_line = current_line .. line
    end
  end

  -- Don't forget the last line
  if current_line ~= "" then
    table.insert(joined_lines, current_line)
  end

  local filtered = {}
  for _, line in ipairs(joined_lines) do
    local file, lineno = line:match(" at (/.+):(%d+)")
    if file and lineno then
      table.insert(filtered, { filename = file, lnum = tonumber(lineno), text = line })
    end
  end
  vim.fn.setqflist(filtered)
  if #filtered > 0 then
    vim.cmd('vertical rightbelow copen')
    vim.cmd('wincmd =')
    return true
  end
  return false
end

M.set_quickfix_from_output = function(output_clean, efm)
  local lines = {}
  vim.iter({ output_clean })
      :filter(function(s) return s and s ~= "" end)
      :each(function(s)
        vim.list_extend(lines, vim.split(s, "\n", { trimempty = true }))
      end)

  if (not efm) then
    efm = M.errorformat
  end

  vim.fn.setqflist({}, 'r', { lines = lines, efm = efm })

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


return M
