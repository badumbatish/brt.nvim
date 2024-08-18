local brt_config = require("brt.config")
local brt_util = require("brt.util")

local brt = {}
brt.terminal_command = "bot :terminal"

function brt.build_terminal_command(current_dir, command)
    return brt.terminal_command .. " cd " .. vim.fn.shellescape(current_dir) .. " && " .. command
end

function brt.execute_terminal_command(current_dir, command, error_msg)
    if command == "" then
        print(error_msg)
        return
    else
        vim.cmd(brt.build_terminal_command(current_dir, command))
        vim.api.nvim_feedkeys('G', 'n', true)
        return
    end
end

-- Function to check for project files and run appropriate build command
function brt.check_and_build()
    local current_dir = vim.loop.cwd()
    local generic_build_error = "Cannot perform `build` command"

    for dir, project in pairs(brt_config.directory_map) do
        if vim.fn.match(current_dir, dir) ~= -1 then
            print("Found " .. project.name .. " project. Building...")
            local error_msg = generic_build_error .. ", no build command found for " .. project.name .. " project."
            brt.execute_terminal_command(current_dir, project.build_command, error_msg)
            return
        end
    end

    for file, project in pairs(brt_config.project_map) do
        local file_path = current_dir .. "/" .. file
        if vim.fn.filereadable(file_path) == 1 then
            print("Found " .. project.name .. " project. Building...")
            local error_msg = generic_build_error .. ", no build command found for " .. project.name .. " project."
            brt.execute_terminal_command(current_dir, project.build_command, error_msg)
            return
        end
    end

    print(generic_build_error .. ", no recognized project file found in the current neovim-opened directory.")
end

function brt.check_and_run()
    local current_dir = vim.loop.cwd()
    local generic_run_error = "Cannot perform `run` command"
    for dir, project in pairs(brt_config.directory_map) do
        if vim.fn.match(current_dir, dir) ~= -1 then
            print("Found " .. project.name .. " project. Running potential executable...")
            local error_msg = generic_run_error .. ", no run command found for " .. project.name .. " project."
            brt.execute_terminal_command(current_dir, project.run_command, error_msg)
            return
        end
    end

    for file, project in pairs(brt_config.project_map) do
        local file_path = current_dir .. "/" .. file
        if vim.fn.filereadable(file_path) == 1 then
            print("Found " .. project.name .. " project. Running potential executable...")
            local error_msg = generic_run_error .. ", no run command found for " .. project.name .. " project."
            brt.execute_terminal_command(current_dir, project.run_command, error_msg)
        end
    end

    print(generic_run_error .. ", no recognized project file found in the current neovim-opened directory.")
end

function brt.check_and_test()
    local current_dir = vim.loop.cwd()
    local generic_test_error = "Cannot perform `test` command"
    for dir, project in pairs(brt_config.directory_map) do
        if vim.fn.match(current_dir, dir) ~= -1 then
            print("Found " .. project.name .. " project. Running potential executable...")
            local error_msg = generic_test_error .. ", no test command found for " .. project.name .. " project."
            brt.execute_terminal_command(current_dir, project.test_command, error_msg)
            return
        end
    end

    for file, project in pairs(brt_config.project_map) do
        local file_path = current_dir .. "/" .. file
        if vim.fn.filereadable(file_path) == 1 then
            print("Found " .. project.name .. " project. Testing...")
            local error_msg = generic_test_error .. ", no test command found for " .. project.name .. " project."
            brt.execute_terminal_command(current_dir, project.test_command, error_msg)
        end
    end

    print(generic_test_error .. ", no recognized project file found in the current neovim-opened directory.")
end

function brt.setup_keymap()
    -- Map the function to <Leader>b
    vim.api.nvim_set_keymap('n', brt_config.keymaps["build"], '<cmd>lua require("brt").check_and_build()<CR>',
        { noremap = true, silent = true })
    vim.api.nvim_set_keymap('n', brt_config.keymaps["run"], '<cmd>lua require("brt").check_and_run()<CR>',
        { noremap = true, silent = true })
    vim.api.nvim_set_keymap('n', brt_config.keymaps["test"], '<cmd>lua require("brt").check_and_test()<CR>',
        { noremap = true, silent = true })
    vim.api.nvim_set_keymap('n', brt_config.keymaps["quit_tab"], '<cmd>q<CR>', { noremap = true, silent = true })
end

function brt.setup()
    brt.setup_keymap()
end

function brt.set_keymaps(keymaps)
    -- override whatever keymaps over to the brt_config.keymaps
    for key, value in pairs(keymaps) do
        brt_config.keymaps[key] = value
    end
end

function brt.set_project_map(project_map)
    -- override whatever project_map over to the brt_config.project_map
    for key, value in pairs(project_map) do
        if brt_util.str_ends_with(key, "/") then
            brt_config.directory_map[brt_util.str_suffix_strip(key, "/")] = value
        else
            brt_config.project_map[key] = value
        end
    end
end

return brt
