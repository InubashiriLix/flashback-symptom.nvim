-- Geometry helpers shared by the float and overlay renderers.
--
-- Everything here is pure math on the editor area; it never touches a window.

local M = {}

---@return number, number
function M.area()
    local ui = vim.api.nvim_list_uis()[1]
    local w = (ui and ui.width) or vim.o.columns
    local h = (ui and ui.height) or (vim.o.lines - vim.o.cmdheight - 1)
    return w, h
end

---@param cfg table
---@return number
function M.border_margin(cfg)
    local b = cfg and cfg.border
    if b == nil or b == "none" then
        return 0
    end
    return 1
end

---@param lines string[]
---@return number, number
function M.measure(lines)
    local w = 1
    for _, l in ipairs(lines) do
        local lw = vim.api.nvim_strwidth(l)
        if lw > w then
            w = lw
        end
    end
    return w, math.max(1, #lines)
end

--- Place a window using the user's `render.position` policy.
---@param cfg FlashbackRenderConfig
---@param w number
---@param h number
---@return number, number
function M.place(cfg, w, h)
    local W, H = M.area()
    local m = M.border_margin(cfg)
    local maxr = math.max(0, H - h - 2 * m)
    local maxc = math.max(0, W - w - 2 * m)
    local mode = cfg.position or "random"

    if mode == "corner" then
        local c = cfg.corner or "botright"
        local r = c:find("top") and 0 or maxr
        local col = c:find("right") and maxc or 0
        return r, col
    elseif mode == "cursor" then
        local off = cfg.cursor_offset or { row = 1, col = 0 }
        local r = vim.fn.screenrow()
        local col = vim.fn.screencol()
        if not r or r <= 0 then
            r, col = 1, 1
        end
        r = math.min(maxr, math.max(0, r - 1 + (off.row or 1)))
        col = math.min(maxc, math.max(0, col - 1 + (off.col or 0)))
        return r, col
    end

    return math.random(0, maxr), math.random(0, maxc)
end

--- Position a rect of size w x h inside the editor area according to `align`.
--- `align` is one of center/top/bottom/left/right/topleft/topright/botleft/botright.
---@param align string|nil
---@param w number
---@param h number
---@param margin number|nil
---@return number, number
function M.align_pos(align, w, h, margin)
    local W, H = M.area()
    margin = margin or 0
    align = align or "center"
    local maxr = math.max(0, H - h - 2 * margin)
    local maxc = math.max(0, W - w - 2 * margin)

    local r, c
    if align:find("top") then
        r = 0
    elseif align:find("bottom") then
        r = maxr
    else
        r = math.floor(maxr / 2)
    end
    if align:find("left") then
        c = 0
    elseif align:find("right") then
        c = maxc
    else
        c = math.floor(maxc / 2)
    end
    return r, c
end

--- Offset of a smaller rect inside a bigger one, according to `anchor`.
---@param anchor string|nil
---@param bw number big width
---@param bh number big height
---@param sw number small width
---@param sh number small height
---@return number, number
function M.anchor_offset(anchor, bw, bh, sw, sh)
    anchor = anchor or "center"
    local dr, dc
    if anchor:find("top") then
        dr = 0
    elseif anchor:find("bottom") then
        dr = bh - sh
    else
        dr = math.floor((bh - sh) / 2)
    end
    if anchor:find("left") then
        dc = 0
    elseif anchor:find("right") then
        dc = bw - sw
    else
        dc = math.floor((bw - sw) / 2)
    end
    return dr, dc
end

return M
