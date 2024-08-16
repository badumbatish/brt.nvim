local brt_config = {}

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
        build_command = "cmake -S . -B build -j4 && cmake --build build -j4",
        run_command = "",
        test_command = "ctest --test-dir build",
        name = "CMake"
    },
    ["Makefile"] = {
        build_command = "make -j4",
        run_command = "",
        test_command = "",
        name = "Make"
    },

    -- Add more project types here
}

brt_config.keymaps = {
    ["build"] = "<leader>b",
    ["run"] = "<leader>r",
    ["test"] = "<leader>t",
}


return brt_config
