-- A blinking caret that trails the typewriter cursor.
return {
    channel = "text",
    priority = 5,
    defaults = {
        blink = 400,
        glyph = "▌",
        color = nil,
    },
    tick = function(_, ctx, t)
        local p = ctx.params
        ctx.text.caret = (math.floor(t / math.max(1, p.blink)) % 2 == 0)
        ctx.text.caret_glyph = p.glyph
        ctx.text.caret_style = p.color and { fg = p.color } or nil
    end,
    exit = function(ctx)
        ctx.text.caret = false
    end,
}
