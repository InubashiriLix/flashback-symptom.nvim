-- The shared text model. Every text-mutating effect (typewriter / glitch /
-- decay / caret) writes into this single structure, and one resolver turns it
-- into final lines plus a per-character position map. This is what lets those
-- effects compose instead of fighting over `frame.text`.

local M = {}

---@param s string
---@param i number zero-based char index
---@return string
local function char_at(s, i)
    return vim.fn.strcharpart(s, i, 1)
end

---@param source string
---@return table
function M.new(source)
    source = source or ""
    local total = math.max(1, vim.fn.strchars(source))
    return {
        source = source,
        total = total,
        revealed = total,
        corrupt = {},
        caret = false,
        caret_glyph = "▌",
        corrupt_style = nil,
        caret_style = nil,
    }
end

--- Resolve the model into renderable lines + a position map.
---@param model table
---@return { lines: string[], pos: table[], caret: table|nil }
function M.resolve(model)
    local lines = {}
    local pos = {}
    local caret_pos = nil
    local cur = {}
    local line_no = 1
    local byte_col = 0
    local caret_glyph = model.caret_glyph or "▌"
    local caret_at = math.min(model.revealed + 1, model.total + 1)

    local function flush_line()
        lines[#lines + 1] = table.concat(cur)
        cur = {}
        line_no = line_no + 1
        byte_col = 0
    end

    local function put_caret()
        local cstart = byte_col
        cur[#cur + 1] = caret_glyph
        byte_col = byte_col + #caret_glyph
        caret_pos = { line = line_no, cstart = cstart, cend = byte_col }
    end

    for i = 1, model.total do
        if model.caret and i == caret_at then
            put_caret()
        end

        local src = char_at(model.source, i - 1)
        local revealed = i <= model.revealed
        local shown, corrupt = nil, false
        if revealed then
            if model.corrupt[i] then
                shown, corrupt = model.corrupt[i], true
            else
                shown = src
            end
        else
            shown = (src == "\n") and "\n" or " "
        end

        if shown == "\n" then
            flush_line()
        else
            local cstart = byte_col
            cur[#cur + 1] = shown
            byte_col = byte_col + #shown
            pos[i] = { line = line_no, cstart = cstart, cend = byte_col, corrupt = corrupt, revealed = revealed }
        end
    end

    -- Caret at the very end (nothing left to reveal).
    if model.caret and caret_at > model.total then
        put_caret()
    end

    flush_line()
    return { lines = lines, pos = pos, caret = caret_pos }
end

return M
