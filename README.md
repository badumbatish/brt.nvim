# BRT

Hi everyone! Welcome to my first plugin: BRT (Build, Run, and Test, (and Debug))

The plugin helps automate/alleviate the process of building, running and testing your code.

Once the commands finish running, it pipes errors (only error for now) into a quickfix list for you.

It also remembers every prompt you give it for all 4 commands, just like atuin.
## Demo
See the plugin in action below:

[![asciicast](https://asciinema.org/a/672407.svg)](https://asciinema.org/a/672407)

## Keymaps

The default keymaps are:
```
<leader>b - Build
<leader>r - Run (the executable)
<leader>d - Debug
<leader>t - Test
<leader>q - Quit the brt tab (it acts as a :q)
<leader>le - Populate the quickfix list with errors from all the buffers.
<leader>le - Populate the quickfix list with warnings from all the current buffers.
```

## Installation
For lazy.nvim   
```lua  
return {
 "badumbatish/brt.nvim",
  dependencies = {
    "ibhagwan/fzf-lua",  -- add fzf-lua as a dependency
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
    -- dir = "~/Developer/nvim_proj/brt.nvim",
    -- dev = { true },

    config = function()

    local brt_config = {}

    brt_config.keymaps = {
        ["build"] = "<leader>b",
        ["run"] = "<leader>r",
        ["test"] = "<leader>t",
        ["debug"] = "<leader>d",
        ["quit_tab"] = "<leader>q",
        ["quickfix_error"] = "<leader>le",
        ["quickfix_warning"] = "<leader>lw"
    }

    require('brt').setup()
end
}
```

## Contributions
Please feel free to contribute to the plugin. I am open to suggestions and improvements.

Potential todo list includes:
- [ ] Add more project types: OCaml, Haskell, gleam, java, etc...
- [ ] Non-stopping commands: run a series of commands and only stop if one fails
 
