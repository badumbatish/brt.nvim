local brt_config = {}

-- Map of directories to their build commands

brt_config.directory_map = {
    -- Add more directories here
}


-- Map of project files to their build commands
brt_config.project_map = {
    ["Cargo.toml"] = {
        build_command = "cargo build",
        run_command = "cargo run",
        test_command = "cargo test",
        name = "Rust"
    },
    ["package.json"] = {
        build_command = "npm install && npm run build",
        run_command = "npm run start",
        test_command = "npm run test",
        name = "Node.js"
    },
    ["CMakeLists.txt"] = {
        build_command = "cmake -S . -B build && cmake --build build -j4",
        run_command = "",
        test_command = "ctest --test-dir build --output-on-failure",
        name = "CMake"
    },
    ["Makefile"] = {
        build_command = "make -j4",
        run_command = "",
        test_command = "",
        name = "Make"
    },
    ["mix.exs"] = {
        build_command = "mix compile",
        run_command = "",
        test_command = "mix test",
        name = "Elixir Mix"
    }

    -- Add more project types here
}

brt_config.keymaps = {
    ["build"] = "<leader>b",
    ["run"] = "<leader>r",
    ["test"] = "<leader>t",
    ["quit_tab"] = "<leader>q",
}


return brt_config
