local brt_config = require("brt.config")
local brt_util = require("brt.util")
local brt_db = require("brt.db")
local brt_qf = require("brt.quickfix")
local brt_context = require("brt.context")

local brt = {}
local successful_msg = "✅ BRT successfully! Terminal closed automatically. Revisit output via :BRTLog."
local fallure_msg = "❌ BRT failed! Check the terminal and quickfix for details. Revisit output via :BRTLog."
local log_file = vim.fn.stdpath("data") .. "/brt.log"

-- Track previous terminal buffer and window for cleanup
local prev_term_buf = nil
local prev_term_win = nil
local prev_normal = nil
local prev_cursor = nil
-- This is to make sure timestamp doesn't get it, as well as ETA

local function redirect_focus_to_normal_window()
  if (prev_normal == nil or prev_cursor == nil) then
    return
  end
  if vim.api.nvim_win_is_valid(prev_normal) then
    vim.api.nvim_set_current_win(prev_normal)
    -- Only restore cursor if we're still in the same buffer
    local prev_buf = vim.api.nvim_win_get_buf(prev_normal)
    local lines = vim.api.nvim_buf_line_count(prev_buf)
    if prev_cursor[1] <= lines then
      vim.api.nvim_win_set_cursor(prev_normal, prev_cursor)
    end
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

  -- Clean up previous terminal window and buffer
  if prev_term_win and vim.api.nvim_win_is_valid(prev_term_win) then
    vim.api.nvim_win_close(prev_term_win, true)
  end
  if prev_term_buf and vim.api.nvim_buf_is_valid(prev_term_buf) then
    vim.api.nvim_buf_delete(prev_term_buf, { force = true })
  end

  -- Clear quickfix list
  vim.fn.setqflist({}, 'r')
  vim.cmd('cclose')

  prev_normal = vim.api.nvim_get_current_win()
  prev_cursor = vim.api.nvim_win_get_cursor(prev_normal) -- {row, col}
  -- 1. Terminal at bottom
  vim.cmd("botright split")
  vim.cmd("resize 15")
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, term_buf)
  local term_win = vim.api.nvim_get_current_win()

  -- Store for cleanup on next execution
  prev_term_buf = term_buf
  prev_term_win = term_win


  local time_stamp = os.time()
  local start_time = vim.loop.hrtime() -- High resolution timer for duration

  -- local tee_cmd = string.format("%s  -o pipefail -c %q", vim.o.shell,
  --   cmd .. " 2>&1 | tee -a " .. vim.fn.shellescape(log_file))
  -- local script_cmd = string.format("script -aqU %s %s -c \"%s\"", vim.fn.shellescape(log_file), vim.o.shell, cmd)

  -- Write context info to log file first
  local context_info = brt_context.get_context_info(cmd, time_stamp)
  local f = io.open(log_file, "w")
  if f then
    f:write(table.concat(context_info, "\n") .. "\n")
    f:close()
  end

  -- vim.print(script_cmd)
  vim.fn.jobstart(cmd, {
    cwd = vim.uv.cwd(),
    term = true, -- pipe output to terminal
    -- stderr_buffered = true,
    -- stdout_buffered = true,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        -- Calculate duration
        local end_time = vim.loop.hrtime()
        local duration_ns = end_time - start_time
        local duration_s = duration_ns / 1e9
        local duration_str = brt_db.format_time_friendly(duration_s)

        -- Read terminal buffer contents and append to log file
        local term_lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
        local f = io.open(log_file, "a")
        if f then
          f:write(table.concat(term_lines, "\n") .. "\n")
          f:close()
        end
        -- Update exit code and duration in place using vim.fn for efficiency
        local lines = vim.fn.readfile(log_file)
        local replaced = 0
        for i, line in ipairs(lines) do
          if line:match("^Exit Code: %?") then
            lines[i] = "Exit Code: " .. exit_code
            replaced = replaced + 1
          elseif line:match("^Duration: %?") then
            lines[i] = "Duration: " .. duration_str
            replaced = replaced + 1
          end
          if replaced == 2 then
            break
          end
        end
        vim.fn.writefile(lines, log_file)

        -- Read log file content for quickfix
        local log_content = table.concat(lines, "\n")

        -- Strip ANSI escape codes and empty lines
        local output_clean = strip_ansi_and_emptylines(log_content or "")

        -- Determine success: 1 if exit_code is 0 and no stderr, 0 otherwise
        local bool_success = exit_code == 0

        if not bool_success then
          brt_qf.set_quickfix_from_output(output_clean)
        end
        -- Save command to database with success status
        brt_db.save_command(cmd, cmd_key, exit_code, time_stamp, duration_s)

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

        redirect_focus_to_normal_window()
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
      return true, "terminal"
    end
    if filetype == "quickfix" then
      return true, "quickfix"
    end
    if name == "" then
      return true, "empty"
    end
    return false
  end

  local has_quit = false
  -- Keep quitting buffers until we hit a quittable one
  while true do
    local bufnr = vim.api.nvim_get_current_buf()
    local ok, kind = is_quittable(bufnr)
    if not ok then break end
    if kind == "terminal" then
      local chan = vim.b[bufnr].terminal_job_id
      if chan then
        -- Graceful: close terminal channel → SIGHUP to child
        local r = pcall(vim.fn.chanclose, chan)
        if not r then
          -- Force kill if needed
          pcall(vim.fn.jobkill, chan)
        end
      end
    end

    vim.cmd("q")
    has_quit = true
  end

  if (not has_quit) then
    vim.cmd("q")
  end
end

-- Convert LSP diagnostics to quickfix list
-- severity_filter: 'E' for errors only, 'W' for warnings only, nil for all

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

  local saved_timeoutlen = vim.o.timeoutlen
  vim.o.timeoutlen = brt_util.timeout_delay -- Very low timeout so Space is instant

  -- Helper to cleanup picker (close border window and restore timeoutlen)
  local function cleanup_picker()
    vim.o.timeoutlen = saved_timeoutlen
  end
  -- Use fzf-lua for input
  local cycle = 0
  local cycle_base = nil
  local cycle_modified = nil
  local fzf_lua = require("fzf-lua")
  fzf_lua.fzf_exec(display_items, {
    prompt = "Command> ",
    query = last_cmd or "",
    winopts = {
      height     = 0.75,
      width      = 0.9,
      row        = 0.5,
      col        = 0.5,
      border     = "rounded",
      title      = " BRT.nvim ",
      title_pos  = "center",
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
    },
    no_filter = false,
    keymap = {
      fzf = {
        ["ctrl-y"]     = "transform-query(printf '%s' {5..})",
        ["ctrl-u"]     = "clear-query",
        ["ctrl-n"]     = "down",
        ["ctrl-p"]     = "up",
        ["ctrl-left"]  = "backward-word",
        ["ctrl-right"] = "forward-word",
      },
    },
    input = true,
    actions = {
      ["tab"] = function(selected, opts)
        local function get_last_word(str)
          return str:match("(%S+)$") or ""
        end
        local function mixed_complete(query_cmd)
          local seen = {}
          local out = {}

          local function add(list)
            for _, v in ipairs(list) do
              if not seen[v] then
                seen[v] = true
                table.insert(out, v)
              end
            end
          end
          local x = vim.opt.wildoptions
          vim.opt.wildoptions = "fuzzy"
          add(vim.fn.getcompletion(query_cmd, "shellcmd"))
          add(vim.fn.getcompletion(query_cmd, "shellcmdline"))
          vim.opt.wildoptions = x
          local n = #out

          if n == 0 then
            return get_last_word(query_cmd)
          end
          local cmd = out[(cycle % n) + 1]
          cycle = cycle + 1

          return cmd
        end
        local function replace_last_word(str, replacement)
          -- Match everything up to the last whitespace
          local prefix = str:match("^(.*%s)") or ""
          return prefix .. replacement
        end
        if cycle_modified == nil or cycle_modified ~= opts.__call_opts.query then
          cycle_base = opts.__call_opts.query
        end
        opts.__call_opts.query = replace_last_word(cycle_base, mixed_complete(cycle_base))
        cycle_modified = opts.__call_opts.query
        fzf_lua.resume(opts)
      end,
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

  -- Apparently fzf-lua creates a windows when we do fzf_exec, we just gotta restore the delay here
  vim.api.nvim_create_autocmd("WinClosed", {
    callback = cleanup_picker,
    once = true, -- runs it this one time and then get out
  })
end

brt.open_log = function()
  if vim.fn.filereadable(log_file) == 1 then
    -- Find or create buffer for the log file
    local buf = vim.fn.bufnr(log_file)
    if buf == -1 then
      -- Buffer doesn't exist, create and load it
      vim.cmd('badd ' .. vim.fn.fnameescape(log_file))
      buf = vim.fn.bufnr(log_file)
      -- Disable swapfile to avoid swap file warnings
      vim.api.nvim_set_option_value('swapfile', false, { buf = buf })
      vim.fn.bufload(buf)
    else
      -- Buffer exists, make sure it's loaded
      if not vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_set_option_value('swapfile', false, { buf = buf })
        vim.fn.bufload(buf)
      end
    end

    -- Calculate window dimensions (95% of screen)
    local ui = vim.api.nvim_list_uis()[1]
    local width = math.floor(ui.width * 0.95)
    local height = math.floor(ui.height * 0.95)
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)

    -- Create pastel sky blue border highlight
    vim.api.nvim_set_hl(0, 'BRTLogBorder', { fg = '#AED6F1' }) -- Pastel sky blue

    -- Create floating window
    local win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      border = 'rounded',
      title = ' BRT Log ',
      title_pos = 'center',
    })

    -- Apply pastel sky blue border
    vim.wo[win].winhighlight = 'FloatBorder:BRTLogBorder'

    -- -- Set keymaps to close window with 'q' or Esc
    -- vim.keymap.set('n', 'q', '<cmd>close<CR>', {buffer = buf, silent = true})
    vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', { buffer = buf, silent = true })
  else
    vim.notify("No BRT log found!", vim.log.levels.WARN)
  end
end


vim.api.nvim_create_user_command("BRTLog", brt.open_log, {})

function brt.setup(opts)
  -- Initialize database
  brt_db.init()

  if opts and opts.keymaps then
    brt.set_keymaps(opts.keymaps)
  end


  vim.keymap.set('n', brt_config.keymaps["build"],
    '<cmd>lua require("brt").check_and_execute("build_command")<CR>',
    { noremap = true, silent = true, desc = "Prompt and execute BRT build command" })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["run"],
    '<cmd>lua require("brt").check_and_execute("run_command")<CR>',
    { noremap = true, silent = true, desc = "Prompt and execute BRT run command" })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["test"],
    '<cmd>lua require("brt").check_and_execute("test_command")<CR>',
    { noremap = true, silent = true, desc = "Prompt and execute BRT test command" })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["debug"],
    '<cmd>lua require("brt").check_and_execute("debug_command")<CR>',
    { noremap = true, silent = true, desc = "Prompt and execute BRT debug command" })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["quit_tab"], '<cmd>lua require("brt").handle_quit()<CR>',
    { noremap = true, silent = true, desc = "Special :q hanlding for BRT" })
  vim.api.nvim_set_keymap('n', brt_config.keymaps["show_log"], '<cmd>lua require("brt").open_log()<CR>',
    { noremap = true, silent = true, desc = "Open log for BRT" })
  vim.keymap.set('n', brt_config.keymaps["quickfix_warning"],
    function() brt_qf.lsp_to_quickfix("W", false) end,
    { noremap = true, silent = true, desc = "Populate quickfix with warnings from LSP"})
  vim.keymap.set('n', brt_config.keymaps["quickfix_error"],
    function() brt_qf.lsp_to_quickfix("E", false) end,
    { noremap = true, silent = true, desc = "Populate quickfix with errors from LSP" })
  vim.keymap.set('n', brt_config.keymaps["quickfix_debug_terminal"],
    function()
      -- Check if terminal buffer exists
      if not brt_util.terminal_available(prev_term_buf) then
        vim.notify("No terminal spawned yet via debug", vim.log.levels.WARN)
        return
      end

      local x = brt_qf.scan_until(prev_term_buf)
      if (x == nil) then
        return
      end
      local s = strip_ansi_and_emptylines(table.concat(x, "\n"))
      local has_error = brt_qf.set_quickfix_from_debug(s)
      if (has_error == false) then
        vim.print("No parsable error from the debug session")
      end
    end,
    { noremap = true, silent = true, desc = "Populate quickfix from stack trace of lldb" })
end

function brt.set_keymaps(keymaps)
  -- override whatever mapping over to the brt_config.keymaps
  for key, value in pairs(keymaps) do
    brt_config.keymaps[key] = value
  end
end

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
