-- The full-screen keyboard hijack.
--
-- When an `overlay` murmur appears with `hijack.enabled`, every keystroke is
-- swallowed so the murmur really "occupies" you. Unlike the trap there is no
-- phrase to type: it ends when the murmur ends.
--
-- The one way out is a hard-coded double <Esc>. It is intentionally NOT
-- configurable: a full-screen input grab with no escape hatch is a foot-gun.

local M = {}

local NS = vim.api.nvim_create_namespace("flashback_hijack")

---@type any
local owner = nil
local esc = 0

---@param key string
---@return string
local function on_key(key)
    if owner == nil then
        return key
    end
    if key == "\27" then
        esc = esc + 1
        if esc >= 2 then
            M.release(owner)
        end
        return ""
    end
    esc = 0
    return ""
end

--- Take over the keyboard. `token` identifies the owner so it can release it
--- again without clobbering a different murmur.
---@param token any
---@return boolean engaged
function M.engage(token)
    if owner ~= nil then
        return false
    end
    owner = token or true
    esc = 0
    vim.on_key(on_key, NS)
    return true
end

--- Release the keyboard. With no token it releases unconditionally.
---@param token any|nil
function M.release(token)
    if owner == nil then
        return
    end
    if token ~= nil and token ~= owner then
        return
    end
    owner = nil
    esc = 0
    vim.on_key(nil, NS)
end

---@return boolean
function M.is_active()
    return owner ~= nil
end

---@return string|nil
function M.escape_hint()
    return "<Esc><Esc>"
end

return M
