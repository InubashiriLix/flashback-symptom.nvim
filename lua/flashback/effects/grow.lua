-- Grows the window from a point out to its full size (entry animation).
return require("flashback.effects._resize").make({
    from = 0, -- nil = the target cover
    to = nil, -- nil = the target cover
    anchor = "center",
    duration = 260,
    easing = "ease-out",
})
