-- Reveals the murmur character by character.
return {
    channel = "text",
    priority = -10,
    defaults = {
        speed = nil, -- ms per character; nil = spread over the murmur duration
        min_speed = 20,
        max_speed = 120,
    },
    enter = function(ctx)
        ctx.text.revealed = 0
    end,
    tick = function(_, ctx, t)
        local p = ctx.params
        local speed = p.speed
        if not speed then
            speed = math.min(p.max_speed, math.max(p.min_speed, math.floor(ctx.duration / ctx.text.total)))
        end
        speed = math.max(1, speed)
        local n = math.floor(t / speed) + 1
        if n > ctx.text.revealed then
            ctx.text.revealed = math.min(ctx.text.total, n)
        end
    end,
}
