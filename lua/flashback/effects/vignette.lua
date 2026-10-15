-- Darkens the edges of the screen (implemented by screen.lua as edge overlays).
return {
    channel = "screen",
    priority = 0,
    defaults = {
        color = "#000000",
        strength = 0.6, -- 0..1
        thickness = 1,
    },
    tick = function(frame, ctx)
        local p = ctx.params
        frame.screen = frame.screen or {}
        frame.screen.vignette = {
            color = p.color,
            strength = p.strength,
            thickness = p.thickness,
        }
    end,
}
