-- High-frequency positional jitter.
return {
    channel = "win",
    priority = 10,
    defaults = {
        amplitude = 1,
        frequency = 8, -- shakes per second
        axes = "both",
    },
    tick = function(frame, ctx, t)
        local p = ctx.params
        local ph = (t / 1000) * p.frequency * 2 * math.pi
        local row = math.floor(p.amplitude * math.sin(ph) + 0.5)
        local col = math.floor(p.amplitude * math.cos(ph) + 0.5)
        if p.axes == "row" then
            col = 0
        elseif p.axes == "col" then
            row = 0
        end
        frame.row_offset = (frame.row_offset or 0) + row
        frame.col_offset = (frame.col_offset or 0) + col
    end,
}
