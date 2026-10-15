-- Grabs the real cursor and holds it there for the duration, then restores it.
--
-- Safety: screen.lua always restores the exact window + position it captured,
-- refuses to grab while in insert mode unless `insert = true`, and re-asserts
-- the held position on a timer (never via CursorMoved, which would recurse).
return {
    channel = "screen",
    priority = 0,
    defaults = {
        to = "keep", -- "keep" holds it in place, "center" pulls it to the window centre
        insert = false,
    },
    tick = function(frame, ctx)
        local p = ctx.params
        frame.screen = frame.screen or {}
        frame.screen.cursor_grab = { to = p.to, insert = p.insert }
    end,
}
