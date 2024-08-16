local brt_config = require("brt.config")
local brt = {}
brt.terminal_command = "bot :terminal"

function brt.build_terminal_command(command)
    return brt.terminal_command .. " cd " .. vim.fn.shellescape(current_dir) .. " && " .. command
end

-- Function to check for project files and run appropriate build command
function brt.check_and_build()
    local current_dir = vim.loop.cwd()
    local generic_build_error = "Cannot perform `build` command"

    for file, project in pairs(brt_config.project_map) do
        local file_path = current_dir .. "/" .. file
        if vim.fn.filereadable(file_path) == 1 then
            print("Found " .. project.name .. " project. Building...")
            if project.build_command == "" then
                print(generic_build_error .. ", no build command found for " .. project.name .. " project.")
                return
            else
                vim.cmd(brt.build_terminal_command(project.build_command))
                return
            end
        end
    end

    print(generic_build_error .. ", no recognized project file found in the current neovim-opened directory.")
end

function brt.check_and_run()
    local current_dir = vim.loop.cwd()
    local generic_run_error = "Cannot perform `run` command"

    for file, project in pairs(brt_config.project_map) do
        local file_path = current_dir .. "/" .. file
        if vim.fn.filereadable(file_path) == 1 then
            print("Found " .. project.name .. " project. Running potential executable...")
            if project.run_command == "" then
                print(generic_run_error .. ", no test command found for " .. project.name .. " project.")
                return
            else
                vim.cmd(brt.build_terminal_command(project.run_command))
                return
            end
        end
    end

    print(generic_run_error .. ", no recognized project file found in the current neovim-opened directory.")
end

function brt.check_and_test()
    local current_dir = vim.loop.cwd()
    local generic_test_error = "Cannot perform `test` command"

    for file, project in pairs(brt_config.project_map) do
        local file_path = current_dir .. "/" .. file
        if vim.fn.filereadable(file_path) == 1 then
            print("Found " .. project.name .. " project. Testing...")
            if project.run_command == "" then
                print(generic_test_error .. ", no test command found for " .. project.name .. " project.")
                return
            else
                vim.cmd(brt.build_terminal_command(project.test_command))
                return
            end
        end
    end

    print(generic_test_error .. ", no recognized project file found in the current neovim-opened directory.")
end

function brt.setup_keymap()
    print("Setup of brt called")
    -- Map the function to <Leader>b
    vim.api.nvim_set_keymap('n', brt_config.keymaps["build"], '<cmd>lua require("brt").check_and_build()<CR>',
        { noremap = true, silent = true })
    vim.api.nvim_set_keymap('n', brt_config.keymaps["run"], '<cmd>lua require("brt").check_and_run()<CR>',
        { noremap = true, silent = true })
    vim.api.nvim_set_keymap('n', brt_config.keymaps["test"], '<cmd>lua require("brt").check_and_test()<CR>',
        { noremap = true, silent = true })
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
        brt_config.project_map[key] = value
    end
end

return brt
