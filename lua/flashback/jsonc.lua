-- Minimal JSONC pre-processor.
--
-- `vim.json.decode` is strict JSON: no comments, no trailing commas. Material
-- files are meant to be hand-written and commented, so we strip both before
-- handing the text to the decoder.
--
-- The scan is string-aware, which matters because URLs (`https://...`) and
-- text values frequently contain `//` and `/*`.

local M = {}

---@param text string
---@return string
function M.strip(text)
    if type(text) ~= "string" then
        return text
    end

    local out = {}
    local i, n = 1, #text
    local in_str = false

    ---@param from number
    ---@return number index just past the comment, or n+1 if unterminated
    local function skip_line_comment(from)
        local j = text:find("\n", from, true)
        return j or (n + 1)
    end

    ---@param from number
    ---@return number
    local function skip_block_comment(from)
        local j = text:find("*/", from, true)
        return j and (j + 2) or (n + 1)
    end

    while i <= n do
        local c = text:sub(i, i)

        if in_str then
            if c == "\\" then
                out[#out + 1] = text:sub(i, i + 1)
                i = i + 2
            else
                out[#out + 1] = c
                if c == '"' then
                    in_str = false
                end
                i = i + 1
            end
        elseif c == '"' then
            in_str = true
            out[#out + 1] = c
            i = i + 1
        elseif c == "/" and text:sub(i + 1, i + 1) == "/" then
            i = skip_line_comment(i + 2)
        elseif c == "/" and text:sub(i + 1, i + 1) == "*" then
            i = skip_block_comment(i + 2)
        elseif c == "," then
            -- Look ahead (skipping whitespace and comments) for a closing
            -- bracket; if that is what follows, the comma is trailing.
            local j = i + 1
            while j <= n do
                local d = text:sub(j, j)
                if d == " " or d == "\t" or d == "\r" or d == "\n" then
                    j = j + 1
                elseif d == "/" and text:sub(j + 1, j + 1) == "/" then
                    j = skip_line_comment(j + 2)
                elseif d == "/" and text:sub(j + 1, j + 1) == "*" then
                    j = skip_block_comment(j + 2)
                else
                    break
                end
            end
            local nextc = text:sub(j, j)
            if nextc == "}" or nextc == "]" then
                i = i + 1 -- drop the trailing comma
            else
                out[#out + 1] = c
                i = i + 1
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end

    return table.concat(out)
end

return M
