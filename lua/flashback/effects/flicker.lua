-- Colour flicker: the foreground jumps to a jarring colour on a fixed beat.
return {
    channel = "style",
    priority = 0,
    defaults = {
        color = "#ff5555",
        interval = 120,
    },
    tick = function(frame, ctx, t)
        local p = ctx.params
        if math.floor(t / math.max(1, p.interval)) % 2 == 1 then
            frame.style.fg = p.color
        end
    end,
}
