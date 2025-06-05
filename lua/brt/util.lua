local util = {}
util.data_file = vim.fn.stdpath("data") .. "/brt_local_data.json"
function util.str_suffix_strip(str, suffix)
	return string.gsub(str, suffix .. "+$", "")
end

function util.str_has(str, pattern)
	return str:find(pattern)
end

function util.str_ends_with(str, ending)
	return ending == "" or str:sub(- #ending) == ending
end

-- Merge suffix of string A with prefix of string B into 1 substring, A and B goes into a new string
function util.merge_strings(A, B)
	-- Find the longest suffix of A that matches the prefix of B
	for i = #A, 1, -1 do
		local suffix = A:sub(i)
		if B:find("^" .. suffix) then
			-- Merge the strings by removing the overlapping part from B
			return A .. B:sub(#suffix + 1)
		end
	end
	-- If no overlap is found, concatenate the strings normally
	return A .. B
end

function util.save_table(tbl)
	local json = vim.fn.json_encode(tbl)
	vim.fn.writefile({ json }, util.data_file)
end

function util.load_table()
	if vim.fn.filereadable(util.data_file) == 1 then
		local content = table.concat(vim.fn.readfile(util.data_file), "\n")
		local ok, result = pcall(vim.fn.json_decode, content)
		if ok then return result end
	end
	return {}
end

function util.create_file_if_empty()
	if vim.fn.filereadable(util.data_file) == 0 then
		vim.fn.writefile({}, util.data_file)
	end
end

function util.table_get(tbl, key)
	for k, v in pairs(tbl) do
		if vim.fn.match(k, key) ~= -1 then
			return v
		end
	end

	return nil
end

return util
