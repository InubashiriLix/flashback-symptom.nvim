-- Fades the murmur out (or in) by driving window transparency.
return {
    channel = "win",
    priority = 100, -- fades usually win over pulse
    defaults = {
        duration = 800,
        from = nil, -- nil = start from the current blend
        to = 100,
    },
    tick = function(frame, ctx, t)
        local p = ctx.params
        local dur = math.max(1, p.duration)
        if t > dur then
            return
        end
        local prog = t / dur
        local from = p.from or frame.blend or frame.base_blend or 0
        frame.blend = from + (p.to - from) * prog
    end,
}
