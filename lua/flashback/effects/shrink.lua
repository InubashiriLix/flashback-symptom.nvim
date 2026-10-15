-- Shrinks the window down to nothing (exit animation).
return require("flashback.effects._resize").make({
    from = nil, -- nil = the target cover
    to = 0,
    anchor = "center",
    duration = 300,
    easing = "ease-out",
})
