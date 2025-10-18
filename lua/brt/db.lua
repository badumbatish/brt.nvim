local db = {}

local brt_util = require("brt.util")
-- Database path
db.db_path = vim.fn.stdpath("config") .. "/brt_commands.db"


function db.fields_initializer(command, type, last_inputted, times_inputted, exit_code)
  return {
    command = command,
    type = type,
    last_inputted = last_inputted,
    times_inputted = times_inputted,
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
      last_inputted = { "integer", required = true },
      times_inputted = { "integer", default = 0 },
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
        -- Insert with type "---", timestamp 0, times_inputted 0
        conn.commands:insert(db.fields_initializer(
          command,
          "---",
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
function db.save_command(command, cmd_type, exit_code)
  if not command or command == "" then
    return false
  end

  if not cmd_type or cmd_type == "" then
    vim.notify("Invalid command type for save_command", vim.log.levels.ERROR)
    return false
  end

  local conn = get_db()
  if not conn then return false end

  local timestamp = os.time()

  -- Check if command exists
  local existing = conn.commands:get({ where = { command = command } })

  if existing and #existing > 0 then
    -- Update existing command
    conn.commands:update({
      where = { command = command },
      set = {
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
      timestamp,
      1,
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
    select = { "command", "type", "last_inputted", "times_inputted", "exit_code" },
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
local function format_time_friendly(timestamp)
  if not timestamp or timestamp == 0 then
    return "----"
  end

  local now = os.time()
  local diff = now - timestamp

  local str_time = ""
  if diff < 60 then
    str_time = diff .. "s"
  elseif diff < 3600 then
    str_time = math.floor(diff / 60) .. "m"
  elseif diff < 86400 then
    str_time = math.floor(diff / 3600) .. "h"
  elseif diff < 604800 then
    str_time = math.floor(diff / 86400) .. "d"
  elseif diff < 2592000 then
    str_time = math.floor(diff / 604800) .. "w"
  elseif diff < 31556926 then
    str_time = math.floor(diff / 2592000) .. "M"
  else
    str_time = math.floor(diff / 31556926) .. "y"
  end

  return "~" .. str_time .. " ago"
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
  local last_inputted = record.last_inputted or 0
  local times_inputted = record.times_inputted or 0
  local exit_code = tostring(record.exit_code or 0)

  local time_str = format_time_friendly(last_inputted)
  local type_str = cmd_type:gsub("_command", "")

  if (times_inputted == 0) then
    success = "⚪"
    exit_code = "~~~"
  elseif (exit_code ~= 0) then
    success = "❌"
  else
    success = "✅"
  end

  return string.format("%7s|%9s|%5s|%8s|%4dx|%s",
    success,
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
    return vim.trim(parts[6])
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

-- Seed default commands into database
-- @param default_list table: Table of default commands by category
function db.seed_defaults(default_list)
  if not default_list then return false end

  for category, commands in pairs(default_list) do
    for _, command in ipairs(commands) do
      -- Default to "build_command" type for seeding
      db.save_command(command, "build", 0)
    end
  end

  return true
end

return db
