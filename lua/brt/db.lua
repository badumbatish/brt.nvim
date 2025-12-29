local db = {}

local brt_util = require("brt.util")
-- Database path
db.db_path = vim.fn.stdpath("config") .. "/brt_commands.db"


function db.fields_initializer(command, type, duration, times_inputted, last_inputted, exit_code)
  return {
    command = command,
    type = type,
    duration = duration,
    times_inputted = times_inputted,
    last_inputted = last_inputted,
    exit_code = exit_code
  }
end

-- Initialize SQLite connection with proper schema
local function get_db()
  local sqlite_ok, sqlite = pcall(require, "sqlite")
  if not sqlite_ok then
    vim.notify("sqlite.lua not found. Please install kkharji/sqlite.lua", vim.log.levels.ERROR)
    return nil
  end

  local connection = sqlite:extend({
    uri = db.db_path,
    opts = { lazy = false },
    commands = {
      id = { "integer", "primary", "key" },
      command = { "text", required = true, unique = true },
      type = { "text", required = true },
      duration = { "integer", required = true },
      times_inputted = { "integer", default = 0 },
      last_inputted = { "integer", default = 0 },
      exit_code = { "integer", default = 0 }, -- 1 for success, 0 for failure
    }
  })

  return connection
end

-- Initialize database schema
function db.init()
  local conn = get_db()
  if not conn then return false end

  -- Seed default commands from util.default_list
  for _, commands in pairs(brt_util.default_list) do
    for _, command in ipairs(commands) do
      -- Check if command already exists
      local existing = conn.commands:get({ where = { command = command } })

      if not existing or #existing == 0 then
        conn.commands:insert(db.fields_initializer(
          command,
          "---",
          0,
          0,
          0,
          0))
      end
    end
  end

  return true
end

-- Save or update a command
-- @param command string: The command to save
-- @param cmd_type string: The type of command (build_command, run_command, test_command, debug_command)
-- @param success_val number|nil: 1 for success, 0 for failure (optional, defaults to 2 ())
function db.save_command(command, cmd_type, exit_code, timestamp, duration)
  if not command or command == "" then
    return false
  end

  if not cmd_type or cmd_type == "" then
    vim.notify("Invalid command type for save_command", vim.log.levels.ERROR)
    return false
  end

  local conn = get_db()
  if not conn then return false end

  -- Check if command exists
  local existing = conn.commands:get({ where = { command = command } })

  if existing and #existing > 0 then
    conn.commands:update({
      where = { command = command },
      set = {
        duration = duration,
        last_inputted = timestamp,
        times_inputted = existing[1].times_inputted + 1,
        type = cmd_type,
        exit_code = exit_code
      }
    })
  else
    -- Insert new command
    conn.commands:insert(db.fields_initializer(
      command,
      cmd_type,
      duration,
      1,
      timestamp,
      exit_code))
  end

  return true
end

-- Get all commands, optionally filtered by type
-- @param cmd_type string|nil: Optional filter by command type
-- @return table: Array of command records with all fields
function db.get_commands(cmd_type)
  local conn = get_db()
  if not conn then return {} end

  local query = {
    select = { "command", "type", "duration", "times_inputted", "exit_code", "last_inputted" },
    order_by = { desc = "last_inputted" }
  }

  if cmd_type then
    query.where = { type = cmd_type }
  end

  return conn.commands:get(query)
end

-- Get the most recently used command by type
-- @param cmd_type string: The command type to filter by
-- @return string|nil: The most recent command or nil
function db.get_last_command(cmd_type)
  if not cmd_type or cmd_type == "" then
    return nil
  end

  local conn = get_db()
  if not conn then return nil end

  local ok, results = pcall(function()
    return conn.commands:get({
      where = { type = cmd_type },
      order_by = { desc = "last_inputted" },
      limit = 1
    })
  end)

  if not ok or not results or #results == 0 then
    return nil
  end

  return results[1].command
end

-- Format time to friendly relative time
-- @param duration number: Duration in seconds
-- @return string: Formatted time string
function db.format_time_friendly(duration)
  if not duration or duration == 0 then
    return "----"
  end

  local str_time = ""
  if duration < 1 then
    str_time = math.floor(duration * 1000) .. "ms"
  elseif duration < 60 then
    str_time = string.format("%.1fs", duration)
  elseif duration < 3600 then
    local mins = math.floor(duration / 60)
    local secs = math.floor(duration % 60)
    str_time = string.format("%dm%ds", mins, secs)
  elseif duration < 86400 then
    local hours = math.floor(duration / 3600)
    local mins = math.floor((duration % 3600) / 60)
    str_time = string.format("%dh%dm", hours, mins)
  elseif duration < 604800 then
    str_time = math.floor(duration / 86400) .. " days"
  elseif duration < 2592000 then
    str_time = math.floor(duration / 604800) .. "wks"
  elseif duration < 31556926 then
    str_time = math.floor(duration / 2592000) .. " mths"
  else
    str_time = math.floor(duration / 31556926) .. " yrs"
  end

  return str_time
end

-- Format a command record for display in fzf-lua (Atuin-style)
-- @param record table: Command record with all fields
-- @return string: Formatted string for display
function db.format_command_for_display(record)
  if not record or type(record) ~= "table" then
    return ""
  end
  local command = record.command or ""
  local cmd_type = record.type or "unknown"
  local duration = record.duration or 0
  local times_inputted = record.times_inputted or 0
  local exit_code = tostring(record.exit_code or 0)

  local time_str = db.format_time_friendly(duration)
  local type_str = cmd_type:gsub("_command", "")

  -- Color codes
  local green = "\27[32m"
  local red = "\27[31m"
  local yellow = "\27[33m"
  local cyan = "\27[36m"
  local gray = "\27[90m"
  local reset = "\27[0m"

  local exit_display, time_display, type_display, count_display, code_display

  if times_inputted == 0 then
    -- Never run - gray styling
    exit_display = gray .. "•" .. reset
    time_display = gray .. string.format("%7s", "—") .. reset
    type_display = gray .. string.format("%-5s", type_str) .. reset
    count_display = gray .. "new" .. reset
    code_display = gray .. string.format("%3s", "—") .. reset
  elseif exit_code ~= "0" then
    -- Failed - red styling
    exit_display = red .. "✗" .. reset
    time_display = red .. string.format("%7s", time_str) .. reset
    type_display = yellow .. string.format("%-5s", type_str) .. reset
    count_display = gray .. string.format("%3dx", times_inputted) .. reset
    code_display = red .. string.format("%3s", exit_code) .. reset
  else
    -- Success - green styling
    exit_display = green .. "✓" .. reset
    time_display = green .. string.format("%7s", time_str) .. reset
    type_display = cyan .. string.format("%-5s", type_str) .. reset
    count_display = gray .. string.format("%3dx", times_inputted) .. reset
    code_display = green .. string.format("%3s", "0") .. reset
  end

  -- Use space as delimiter for compact display
  return string.format("%s %s %s %s %s %s",
    exit_display,
    type_display,
    time_display,
    count_display,
    code_display,
    command
  )
end

-- Parse formatted display string back to command
-- @param display_str string: Formatted display string
-- @return string: The command part
function db.parse_display_string(display_str)
  if not display_str or display_str == "" then
    return ""
  end

  -- Strip ANSI escape codes first (colors mess up parsing)
  local stripped = display_str:gsub("\27%[[%d;]*m", "")

  -- Format: status type duration count exit_code command
  -- Split by whitespace, skip first 5 fields, rest is command
  local fields = {}
  for field in stripped:gmatch("%S+") do
    table.insert(fields, field)
  end

  -- Command starts at field 6 (after status, type, duration, count, exit_code)
  if #fields < 6 then
    return vim.trim(stripped)
  end

  -- Rejoin everything from field 6 onwards
  local command_parts = {}
  for i = 6, #fields do
    table.insert(command_parts, fields[i])
  end

  return table.concat(command_parts, " ")
end

-- Clear all commands from database
function db.clear_all()
  local conn = get_db()
  if not conn then return false end

  local ok = pcall(function()
    conn.commands:remove()
  end)

  if not ok then
    vim.notify("Failed to clear database", vim.log.levels.ERROR)
    return false
  end

  return true
end


return db
