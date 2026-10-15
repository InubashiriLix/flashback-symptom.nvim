-- Cycles the colour around the hue wheel. With per_char it paints every glyph
-- a different hue via per-character spans.
local highlight = require("flashback.highlight")

return {
    channel = "style",
    priority = 0,
    defaults = {
        speed = 25, -- hue degrees per 100ms (higher = faster)
        saturation = 0.85,
        lightness = 0.6,
        per_char = false,
    },
    tick = function(frame, ctx, t)
        local p = ctx.params
        local base = (t / 100) * p.speed
        if p.per_char then
            frame.char_style = function(i, n)
                local h = (base + (i - 1) * (360 / math.max(1, n))) % 360
                return { fg = highlight.hsl(h, p.saturation, p.lightness) }
            end
        else
            frame.style.fg = highlight.hsl(base % 360, p.saturation, p.lightness)
        end
    end,
}
