local brt_config = require("brt.config")
local brt_util = require("brt.util")

local brt = {}
brt.terminal_command = "bot :terminal"

function brt.build_terminal_command(command)
    local current_dir = vim.uv.cwd()
    if not current_dir then
        current_dir = "."
    end
    return brt.terminal_command .. " cd " .. vim.fn.shellescape(current_dir) .. " && " .. command
end

function brt.execute_terminal_command(command)
    if command == "" then return end
    vim.cmd(brt.build_terminal_command(command))
    vim.api.nvim_feedkeys('G', 'n', true)
end

function brt.handle_quit()
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = 0 })
    -- print("Keymap triggered!")
    if buftype == "terminal" then
        vim.cmd("bd!")
    else
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
            lnum = diagnostic.lnum + 1,  -- LSP is 0-indexed, quickfix is 1-indexed
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
        elseif (severity_filter == 'E')  then
          vim.notify("Populated quickfix list of all errors")
        else
          vim.notify("Populated quickfix list of current buffer warnings")
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

    local current_dir = vim.uv.cwd()
    local tbl = brt_util.load_table()
    local prev_data = brt_util.table_get(tbl, current_dir)

    if not prev_data then
        prev_data = brt.populate_data(current_dir)
        brt_util.save_table(tbl)
    end

    prev_data[cmd_key] = vim.fn.input({
        prompt = "Change/Input to " .. op .. ": ",
        default = prev_data[cmd_key]
    })

    if (brt_util.only_spaces(prev_data[cmd_key])) then return end
    if current_dir then
        tbl[current_dir] = prev_data
    end

    brt_util.save_table(tbl)
    brt.execute_terminal_command(prev_data[cmd_key])
    -- TODO: this needs to wait until run or build is finished
    -- if (valid_ops[op] == "build_command" or valid_ops[op] == "run_command") then
    --   brt.lsp_to_quickfix("E", true)
    -- end
end

function brt.setup(opts)
    brt_util.create_file_if_empty()
    if opts and opts.keymaps then
        brt.set_keymaps(opts.keymaps)
    end

    if opts and opts.filetype_map then
        brt.set_filetype_map(opts.project_map)
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
    vim.api.nvim_set_keymap('n', brt_config.keymaps["quickfix_error"], '<cmd>lua require("brt").lsp_to_quickfix("E", false)<CR>',
        { noremap = true, silent = true })
    vim.api.nvim_set_keymap('n', brt_config.keymaps["quickfix_warning"], '<cmd>lua require("brt").lsp_to_quickfix("W", false)<CR>',
        { noremap = true, silent = true })
end

function brt.set_keymaps(keymaps)
    -- override whatever mapping over to the brt_config.keymaps
    for key, value in pairs(keymaps) do
        brt_config.keymaps[key] = value
    end
end

function brt.set_filetype_map(filetype_map)
    -- override whatever mapping over to the brt_config.filetype_map
    for key, value in pairs(filetype_map) do
        brt_config.filetype_map[key] = value
    end
end

return brt
