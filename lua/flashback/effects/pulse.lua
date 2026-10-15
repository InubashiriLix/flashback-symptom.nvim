-- Breathing transparency.
return {
    channel = "win",
    priority = 0,
    defaults = {
        min = 0,
        max = 70,
        period = 900,
    },
    tick = function(frame, ctx, t)
        local p = ctx.params
        local s = 0.5 + 0.5 * math.sin(2 * math.pi * t / math.max(1, p.period))
        frame.blend = p.min + (p.max - p.min) * s
    end,
}
