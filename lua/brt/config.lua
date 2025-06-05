local brt_config = {}


brt_config.keymaps = {
    ["build"] = "<leader>b",
    ["run"] = "<leader>r",
    ["test"] = "<leader>t",
    ["debug"] = "<leader>d",
    ["quit_tab"] = "<leader>q",
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

return brt_config
