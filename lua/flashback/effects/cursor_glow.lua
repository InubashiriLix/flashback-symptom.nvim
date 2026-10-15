-- A glowing halo that follows the cursor.
return {
    channel = "screen",
    priority = 0,
    defaults = {
        color = "#ff79c6",
        blend = 55,
        padding = 0,
    },
    tick = function(frame, ctx)
        local p = ctx.params
        frame.screen = frame.screen or {}
        frame.screen.cursor_glow = {
            color = p.color,
            blend = p.blend,
            padding = p.padding,
        }
    end,
}
