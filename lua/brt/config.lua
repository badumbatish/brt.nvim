local brt_config = {}


brt_config.keymaps = {
    ["build"] = "<leader>b", -- build the project
    ["run"] = "<leader>r", -- run the project
    ["test"] = "<leader>t", -- test the project
    ["debug"] = "<leader>d", -- debug the project (this correctly enables <leader>ld)
    ["quit_tab"] = "<leader>q", -- quit quickfix list and/or terminal
    ["show_log"] = "<leader>ll", 
    ["quickfix_warning"] = "<leader>lw",
    ["quickfix_error"] = "<leader>le",
    ["quickfix_debug_terminal"] = "<leader>ld",
}

return brt_config
