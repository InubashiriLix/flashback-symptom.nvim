-- Curtain reveal: the window expands from one edge instead of growing out of a
-- point. `anchor` picks the edge (top/bottom/left/right).
return require("flashback.effects._resize").make({
    from = 0,
    to = nil,
    anchor = "top",
    duration = 320,
    easing = "linear",
})
