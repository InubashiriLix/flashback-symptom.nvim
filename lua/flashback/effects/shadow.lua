-- Draws a darker copy of the murmur behind and slightly offset from it.
return {
    channel = "win",
    priority = 20,
    defaults = {
        dx = 1,
        dy = 1,
        color = "#000000",
        blend = 60,
    },
    tick = function(frame, ctx)
        local p = ctx.params
        frame.shadow = {
            enabled = true,
            dx = p.dx,
            dy = p.dy,
            color = p.color,
            blend = p.blend,
        }
    end,
}
