-- Nudges the real cursor around on the current line, then restores it.
--
-- This is the most dangerous effect in the box: it touches the user's cursor.
-- It is disabled globally by default (config.screen.cursor_harass.enabled) and
-- screen.lua refuses to run it while in insert mode unless allow_insert is set.
return {
    channel = "screen",
    priority = 0,
    defaults = {
        interval = 900, -- ms between nudges
        amplitude = 1, -- columns
        allow_insert = false,
    },
    tick = function(frame, ctx, t)
        local p = ctx.params
        frame.screen = frame.screen or {}
        frame.screen.cursor_harass = {
            interval = p.interval,
            amplitude = p.amplitude,
            allow_insert = p.allow_insert,
            t = t,
        }
    end,
}
