-- The input hijack. When a trapped murmur shows up, we take over the keyboard
-- with vim.on_key, swallow every keystroke, and only give control back once the
-- user has typed the unlock text character for character.
--
-- A double <Esc> is the emergency escape (config.trap.escape), because a plain
-- vim.on_key hijack can otherwise lock someone inside Neovim forever.

local uv = vim.uv or vim.loop
local renderer = require("flashback.renderer")
local stats = require("flashback.stats")

local M = {}

local NS = vim.api.nvim_create_namespace("flashback_trap")

local HINT = "键入以下内容以解脱："

vim.api.nvim_set_hl(0, "FlashbackTrapHint", { fg = "#888888", italic = true })
vim.api.nvim_set_hl(0, "FlashbackTrapOk", { fg = "#50fa7b", bold = true })
vim.api.nvim_set_hl(0, "FlashbackTrapTodo", { fg = "#ff5555" })

---@class TrapState
---@field target string
---@field total number
---@field index number
---@field esc number
---@field handle table
---@field cfg FlashbackTrapConfig
---@field start_ns number

---@type TrapState|nil
local state = nil

---@param target string
---@param index number
---@return number
local function byte_offset(target, index)
    return #vim.fn.strcharpart(target, 0, index)
end

local function redraw()
    if not state then
        return
    end
    local target = state.target
    local lines = {
        HINT,
        target,
        string.format("[ %d / %d ]", state.index, state.total),
    }
    local cut = byte_offset(target, state.index)
    local spans = {
        { line = 0, cstart = 0, cend = -1, group = "FlashbackTrapHint" },
        { line = 1, cstart = 0, cend = cut, group = (state.index > 0) and "FlashbackTrapOk" or "FlashbackTrapTodo" },
        { line = 1, cstart = cut, cend = -1, group = "FlashbackTrapTodo" },
        { line = 2, cstart = 0, cend = -1, group = "FlashbackTrapHint" },
    }
    state.handle.apply({
        lines = lines,
        spans = spans,
        blend = state.handle.base_blend,
        text_key = table.concat(lines, "\n") .. "|trap|" .. state.index,
    })
end

---@param key string
---@return string
local function handle_key(key)
    if key == "\27" then
        if state.cfg.escape then
            state.esc = state.esc + 1
            if state.esc >= 2 then
                M.disengage(true)
                return ""
            end
        end
        return ""
    end
    state.esc = 0

    local chars = vim.fn.strchars(key)
    for i = 1, chars do
        local c = vim.fn.strcharpart(key, i - 1, 1)
        local expected = vim.fn.strcharpart(state.target, state.index, 1)
        if c == expected then
            state.index = state.index + 1
        else
            state.index = 0
        end
        if state.index >= state.total then
            M.disengage(false)
            return ""
        end
    end

    redraw()
    return ""
end

---@param key string
---@return string
local function on_key(key)
    if not state then
        return key
    end
    local ok, res = pcall(handle_key, key)
    if not ok then
        vim.schedule(function()
            vim.notify("flashback: trap error: " .. tostring(res), vim.log.levels.ERROR)
            M.disengage(false)
        end)
        return ""
    end
    return res
end

--- Take over the keyboard until the user types the unlock text.
---@param murmur MurmurItem
---@param handle table
---@param cfg FlashbackTrapConfig
function M.engage(murmur, handle, cfg)
    if state then
        M.disengage(false)
    end

    if handle.cancel_lifetime then
        pcall(handle.cancel_lifetime)
    end

    local target = murmur.unlock_text or murmur.text or ""
    state = {
        target = target,
        total = math.max(1, vim.fn.strchars(target)),
        index = 0,
        esc = 0,
        handle = handle,
        cfg = cfg or {},
        start_ns = uv.hrtime(),
    }

    vim.on_key(on_key, NS)
    redraw()
end

---@param escaped boolean
function M.disengage(escaped)
    if not state then
        return
    end
    local handle = state.handle
    local ms = (uv.hrtime() - state.start_ns) / 1e6
    state = nil
    vim.on_key(nil, NS)

    stats.bump("trap_ms", math.floor(ms))
    if escaped then
        stats.bump("escapes")
    end

    if handle then
        renderer.close(handle)
    end
end

---@return boolean
function M.is_active()
    return state ~= nil
end

---@return string|nil
function M.target()
    return state and state.target or nil
end

return M
