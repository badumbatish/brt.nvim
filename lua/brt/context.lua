
local M = {}

local function get_git_info()

end
function M.get_context_info(cmd, timestamp)
  local info = {}

  -- Get current shell
  local shell = vim.env.SHELL or "unknown"
  table.insert(info, "Shell: " .. shell)

  -- Get git info if in a git repo
  local git_branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD 2>/dev/null")[1]
  if git_branch and git_branch ~= "" then
    local git_commit = vim.fn.systemlist("git rev-parse --short HEAD 2>/dev/null")[1]
    local git_repo = vim.fn.systemlist("git config --get remote.origin.url 2>/dev/null")[1]

    if git_commit and git_commit ~= "" then
      table.insert(info, "Git Branch: " .. git_branch)
      table.insert(info, "Git Commit: " .. git_commit)
    end
    if git_repo and git_repo ~= "" then
      table.insert(info, "Git Repo: " .. git_repo)
    end
  end

  table.insert(info, "Working Directory: " .. vim.uv.cwd())
  table.insert(info, "Command: " .. cmd)
  table.insert(info, "Exit Code: ?")
  table.insert(info, "Duration: ?")
  table.insert(info, "Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S", timestamp))
  table.insert(info, string.rep("-", 140))

  return info
end

return M
