-- Shared glyph picking for glitch / decay. Kept in its own module so effect
-- modules never have to require the effect registry (which would be circular).
local M = {}

local FALLBACK = { "#", "?", "*", "%" }

---@param glyph_pools table<string, string[]>|nil
---@param pool string|string[]|nil
---@return string
function M.pick(glyph_pools, pool)
    local list
    if type(pool) == "table" then
        list = pool
    elseif type(pool) == "string" and glyph_pools and glyph_pools[pool] then
        list = glyph_pools[pool]
    elseif glyph_pools and glyph_pools.katakana then
        list = glyph_pools.katakana
    end
    if not list or #list == 0 then
        list = FALLBACK
    end
    return list[math.random(#list)]
end

return M
