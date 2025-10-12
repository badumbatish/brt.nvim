# BRT

Hi everyone! Welcome to my first plugin: BRT (Build, Run, and Test, (and Debug))

The plugin helps automate/alleviate the process of building, running and testing your code.

Instead of having to type out the commands to build, run, and test your code, you can set the commands in the BRT plugins to do it for you.

BRT will look inside your neovim-invoked directory and check for a match to run your commands.

For example:
- If your directory contains `Cargo.toml`, pressing `<leader>b` will run `cargo build` in the terminal.

- If you have a `Makefile`, pressing `<leader>b` will run `make -j4` in the terminal.

- If you have a `CMakeLists.txt`, pressing `<leader>b` will run `cmake --build build -j4` in the terminal.

It automatically detects these files once you give it the filetype to look for and which command to build, please see [Configuration](#Configuration) for more information.

It also remembers every prompt you give it for all 4 commands, committed to your directory.
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
- The keymap used as placeholder for different file types.

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

    brt_config.filetype_map = {
        ["Cargo.toml"] = {
            build_command = "cargo build",
            run_command = "cargo run",
            debug_command = "",
            test_command = "cargo test",
        },
        ["package.json"] = {
            build_command = "npm install && npm run build",
            run_command = "npm run start",
            debug_command = "",
            test_command = "npm run test",
        },
        ["CMakeLists.txt"] = {
            build_command = "cmake --build build -j4",
            run_command = "./build/",
            debug_command = "lldb -- ./build/",
            test_command = "ctest --test-dir build --output-on-failure",
        },
        ["Makefile"] = {
            build_command = "make -j4",
            run_command = "make run",
            debug_command = "",
            test_command = "make test",
        },
        ["mix.exs"] = {
            build_command = "mix compile",
            run_command = "",
            debug_command = "",
            test_command = "mix test",
        }

        -- Add more project types here
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
 
