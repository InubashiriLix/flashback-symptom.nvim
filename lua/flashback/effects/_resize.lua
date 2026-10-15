-- Shared core for the size-animation effects (grow / shrink / wipe).
--
-- It writes `frame.cover` (0..1 of the display cover) and `frame.anchor`
-- (where the rect grows from); the overlay renderer turns those into a window
-- rect. Effects are just parameter presets of this.

local M = {}

---@param defaults table
---@return table
function M.make(defaults)
    return {
        channel = "win",
        priority = 30,
        defaults = defaults,
        tick = function(frame, ctx, t)
            local p = ctx.params
            local target = (ctx.display and ctx.display.cover) or 1.0
            local dur = math.max(1, p.duration or ctx.duration)
            local prog = math.min(1, t / dur)
            if p.easing ~= "linear" then
                prog = 1 - (1 - prog) * (1 - prog) -- ease-out quad
            end

            local from = p.from
            if from == nil then
                from = target
            end
            local to = p.to
            if to == nil then
                to = target
            end

            frame.cover = from + (to - from) * prog
            frame.anchor = p.anchor
        end,
    }
end

return M
