---@class MurmurItem
---@field text string the text to be murmured
---@field style table { fg, bg, attrs, sp } foreground/background/attributes
---@field duration number the duration of the murmur in milliseconds
---@field effects table<string, table> named effects with their parameters
---@field weight number relative trigger weight
---@field trap boolean|nil whether this murmur hijacks the user's input
---@field unlock_text string|nil text the user must type to escape a trap
---@field when table|nil per-murmur trigger tags (filetypes/modes)
---@field source string|nil where this murmur came from (material/diagnostics/todo)
---@field id number unique id of this murmur

local M = {}

local next_id = 0

---@type MurmurItem[]
local pool = {}

---@type table<string, string>
local palette = {}

---@type table<string, string[]>
local glyph_pools = {}

---@type table<string, table>
local presets = {}

---@param text string
---@param style table|nil
---@param duration number|nil
---@return MurmurItem
function M.new(text, style, duration)
    next_id = next_id + 1
    ---@type MurmurItem
    return {
        text = text or "",
        style = style or {},
        duration = duration or 3000,
        effects = {},
        weight = 1,
        trap = false,
        unlock_text = nil,
        when = nil,
        source = nil,
        id = next_id,
    }
end

---@param material table
function M.set_material(material)
    material = material or {}
    pool = material.murmurs or {}
    palette = material.palette or {}
    glyph_pools = material.glyph_pools or {}
    presets = material.presets or {}
end

---@return MurmurItem[]
function M.get_pool()
    return pool
end

---@return table<string, string>
function M.get_palette()
    return palette
end

---@return table<string, string[]>
function M.get_glyph_pools()
    return glyph_pools
end

---@return table<string, table>
function M.get_presets()
    return presets
end

function M.clear()
    pool, palette, glyph_pools, presets = {}, {}, {}, {}
end

--- Weighted random pick from a list, honouring each item's weight.
---@param list MurmurItem[]
---@param filter fun(m: MurmurItem): boolean|nil
---@return MurmurItem|nil
function M.pick(list, filter)
    local eligible = {}
    local total = 0
    for _, m in ipairs(list or {}) do
        if not filter or filter(m) then
            local w = tonumber(m.weight) or 1
            if w > 0 then
                eligible[#eligible + 1] = m
                total = total + w
            end
        end
    end
    if total <= 0 then
        return nil
    end
    local roll = math.random() * total
    local acc = 0
    for _, m in ipairs(eligible) do
        acc = acc + (tonumber(m.weight) or 1)
        if roll <= acc then
            return m
        end
    end
    return eligible[#eligible]
end

---@param filter fun(m: MurmurItem): boolean|nil
---@return MurmurItem|nil
function M.random(filter)
    return M.pick(pool, filter)
end

---@return MurmurItem|nil
function M.random_trap()
    return M.pick(pool, function(m)
        return m.trap
    end)
end

return M
