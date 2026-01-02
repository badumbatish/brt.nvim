# BRT
Hi everyone! Welcome to my first plugin: BRT (Build, Run, and Test, (and Debug))

The plugin helps automate/alleviate the process of building, running and testing your code.

Once the commands finish running, it pipes errors (only error for now) into a quickfix list for you.

It also remembers every prompt you give it for all 4 commands, just like atuin.
## Demo
See the plugin in action in the following video.

https://youtu.be/sIxkQYV4yMM

## Keymaps

The default keymaps are:
```
<leader>b - Build
<leader>r - Run (the executable)
<leader>d - Debug
<leader>t - Test
<leader>q - Quit the brt tab (it acts as a :q)
<leader>le - Populate the quickfix list with errors from all the buffers.
<leader>lw - Populate the quickfix list with warnings from all the current buffers.
<leader>ld - Populate the quickfix list with lldb stacktrace from current BRT-spawn terminal (stacktrace between two `(lldb) ...`).
<leader>ll - Open a floating window for inspection of the log created from BRT's last run command.
```

## Installation
For lazy.nvim   
```lua  
return {
 "badumbatish/brt.nvim",
  dependencies = {
    "ibhagwan/fzf-lua",  -- add fzf-lua as a dependency
    'kkharji/sqlite.lua', -- sqlite is also needed
  },

 config = function()
   require('brt').setup()
 end
}
```

## Configuration
You can also change 

- The keymap used to invoke brt.nvim.

The full fledged default is here (or you can check the most up to date at lua/brt/config.lua):
```lua

return {
    "badumbatish/brt.nvim",
    -- -- Uncomment these two lines to contribute and develop
    -- -- Remember to create Developer/nvim_proj and clone your fork
    -- dir = "~/Developer/nvim_proj/brt.nvim", or your own folder where brt.nvim is git-cloned
    -- dev = { true },

    config = function()

    local brt_config = {}
    
    -- default config, you don't need to change anything
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

    require('brt').setup(brt_config)
end
}
```

## Contributions
Please feel free to contribute to the plugin. I am open to suggestions and improvements.

Potential todo list includes:
- [ ] Testing: tests are much needed but I'm not quite sure where to start.
- [ ] Non-stopping commands: run a series of commands and only stop if one fails
 
