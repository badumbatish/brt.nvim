local brt_config = require("brt.config")
local brt_util = require("brt.util")

local brt = {}
brt.terminal_command = "bot :terminal"

function brt.build_terminal_command(command)
	local current_dir = vim.loop.cwd()
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
		vim.cmd("bd! | close")
	else
		vim.cmd("q")
	end
end

function brt.populate_data(current_dir)
	for file, filetype_config in pairs(brt_config.filetype_map) do
		local file_path = current_dir .. "/" .. file
		if vim.fn.filereadable(file_path) then
			return filetype_config
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

	local current_dir = vim.loop.cwd()
	local tbl = brt_util.load_table()
	local prev_data = brt_util.table_get(tbl, current_dir)

	if not prev_data then
		prev_data = brt.populate_data(current_dir)
	end

	prev_data[cmd_key] = vim.fn.input({
		prompt = "Change/Input to " .. op .. ": ",
		default = prev_data
			[cmd_key] or ""
	})

	if (prev_data[cmd_key] == "") then return end
	tbl[current_dir] = prev_data

	brt_util.save_table(tbl)
	brt.execute_terminal_command(prev_data[cmd_key])
end

function brt.setup(opts)
	brt_util.create_file_if_empty()
	if opts and opts.keymaps then
		brt.set_keymaps(opts.keymaps)
	else
		brt.set_keymaps(brt_config.keymaps)
	end

	if opts and opts.filetype_map then
		brt.set_filetype_map(opts.project_map)
	else
		brt.set_filetype_map(brt_config.filetype_map)
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
