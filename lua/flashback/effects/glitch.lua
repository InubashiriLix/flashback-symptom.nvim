-- Randomly replaces revealed characters with noise glyphs, then restores them.
local glyph = require("flashback.glyph")

return {
    channel = "text",
    priority = 0,
    defaults = {
        color = "#ff00ff",
        density = 0.08, -- fraction of revealed characters corrupted per refresh
        interval = 60,
        pool = "katakana",
    },
    enter = function(ctx)
        ctx.scratch.phase = -1
    end,
    tick = function(_, ctx, t)
        local p = ctx.params
        ctx.text.corrupt_style = { fg = p.color }
        local phase = math.floor(t / math.max(1, p.interval))
        if phase == ctx.scratch.phase then
            return
        end
        ctx.scratch.phase = phase

        ctx.text.corrupt = {}
        local revealed = ctx.text.revealed
        if revealed <= 0 then
            return
        end
        local count = math.max(1, math.floor(revealed * p.density))
        for _ = 1, count do
            ctx.text.corrupt[math.random(1, revealed)] = glyph.pick(ctx.glyph_pools, p.pool)
        end
    end,
    exit = function(ctx)
        ctx.text.corrupt = {}
    end,
}
