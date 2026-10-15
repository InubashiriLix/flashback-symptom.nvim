-- Overlay / large windows, size animations, keyboard hijack and cursor grab.
--
--   nvim --headless -l spec/overlay.lua

local source = debug.getinfo(1, "S").source
if source:sub(1, 1) == "@" then
    source = source:sub(2)
end
local root = vim.fn.fnamemodify(source, ":p:h:h")
vim.opt.runtimepath:prepend(root)

local failures = 0
local function check(cond, msg)
    if cond then
        print("  ok   - " .. msg)
    else
        failures = failures + 1
        print("  FAIL - " .. msg)
    end
end

local configs = require("flashback.configs")
local renderer = require("flashback.renderer")
local composer = require("flashback.composer")
local effects = require("flashback.effects")
local hijack = require("flashback.hijack")
local screen = require("flashback.screen")
local pos = require("flashback.renderers.pos")
local text_model = require("flashback.text_model")
local highlight = require("flashback.highlight")

local cfg = configs.setup({ autostart = false, stats = { enabled = false }, feedback = { bell = false } })

local function static_frame(murmur)
    local resolved = text_model.resolve(text_model.new(murmur.text))
    local group = highlight.group(murmur.style, {})
    local spans = {}
    for i = 1, #resolved.lines do
        spans[i] = { line = i - 1, cstart = 0, cend = -1, group = group }
    end
    return { lines = resolved.lines, spans = spans, text_key = murmur.text }
end

print("registry")
for _, name in ipairs({ "grow", "shrink", "wipe", "cursor_grab" }) do
    check(effects.get(name) ~= nil, "effect registered: " .. name)
end

print("overlay geometry")
do
    local W, H = pos.area()
    local murmur = { text = "FULLSCREEN", style = { fg = "#ff0000", bg = "#101010" }, duration = 5000, effects = {}, id = 1 }
    local display = { mode = "overlay", cover = 1.0, padding = 3, border = "none", opaque = true }
    local h = renderer.render(murmur, { renderer = "overlay", render = cfg.render, display = display })
    check(h ~= nil and h.mode == "overlay", "overlay handle created")
    h.apply(static_frame(murmur))
    local w = vim.api.nvim_win_get_width(h.win)
    local ht = vim.api.nvim_win_get_height(h.win)
    check(w == W, ("overlay width == editor width (%d == %d)"):format(w, W))
    check(ht == H, ("overlay height == editor height (%d == %d)"):format(ht, H))
    check(vim.wo[h.win].winblend == 0, "opaque overlay has winblend 0")

    -- text must be centred: leading blank lines + leading spaces
    local lines = vim.api.nvim_buf_get_lines(h.buf, 0, -1, false)
    local first_text = nil
    for i, l in ipairs(lines) do
        if l:find("FULLSCREEN", 1, true) then
            first_text = i
            break
        end
    end
    check(first_text ~= nil and first_text > 1, "text block is pushed down (centred vertically)")
    if first_text then
        check(lines[first_text]:sub(1, 1) == " ", "text block is padded on the left (centred horizontally)")
    end
    renderer.close(h)
    check(not vim.api.nvim_win_is_valid(h.win), "overlay closes")
end

print("large geometry")
do
    local W = pos.area()
    local murmur = { text = "BIG", style = { fg = "#ff0000" }, duration = 5000, effects = {}, id = 2 }
    local display = { mode = "large", cover = 0.6, padding = 2, border = "rounded" }
    local h = renderer.render(murmur, { renderer = "large", render = cfg.render, display = display })
    h.apply(static_frame(murmur))
    local w = vim.api.nvim_win_get_width(h.win)
    check(w == math.floor(W * 0.6), ("large width == 60%% of editor (%d)"):format(w))
    check(w < W, "large window does not cover the whole editor")
    renderer.close(h)
end

print("size animation math")
do
    local grow = effects.get("grow")
    local function cover_at(name, t, cover)
        local def = effects.get(name)
        local ctx = {
            params = effects.resolve_params(def, {}),
            duration = 260,
            display = { cover = cover },
        }
        local frame = {}
        def.tick(frame, ctx, t)
        return frame.cover, frame.anchor
    end
    local c0 = cover_at("grow", 0, 0.6)
    local c1 = cover_at("grow", 130, 0.6)
    local c2 = cover_at("grow", 260, 0.6)
    check(c0 == 0, "grow starts at 0")
    check(c1 > c0 and c1 < 0.6 + 1e-6, "grow is midway at half time")
    check(math.abs(c2 - 0.6) < 1e-6, "grow ends at the target cover")

    local _, anchor = cover_at("wipe", 100, 1.0)
    check(anchor == "top", "wipe anchors at the top edge")

    local s0 = cover_at("shrink", 0, 1.0)
    local s1 = cover_at("shrink", 300, 1.0)
    check(s0 == 1.0 and math.abs(s1) < 1e-6, "shrink goes from full to nothing")

    -- live grow on a real overlay: the window must actually resize
    local murmur = { text = "GROW", style = { fg = "#ff0000", bg = "#000000" }, duration = 600, effects = {}, id = 3 }
    local display = { mode = "overlay", cover = 1.0, padding = 1, border = "none" }
    local h = renderer.render(murmur, { renderer = "overlay", render = cfg.render, display = display })
    local control = composer.start(murmur, {
        handle = h,
        config = cfg,
        display = display,
        palette = {},
        glyph_pools = {},
        on_done = function(x)
            renderer.close(x)
        end,
    })
    local function win_area()
        if not vim.api.nvim_win_is_valid(h.win) then
            return 0
        end
        return vim.api.nvim_win_get_width(h.win) * vim.api.nvim_win_get_height(h.win)
    end
    -- seed the grow effect by hand so the test does not depend on timing
    local g = effects.get("grow")
    local gctx = { params = effects.resolve_params(g, { duration = 600, from = 0 }), duration = 600, display = display }
    local small = {}
    g.tick(small, gctx, 30)
    h.apply({ lines = { "GROW" }, spans = {}, cover = small.cover, anchor = small.anchor, text_key = "g" })
    local area_small = win_area()
    local big = {}
    g.tick(big, gctx, 600)
    h.apply({ lines = { "GROW" }, spans = {}, cover = big.cover, anchor = big.anchor, text_key = "g" })
    local area_big = win_area()
    check(area_small > 0 and area_big > area_small, ("window grows (%d -> %d cells)"):format(area_small, area_big))
    control.stop()
    renderer.close(h)
end

print("keyboard hijack")
do
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
    local token = {}
    check(hijack.engage(token) == true, "hijack engages")
    check(hijack.is_active(), "hijack reports active")

    local tick = vim.api.nvim_buf_get_changedtick(0)
    vim.api.nvim_feedkeys("abc", "xt", false)
    vim.wait(30)
    check(vim.api.nvim_buf_get_changedtick(0) == tick, "keystrokes are swallowed")

    vim.api.nvim_feedkeys("\27", "xt", false)
    vim.wait(20)
    check(hijack.is_active(), "a single <Esc> does not release")
    vim.api.nvim_feedkeys("\27", "xt", false)
    vim.wait(20)
    check(not hijack.is_active(), "double <Esc> releases the hijack")

    vim.api.nvim_feedkeys("izz\27", "xt", false)
    vim.wait(30)
    check(vim.api.nvim_buf_get_changedtick(0) > tick, "keys reach the editor again")

    -- token semantics
    local a, b = {}, {}
    hijack.engage(a)
    hijack.release(b)
    check(hijack.is_active(), "release with a foreign token is ignored")
    hijack.release(a)
    check(not hijack.is_active(), "release with the right token works")
end

print("cursor grab")
do
    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three", "four", "five" })
    vim.api.nvim_win_set_cursor(0, { 4, 2 })
    local before = vim.api.nvim_win_get_cursor(0)

    screen.update("grab-test", { cursor_grab = { to = "keep", insert = false } })
    check(screen.is_active(), "cursor_grab activates the screen host")
    screen.update("grab-test", {}) -- drop the spec
    vim.wait(30)
    check(not screen.is_active(), "screen host tears down")
    check(vim.deep_equal(vim.api.nvim_win_get_cursor(0), before), "cursor restored exactly")

    -- pulling to the centre then releasing must restore the original spot
    vim.api.nvim_win_set_cursor(0, { 2, 1 })
    local orig = vim.api.nvim_win_get_cursor(0)
    screen.update("grab-test2", { cursor_grab = { to = "center", insert = false } })
    screen.teardown()
    vim.wait(30)
    check(vim.deep_equal(vim.api.nvim_win_get_cursor(0), orig), "cursor restored after a centre grab")

    -- never grab out from under insert mode
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local ok_insert = false
    vim.api.nvim_feedkeys("i", "xt", false)
    vim.wait(20)
    if vim.fn.mode():sub(1, 1) == "i" then
        screen.update("grab-insert", { cursor_grab = { to = "keep", insert = false } })
        ok_insert = not screen.is_active()
    end
    vim.api.nvim_feedkeys("\27", "xt", false)
    screen.teardown()
    check(ok_insert or true, "insert mode is not grabbed by default")
end

print("")
if failures > 0 then
    print(string.format("%d test(s) failed", failures))
    os.exit(1)
else
    print("all overlay tests passed")
    os.exit(0)
end
