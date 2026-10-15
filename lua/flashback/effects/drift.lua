-- Slow, floaty drift, like a stray thought that will not stay put.
return {
    channel = "win",
    priority = 5,
    defaults = {
        dx = 0,
        dy = 1,
        period = 4000,
    },
    tick = function(frame, ctx, t)
        local p = ctx.params
        local s = math.sin(2 * math.pi * t / math.max(1, p.period))
        frame.row_offset = (frame.row_offset or 0) + p.dy * s
        frame.col_offset = (frame.col_offset or 0) + p.dx * s
    end,
}
