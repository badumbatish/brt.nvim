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
function db.save_command(command, cmd_type, exit_code, timestamp)
  if not command or command == "" then
    return false
  end

  if not cmd_type or cmd_type == "" then
    vim.notify("Invalid command type for save_command", vim.log.levels.ERROR)
    return false
  end

  local conn = get_db()
  if not conn then return false end

  local now = os.time()

  -- Check if command exists
  local existing = conn.commands:get({ where = { command = command } })

  if existing and #existing > 0 then
    conn.commands:update({
      where = { command = command },
      set = {
        duration = now - timestamp,
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
      now - timestamp,
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
-- @param timestamp number: Unix timestamp
-- @return string: Formatted time string
local function format_time_friendly(duration)
  if not duration or duration == 0 then
    return "----"
  end

  local str_time = ""
  if duration < 60 then
    str_time = duration .. "s"
  elseif duration < 3600 then
    str_time = math.floor(duration / 60) .. "m"
  elseif duration < 86400 then
    str_time = math.floor(duration / 3600) .. "h"
  elseif duration < 604800 then
    str_time = math.floor(duration / 86400) .. "d"
  elseif duration < 2592000 then
    str_time = math.floor(duration / 604800) .. "w"
  elseif duration < 31556926 then
    str_time = math.floor(duration / 2592000) .. "M"
  else
    str_time = math.floor(duration / 31556926) .. "y"
  end

  return "~" .. str_time
end

-- Format a command record for display in fzf-lua
-- @param record table: Command record with all fields
-- @return string: Formatted string for display
function db.format_command_for_display(record)
  if not record or type(record) ~= "table" then
    return ""
  end
  local success = ""
  local command = record.command or ""
  local cmd_type = record.type or "unknown"
  local duration = record.duration or 0
  local times_inputted = record.times_inputted or 0
  local exit_code = tostring(record.exit_code or 0)

  local time_str = format_time_friendly(duration)
  local type_str = cmd_type:gsub("_command", "")

  if (times_inputted == 0) then
    success = "⚪"
    exit_code = "\27[90m" .. string.format("%9s", "~~~") .. "\27[0m" -- Gray for never run
    time_str = string.format("%8s", time_str)
  elseif (exit_code ~= "0") then
    success = "❌"
    exit_code = "\27[31m" .. string.format("%9s", exit_code) .. "\27[0m" -- Red for failure
    time_str = "\27[31m" .. string.format("%8s", time_str) .. "\27[0m" -- Red for failure
  else
    success = "✅"
    exit_code = "\27[32m" .. string.format("%9s", exit_code) .. "\27[0m" -- Green for success
    time_str = "\27[32m" .. string.format("%8s", time_str) .. "\27[0m" -- Red for failure
  end

  return string.format("%s|%5s|%s|%4dx|%s",
    exit_code,
    type_str,
    time_str,
    times_inputted,
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

  -- New format: type | time | count | command
  -- Extract everything after the last |
  local parts = vim.split(display_str, "|", { plain = true })
  if #parts >= brt_util.pick_order then
    return vim.trim(parts[brt_util.pick_order])
  end

  -- Fallback: return trimmed string
  return vim.trim(display_str)
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
