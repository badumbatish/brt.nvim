local util = {}

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

return util
