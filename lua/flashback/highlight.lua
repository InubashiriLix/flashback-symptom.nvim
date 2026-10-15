-- Style / palette resolution. Everything that turns a declarative style into an
-- actual highlight group lives here, so effects and the composer only ever deal
-- with group *names*.

local M = {}

---@type table<string, string>
local cache = {}

---@param s string
---@return string
local function slug(s)
    return (s:gsub("[^%w]", ""))
end

--- Convert HSL (h in degrees, s/l in 0..1) to #RRGGBB.
---@param h number
---@param s number
---@param l number
---@return string
function M.hsl(h, s, l)
    h = h % 360
    local c = (1 - math.abs(2 * l - 1)) * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = l - c / 2
    local r, g, b
    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end
    local function q(v)
        return math.floor((v + m) * 255 + 0.5)
    end
    return string.format("#%02x%02x%02x", q(r), q(g), q(b))
end

--- Resolve a color value: palette name, "random"/"theme", or literal #RRGGBB.
---@param value string|nil
---@param palette table<string, string>|nil
---@return string|nil
function M.color(value, palette)
    if type(value) ~= "string" then
        return nil
    end
    if value == "random" or value == "theme" or value == "auto" then
        local keys = {}
        for k in pairs(palette or {}) do
            keys[#keys + 1] = k
        end
        if #keys == 0 then
            return "#ffffff"
        end
        return palette[keys[math.random(#keys)]]
    end
    if value:sub(1, 1) == "#" then
        return value
    end
    if palette and palette[value] then
        return palette[value]
    end
    return nil
end

--- Turn a style table into a highlight group name (cached).
---@param style table|nil { fg, bg, attrs, sp, blend }
---@param palette table<string, string>|nil
---@return string
function M.group(style, palette)
    style = style or {}
    local fg = M.color(style.fg, palette)
    local bg = M.color(style.bg, palette)
    local sp = M.color(style.sp, palette)
    local attrs = style.attrs or {}

    local hl = {}
    if fg then
        hl.fg = fg
    end
    if bg then
        hl.bg = bg
    end
    if sp then
        hl.sp = sp
    end
    for _, a in ipairs(attrs) do
        hl[a] = true
    end

    local parts = { fg or "", bg or "", sp or "", table.concat(attrs, ",") }
    local key = table.concat(parts, "|")
    if cache[key] then
        return cache[key]
    end

    local name = "Flashback_" .. slug(vim.fn.sha256(key)):sub(1, 16)
    vim.api.nvim_set_hl(0, name, hl)
    cache[key] = name
    return name
end

--- Group used to paint the whole float window background (winhl -> NormalFloat).
---@param style table|nil
---@param palette table<string, string>|nil
---@return string|nil
function M.win_group(style, palette)
    if not style or not style.bg then
        return nil
    end
    return M.group({ bg = style.bg }, palette)
end

--- Merge overlay style onto a base style (overlay wins).
---@param base table|nil
---@param overlay table|nil
---@return table
function M.merge(base, overlay)
    local out = {}
    for k, v in pairs(base or {}) do
        out[k] = v
    end
    for k, v in pairs(overlay or {}) do
        out[k] = v
    end
    return out
end

return M
