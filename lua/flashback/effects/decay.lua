-- The murmur progressively corrupts and eats itself until nothing is left.
local glyph = require("flashback.glyph")

return {
    channel = "text",
    priority = 0,
    defaults = {
        color = "#ff5555",
        pool = "blocks",
        density = 1.0,
    },
    enter = function(ctx)
        ctx.text.corrupt_style = { fg = ctx.params.color }
    end,
    tick = function(_, ctx, t)
        local p = ctx.params
        ctx.text.corrupt_style = { fg = p.color }
        local prog = math.min(1, t / math.max(1, ctx.duration))

        local keep = math.floor(ctx.text.total * (1 - prog))
        ctx.text.revealed = math.min(ctx.text.revealed, math.max(0, keep))

        local revealed = ctx.text.revealed
        if revealed <= 0 then
            return
        end
        local count = math.max(0, math.floor(revealed * prog * p.density))
        for _ = 1, count do
            ctx.text.corrupt[math.random(1, revealed)] = glyph.pick(ctx.glyph_pools, p.pool)
        end
    end,
    exit = function(ctx)
        ctx.text.corrupt = {}
    end,
}
