local util = {}
util.data_file = vim.fn.stdpath("data") .. "/brt_local_data.json"

util.default_list = {
  -- Rust
  rust = {
    "cargo build",
    "cargo run",
    "cargo test",
  },

  -- Node.js / npm
  node = {
    "npm install && npm run build",
    "npm run start",
    "npm run test",
  },

  -- C/C++ (CMake / Ninja)
  cpp = {
    "cmake --build build -j4",
    "ninja -C build",
    "./build/",
    "lldb -- ./build/",
    "ctest --test-dir build --output-on-failure",
  },

  -- Make
  make = {
    "make -j4",
    "make run",
    "make test",
  },

  -- Elixir / Mix
  elixir = {
    "mix compile",
    "mix test",
  },
}
util.default_list_flat = {}
for _, commands in pairs(util.default_list) do
  for _, command in ipairs(commands) do
    table.insert(util.default_list_flat, command)
  end
end

function util.str_suffix_strip(str, suffix)
  return string.gsub(str, suffix .. "+$", "")
end

function util.str_has(str, pattern)
  return str:find(pattern)
end

function util.only_spaces(str)
  return str:match("^%s*$") ~= nil
end

function util.str_ends_with(str, ending)
  return ending == "" or str:sub(- #ending) == ending
end

-- Merge suffix of string A with prefix of string B into 1 substring, A and B goes into a new string
function util.merge_strings(A, B)
  -- Find the longest suffix of A that matches the prefix of B
  for i = #A, 1, -1 do
    local suffix = A:sub(i)
    if B:find("^" .. suffix) then
      -- Merge the strings by removing the overlapping part from B
      return A .. B:sub(#suffix + 1)
    end
  end
  -- If no overlap is found, concatenate the strings normally
  return A .. B
end

function util.save_table(tbl)
  vim.fn.writefile(tbl, util.data_file)
end

function util.load_table()
  if vim.fn.filereadable(util.data_file) == 1 then
    return vim.fn.readfile(util.data_file)
  end
  return {}
end

function util.create_file_if_empty()
  if vim.fn.filereadable(util.data_file) == 0 then
    vim.fn.writefile(util.default_list_flat, util.data_file)
  end
end

function util.table_get(tbl, key)
  for k, v in pairs(tbl) do
    if vim.fn.match(k, key) ~= -1 then
      return v
    end
  end

  return nil
end

return util
