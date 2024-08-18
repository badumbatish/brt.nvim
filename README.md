# BRT

Hi everyone! Welcome to my first plugin: BRT (Build, Run, and Test)

The plugin helps automate/alleviate the process of building, running and testing your code.

Instead of having to type out the commands to build, run, and test your code, you can set the commands in the BRT plugins to do it for you.

BRT will look inside your neovim-invoked directory and check for a match to run your commands.

For example
- If your directory contains `Cargo.toml`, pressing `<leader>b` will run `cargo build` in the terminal.

- If you have a `Makefile`, pressing `<leader>b` will run `make -j4` in the terminal.

- If you have a `CMakeLists.txt`, pressing `<leader>b` will run `cmake -S . -B build && cmake --build build -j4` in the terminal.

- If you have a special workspace directory that uses `CMakeLists.txt`, you can configure the special directory to use a different command instead, see [Configuration](##Configuration) for more information.

It automatically detects these files once you give it the filetype to look for and which command to build, please see [Configuration](##Configuration) for more information.

## Demo
See the plugin in action below:

[![asciicast](https://asciinema.org/a/672407.svg)](https://asciinema.org/a/672407)

## Keymaps

The default keymaps are:
```
<leader>b - Build
<leader>r - Run (the executable)
<leader>t - Test
<leader>q - Quit the brt tab (it acts as a :q)
```

## Installation
For Lazy   
```lua  
return {
 "badumbatish/brt.nvim",

 config = function()
   require('brt').setup()
 end
}
```

## Configuration
You can also change how BRT invokes the command itself. Please see 

https://github.com/badumbatish/brt.nvim/blob/main/lua/brt/config.lua

and provide your own configuration with the brt.set_* functions found in `init.lua`

You only need to provide the configuration that you want to change. The rest will be set to the default values.

### File-type based configuration
For example, if you want to change a CMake project to use `ninja` instead of the default `make`, you only need to do the following in your lua configuration file,
where the green text is the new configuration and the red text is the default configuration.
```diff
local project_map =  {

   ["CMakeLists.txt"] = {

+       build_command = "cmake -G ninja -S . -B build && cmake --build build -j4",
-       build_command = "cmake -S . -B build && cmake --build build -j4",

        run_command = "",
        test_command = "ctest --test-dir build",
        name = "CMake"
    }
    }

require('brt').set_project_map(project_map)
require('brt').setup()
```

### Directory based configuration
If you want to configure not based on the file type such as `CMakeLists.txt` but on the directory instead, add the `/` on your project\_map key.

Keys ending with / means that it is a directory, and will be considered first, then comes the file types matching
```diff

local project_map =  {

+   ["sammine-lang/"] = {
        ...
    }
    }

require('brt').set_project_map(project_map)
require('brt').setup()
```


You need to call `brt.set_*` functions before calling `require('brt').setup()` in your `init.lua` file.

Calling `brt.set_*` functions after `require('brt').setup()` will not work since `setup()` will ignore some part of the overridden configuration.

## Contributions
Please feel free to contribute to the plugin. I am open to suggestions and improvements.

Potential todo list includes:
- [ ] Add more project types: OCaml, Haskell, gleam, java, etc...
- [ ] Add more command types: fmt, lint, combo  etc...
- [ ] Non-stopping commands: run a series of commands and only stop if one fails
 
