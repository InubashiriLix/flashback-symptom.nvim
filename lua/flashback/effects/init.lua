-- Effect registry. An effect is a three-phase driver that only ever writes into
-- the shared frame / text model:
--
--   enter(ctx)          -- once, when the effect becomes active
--   tick(frame, ctx, t) -- every frame; t is ms since this effect started
--   exit(ctx)           -- once, when it stops
--
-- Effects never touch windows directly; the composer applies the frame.

local M = {}

---@class Effect
---@field channel string informational: "text" | "style" | "win" | "screen"
---@field priority number|nil
---@field defaults table|nil

---@type table<string, Effect>
local registry = {}

---@type string[]
local order = {}

---@param name string
---@param def Effect
function M.register(name, def)
    if not registry[name] then
        order[#order + 1] = name
    end
    registry[name] = def
end

---@param name string
---@return Effect|nil
function M.get(name)
    return registry[name]
end

---@return string[]
function M.names()
    local out = {}
    for i, n in ipairs(order) do
        out[i] = n
    end
    return out
end

---@param def Effect
---@param params table|nil
---@return table
function M.resolve_params(def, params)
    local out = {}
    for k, v in pairs(def.defaults or {}) do
        out[k] = v
    end
    for k, v in pairs(params or {}) do
        out[k] = v
    end
    return out
end

local builtin = {
    "typewriter", "glitch", "decay", "caret",
    "rainbow", "flicker", "pulse",
    "shake", "drift", "fade", "shadow",
    "grow", "shrink", "wipe",
    "vignette", "cursor_glow", "cursor_harass", "cursor_grab",
}

for _, name in ipairs(builtin) do
    local ok, def = pcall(require, "flashback.effects." .. name)
    if ok and type(def) == "table" then
        M.register(name, def)
    end
end

return M
