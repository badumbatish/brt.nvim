local brt_config = require("brt.config")
local brt_util = require("brt.util")

local brt = {}
local successful_msg = "✅ BRT successfully! Terminal closed automatically. Resivit ouput via :BRTLog."
local fallure_msg = "❌ BRT failed! Check the terminal and quickfix for details. Resivit ouput via :BRTLog."
local log_file = vim.fn.stdpath("data") .. "/brt.log"

local function set_quickfix_from_output(output_clean)
  local lines = {}
  vim.iter({ output_clean })
      :filter(function(s) return s and s ~= "" end)
      :each(function(s)
        vim.list_extend(lines, vim.split(s, "\n", { trimempty = true }))
      end)

  vim.fn.setqflist({}, 'r', { lines = lines, efm = vim.o.errorformat })

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

local function strip_ansi_and_emptylines(s)
  if not s then return "" end
  -- Remove ANSI escape sequences
  s = s:gsub("\27%[[%d;]*[A-Za-z]", "")
  -- Remove empty lines
  local lines = {}
  for line in s:gmatch("[^\r\n]+") do
    if line:match("%S") then -- keep only lines with non-space characters
      table.insert(lines, line)
    end
  end
  return table.concat(lines, "\n")
end

-- Run in a terminal + quickfix
function brt.execute_with_quickfix(cmd)
  if cmd == "" then return end
  local prev_win = vim.api.nvim_get_current_win()
  local prev_cursor = vim.api.nvim_win_get_cursor(prev_win) -- {row, col}
  -- 1. Terminal at bottom
  vim.cmd("botright split")
  vim.cmd("resize 15")
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, term_buf)
  local term_win = vim.api.nvim_get_current_win()

  local output_data = {}
  local has_stderr = false

  local job_id = vim.fn.jobstart(cmd, {
    cwd = vim.uv.cwd(),
    term = true, -- pipe output to terminal
    on_stdout = function(_, data, _)
      if data then
        vim.list_extend(output_data, data)
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        vim.list_extend(output_data, data)
        has_stderr = true
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        local output_clean = strip_ansi_and_emptylines(table.concat(output_data, "\n"))
        set_quickfix_from_output(output_clean)

        -- Save to file
        local f, err = io.open(log_file, "w")
        if f then
          local cwd = vim.loop.cwd() -- or os.getenv("PWD")
          -- TODO: Add git commit, branch and repo
          f:write("pwd        : " .. cwd .. "\n")
          f:write("command    : " .. cmd .. "\n")
          f:write("exit code  : " .. exit_code .. "\n")
          f:write("output     :\n" .. output_clean .. "\n")

          f:close()
        else
          vim.notify("Failed to write BRT log: " .. err, vim.log.levels.ERROR)
        end
        -- If no error and exit_code is 0, close terminal
        if exit_code == 0 and not has_stderr then
          if vim.api.nvim_win_is_valid(term_win) then
            vim.api.nvim_win_close(term_win, true)
          end
        end

        if exit_code == 0 and not has_stderr then
          vim.print(successful_msg)
        else
          vim.print(fallure_msg)
        end

        if vim.api.nvim_win_is_valid(prev_win) then
          vim.api.nvim_set_current_win(prev_win)
          vim.api.nvim_win_set_cursor(prev_win, prev_cursor)
        end
      end)
    end,
  })
end

function brt.handle_quit()
  local function is_quittable(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

    if buftype == "terminal" then
      return true
    end
    if filetype == "quickfix" then
      return true
    end
    if name == "" then
      return true
    end
    return false
  end

  local has_quit = false
  -- Keep quitting buffers until we hit a quittable one
  while true do
    local bufnr = vim.api.nvim_get_current_buf()
    if is_quittable(bufnr) then
      vim.cmd("q")
      has_quit = true
    else
      break
    end
  end

  if (not has_quit) then
    vim.cmd("q")
  end
end

-- Convert LSP diagnostics to quickfix list
-- severity_filter: 'E' for errors only, 'W' for warnings only, nil for all
function brt.lsp_to_quickfix(severity_filter, is_silent)
  local severity_map = nil
  local buffer_scope = nil

  if severity_filter == 'E' then
    severity_map = vim.diagnostic.severity.ERROR
    buffer_scope = nil
  elseif severity_filter == 'W' then
    severity_map = vim.diagnostic.severity.WARN
    buffer_scope = 0
  end

  local diagnostics = vim.diagnostic.get(buffer_scope, severity_map and { severity = severity_map } or nil)
  local qf_list = {}

  for _, diagnostic in ipairs(diagnostics) do
    local bufnr = diagnostic.bufnr or 0
    local filename = vim.api.nvim_buf_get_name(bufnr)

    -- Since we're filtering by severity, we know the type
    local type = severity_filter or 'I'

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

function brt.populate_data(current_dir)
  for file, filetype_config in pairs(brt_config.filetype_map) do
    local file_path = current_dir .. "/" .. file

    local expanded = vim.fn.expand(file_path)
    if vim.fn.filereadable(expanded) == 1 then
      vim.print(file_path)
      return vim.deepcopy(filetype_config)
    end
  end
  return {
    build_command = "",
    run_command = "",
    test_command = "",
    debug_command = ""
  }
end

function brt.check_and_execute(op)
  local valid_ops = {
    build_command = "build_command",
    run_command = "run_command",
    test_command = "test_command",
    debug_command = "debug_command",
  }

  local cmd_key = valid_ops[op]
  if not cmd_key then
    vim.notify("Invalid operation: " .. tostring(op), vim.log.levels.ERROR)
    return
  end

  local tbl = brt_util.load_table()
  -- Use fzf-lua for input
  local fzf_lua = require("fzf-lua")
  fzf_lua.fzf_exec(tbl, {
    prompt = "Change/Input to " .. op .. ":> ",
    winopts = {
      height     = 0.3,
      width      = 0.5,
      row        = 0.5,
      col        = 0.5,
      border     = "rounded",
      fullscreen = false,
    },
    keymap = {
      fzf = {
        ["ctrl-y"] = "replace-query",
        ["ctrl-n"] = "down",
        ["ctrl-p"] = "up",
      },
    },
    input = true,
    actions = {
      ["default"] = function(selected, opts)
        local input = opts.query or (selected and selected[1])
        if not input or brt_util.only_spaces(input) then
          return
        end
        table.insert(tbl, input)
        if #tbl > 0 then
          brt_util.save_table(tbl)
        end
        brt.execute_with_quickfix(input)
      end,


    },
  })
end

function brt.setup(opts)
  brt_util.create_file_if_empty()
  if opts and opts.keymaps then
    brt.set_keymaps(opts.keymaps)
  end


  vim.api.nvim_set_keymap('n', brt_config.keymaps["build"],
    '<cmd>lua require("brt").check_and_execute("build_command")<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["run"],
    '<cmd>lua require("brt").check_and_execute("run_command")<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["test"],
    '<cmd>lua require("brt").check_and_execute("test_command")<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["debug"],
    '<cmd>lua require("brt").check_and_execute("debug_command")<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["quit_tab"], '<cmd>lua require("brt").handle_quit()<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["quickfix_error"],
    '<cmd>lua require("brt").lsp_to_quickfix("E", false)<CR>',
    { noremap = true, silent = true })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["quickfix_warning"],
    '<cmd>lua require("brt").lsp_to_quickfix("W", false)<CR>',
    { noremap = true, silent = true })
end

function brt.set_keymaps(keymaps)
  -- override whatever mapping over to the brt_config.keymaps
  for key, value in pairs(keymaps) do
    brt_config.keymaps[key] = value
  end
end

vim.api.nvim_create_user_command("BRTLog", function()
  if vim.fn.filereadable(log_file) == 1 then
    vim.cmd("tabnew " .. log_file)
  else
    vim.notify("No BRT log found!", vim.log.levels.WARN)
  end
end, {})

vim.api.nvim_create_user_command("BRTClear", function()
  -- Delete the data file if it exists
  if vim.fn.filereadable(brt_util.data_file) == 1 then
    local ok, err = pcall(vim.fn.delete, brt_util.data_file)
    if not ok then
      vim.notify("Failed to delete BRT data file: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
  end

  -- Recreate file with default commands if empty
  brt_util.create_file_if_empty()

  vim.notify("BRT command history cleared.", vim.log.levels.INFO)
end, { desc = "Clear BRT command history" })


return brt
