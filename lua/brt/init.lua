local brt_config = require("brt.config")
local brt_util = require("brt.util")
local brt_db = require("brt.db")
local brt_context = require("brt.context")

local brt = {}
local successful_msg = "✅ BRT successfully! Terminal closed automatically. Resivit ouput via :BRTLog."
local fallure_msg = "❌ BRT failed! Check the terminal and quickfix for details. Resivit ouput via :BRTLog."
local log_file = vim.fn.stdpath("data") .. "/brt.log"
local errorformat = vim.o.errorformat

-- This is to make sure timestamp doesn't get it, as well as ETA
errorformat = '%-GTimestamp:%.%#,' .. errorformat .. ',%-G%\\d\\+%%%\\ \\[.*ETA:.*'
local function set_quickfix_from_output(output_clean)
  local lines = {}
  vim.iter({ output_clean })
      :filter(function(s) return s and s ~= "" end)
      :each(function(s)
        vim.list_extend(lines, vim.split(s, "\n", { trimempty = true }))
      end)

  vim.fn.setqflist({}, 'r', { lines = lines, efm = errorformat })

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
-- @param cmd string: The command to execute
-- @param cmd_key string|nil: The command type (build_command, run_command, etc.) for saving to database
function brt.execute_with_quickfix(cmd, cmd_key)
  if cmd == "" then return end
  local prev_win = vim.api.nvim_get_current_win()
  local prev_cursor = vim.api.nvim_win_get_cursor(prev_win) -- {row, col}
  -- 1. Terminal at bottom
  vim.cmd("botright split")
  vim.cmd("resize 15")
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, term_buf)
  local term_win = vim.api.nvim_get_current_win()


  local time_stamp = os.time()
  -- Write context info to log file first
  local context_info = brt_context.get_context_info(cmd, time_stamp)
  local f = io.open(log_file, "w")
  if f then
    f:write(context_info)
    f:close()
  end

  local tee_cmd = string.format("bash -o pipefail -c %q", cmd .. " 2>&1 | tee -a " .. vim.fn.shellescape(log_file))
  vim.fn.jobstart(tee_cmd, {
    cwd = vim.uv.cwd(),
    term = true, -- pipe output to terminal
    -- stderr_buffered = true,
    -- stdout_buffered = true,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        -- Read log file content
        local log_content = ""
        local f = io.open(log_file, "r")
        if f then
          log_content = f:read("*a")
          f:close()
        end

        -- Strip ANSI escape codes and empty lines
        local output_clean = strip_ansi_and_emptylines(log_content or "")

        -- Determine success: 1 if exit_code is 0 and no stderr, 0 otherwise
        local bool_success = exit_code == 0

        if not bool_success then
          set_quickfix_from_output(output_clean)
        end
        -- Save command to database with success status
        brt_db.save_command(cmd, cmd_key, exit_code, time_stamp)

        -- If no error and exit_code is 0, close terminal
        if bool_success then
          if vim.api.nvim_win_is_valid(term_win) then
            vim.api.nvim_win_close(term_win, true)
          end
        end

        if bool_success then
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

function brt.check_and_execute(op)
  vim.api.nvim_echo({ { "", "None" } }, false, {})
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

  -- Get ALL commands from database (no filtering by type)
  local commands = brt_db.get_commands()

  -- Format commands for display with all 4 fields
  local display_items = {}
  for _, cmd_record in ipairs(commands) do
    table.insert(display_items, brt_db.format_command_for_display(cmd_record))
  end

  -- Get the last command for this type as default
  local last_cmd = brt_db.get_last_command(cmd_key)

  -- Use fzf-lua for input
  local fzf_lua = require("fzf-lua")
  fzf_lua.fzf_exec(display_items, {
    prompt = "Command> ",
    query = last_cmd or "",
    winopts = {
      height     = 0.7,
      width      = 0.8,
      row        = 0.5,
      col        = 0.5,
      border     = "rounded",
      fullscreen = false,
    },
    -- defaults = {
    --     multiline = 1
    -- },
    fzf_opts = {
      -- Start with no selection
      ["--no-select-1"] = "",
      ["--nth"] = brt_util.pick_order,
      ["--delimiter"] = "|",
      ["--ghost"] = "...",
      ["--header"] = "EXIT CODE| TYPE|DURATION|COUNT|COMMAND",
      ["--wrap"] = "",
      ["--highlight-line"] = "",
      ["--ansi"] = "",
      ["--border-label"] = "HI",
      ["--border"] = "top"
    },
    no_filter = false,
    keymap = {
      fzf = {
        ["ctrl-u"] = "clear-query",
        ["ctrl-n"] = "down",
        ["ctrl-p"] = "up",
      },
    },
    input = true,
    actions = {
      ["ctrl-y"] = {
        function(selected, opts)
          if selected and selected[1] then
            local command = brt_db.parse_display_string(selected[1])
            opts.query = command
            fzf_lua.resume()
          end
        end,
      },
      ["default"] = function(selected, opts)
        local input

        -- If user selected an item, parse it to get the command
        if selected and selected[1] then
          input = brt_db.parse_display_string(selected[1])
        end

        -- If user typed a new query, use that instead
        if opts.query and opts.query ~= "" and not brt_util.only_spaces(opts.query) then
          input = opts.query
        end

        if not input or brt_util.only_spaces(input) then
          return
        end

        -- Execute the command and pass cmd_key so it can save after execution with success status
        brt.execute_with_quickfix(input, cmd_key)
      end,
    },
  })
end

function brt.setup(opts)
  -- Initialize database
  brt_db.init()

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
  -- Clear database
  local ok = brt_db.clear_all()
  if ok then
    vim.notify("BRT command history cleared.", vim.log.levels.INFO)
  else
    vim.notify("Failed to clear BRT command history.", vim.log.levels.ERROR)
  end
end, { desc = "Clear BRT command history" })


return brt
