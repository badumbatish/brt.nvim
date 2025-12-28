# BRT.nvim

**Build, Run, Test (and Debug)** for Neovim.

## What is this?

BRT lets you build, run, and test your code without leaving Neovim. No more switching to a terminal tab, running commands, then switching back to fix errors.

If you work on large codebases like LLVM, Clang, or anything that requires constant terminal usage, you know how annoying the context switch is. BRT keeps everything in your editor.

## Features

- **Command history** — BRT remembers every command you run (stored in SQLite). Similar to [atuin](https://github.com/atuinsh/atuin), you can fuzzy search through your history.

- **Quickfix integration** — When your build fails, BRT automatically parses the terminal output and pipes errors into the quickfix list. Press `n` within the quickfix to jump straight to the file and line where the error occurred. No more manually scrolling through terminal output trying to find what broke.

- **LLDB stacktrace support** — If you're debugging, `<leader>ld` extracts lldb stacktraces into quickfix so you can jump to the relevant frames.

- **Shell expansion works** — Globs, environment variables, pipes — it all works like you'd expect.

## Requirements

- Neovim 0.9+
- [fzf](https://github.com/junegunn/fzf) 0.56.0+
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [sqlite.lua](https://github.com/kkharji/sqlite.lua)

**Note:** Ubuntu repos have an outdated fzf version. You'll need to install fzf manually if you're on Ubuntu:
```bash
# Install latest fzf manually
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
```

## Installation

```lua
-- lazy.nvim
return {
  "badumbatish/brt.nvim",
  dependencies = {
    "ibhagwan/fzf-lua",
    "kkharji/sqlite.lua",
  },
  config = function()
    require("brt").setup()
  end,
}
```

## Keymaps

| Key | What it does |
|-----|--------------|
| `<leader>b` | Build |
| `<leader>r` | Run |
| `<leader>t` | Test |
| `<leader>d` | Debug |
| `<leader>q` | Close BRT window |
| `<leader>le` | Load errors into quickfix |
| `<leader>lw` | Load warnings into quickfix |
| `<leader>ld` | Load lldb stacktrace into quickfix |
| `<leader>ll` | Open BRT log |

When the picker is open:
- `Enter` — run the command
- `Ctrl-y` — copy command to input
- `Ctrl-u` — clear input
- `Esc` — close

## Configuration

```lua
require("brt").setup({
  keymaps = {
    ["build"] = "<leader>b",
    ["run"] = "<leader>r",
    ["test"] = "<leader>t",
    ["debug"] = "<leader>d",
    ["quit_tab"] = "<leader>q",
    ["show_log"] = "<leader>ll",
    ["quickfix_error"] = "<leader>le",
    ["quickfix_warning"] = "<leader>lw",
    ["quickfix_debug_terminal"] = "<leader>ld",
  },
})
```

## Contributing

Open to suggestions and PRs. Some ideas:
- More project type templates
- Command chaining (run multiple commands, stop on failure)

## License

MIT

## Credits

Made by [@badumbatish](https://github.com/badumbatish)
