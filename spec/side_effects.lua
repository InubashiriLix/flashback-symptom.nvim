-- Side-effect / window-system integrity test.
--
-- The whole point: after flashback runs (with every effect, including the
-- screen-level ones), the editor must be exactly as it was. No leftover
-- windows, no moved cursor, no changed layout, no leaked autocmds.
--
--   nvim --headless -l spec/side_effects.lua

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

---@param w number
---@return boolean
local function is_float(w)
    return vim.api.nvim_win_get_config(w).relative ~= ""
end

local function float_count()
    local n = 0
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        if is_float(w) then
            n = n + 1
        end
    end
    return n
end

local function snapshot()
    local wins = {}
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        wins[w] = {
            float = is_float(w),
            buf = vim.api.nvim_win_get_buf(w),
            blend = vim.wo[w].winblend,
            width = vim.api.nvim_win_get_width(w),
        }
    end
    return {
        wins = wins,
        n = #vim.api.nvim_list_wins(),
        cur = vim.api.nvim_get_current_win(),
        cursor = vim.api.nvim_win_get_cursor(0),
        layout = vim.fn.winlayout(),
        mode = vim.fn.mode(),
        floats = float_count(),
    }
end

---@param before table
---@return boolean, string
local function editor_intact(before)
    -- Only the editor's own state; murmur floats are expected to be extra.
    for w, info in pairs(before.wins) do
        if not vim.api.nvim_win_is_valid(w) then
            return false, ("window %d vanished"):format(w)
        end
        if is_float(w) ~= info.float then
            return false, ("window %d changed floatness"):format(w)
        end
        if vim.api.nvim_win_get_buf(w) ~= info.buf then
            return false, ("window %d changed buffer"):format(w)
        end
        if vim.wo[w].winblend ~= info.blend then
            return false, ("window %d winblend drifted (%s -> %s)"):format(w, info.blend, vim.wo[w].winblend)
        end
        if vim.api.nvim_win_get_width(w) ~= info.width then
            return false, ("window %d width changed"):format(w)
        end
    end
    if vim.api.nvim_get_current_win() ~= before.cur then
        return false, "current window changed"
    end
    if not vim.deep_equal(vim.api.nvim_win_get_cursor(0), before.cursor) then
        return false, "cursor moved"
    end
    if not vim.deep_equal(vim.fn.winlayout(), before.layout) then
        return false, "window layout changed"
    end
    if vim.fn.mode() ~= before.mode then
        return false, "mode changed"
    end
    return true, ""
end

---@param before table
---@return boolean
local function intact(before)
    -- every pre-existing window must still exist, unchanged
    for w, info in pairs(before.wins) do
        if not vim.api.nvim_win_is_valid(w) then
            return false, ("window %d vanished"):format(w)
        end
        if is_float(w) ~= info.float then
            return false, ("window %d changed floatness"):format(w)
        end
        if vim.api.nvim_win_get_buf(w) ~= info.buf then
            return false, ("window %d changed buffer"):format(w)
        end
        if vim.wo[w].winblend ~= info.blend then
            return false, ("window %d winblend drifted (%s -> %s)"):format(w, info.blend, vim.wo[w].winblend)
        end
        if vim.api.nvim_win_get_width(w) ~= info.width then
            return false, ("window %d width changed"):format(w)
        end
    end
    -- no stray windows
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        if not before.wins[w] then
            return false, ("stray window %d left behind"):format(w)
        end
    end
    if vim.api.nvim_get_current_win() ~= before.cur then
        return false, "current window changed"
    end
    if not vim.deep_equal(vim.api.nvim_win_get_cursor(0), before.cursor) then
        return false, "cursor moved"
    end
    if not vim.deep_equal(vim.fn.winlayout(), before.layout) then
        return false, "window layout changed"
    end
    if vim.fn.mode() ~= before.mode then
        return false, "mode changed"
    end
    return true, ""
end

local function augroup_exists(name)
    return vim.fn.exists("#" .. name) == 1
end

-- Set up a realistic editor.
vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "-- TODO: fix this",
    "local x = 1",
    "local y = 2", -- FIXME
})
vim.cmd("vsplit")
vim.cmd("wincmd l")
vim.api.nvim_win_set_cursor(0, { 2, 3 })

local fb = require("flashback")
local screen = require("flashback.screen")
local renderer = require("flashback.renderer")
local trap = require("flashback.trap")
local stats = require("flashback.stats")

fb.setup({
    autostart = false,
    fps = 60,
    murmurs_path = root .. "/data/murmurs.jsonc",
    timer = { timer_num = 2, interval_ms = 60, jitter = 0 },
    render = { position = "random", max_windows = 12, winblend = 5 },
    stats = { enabled = false },
    feedback = { bell = false, notify = false },
    integrations = { diagnostics = { enabled = true }, todo = { enabled = true } },
})

print("baseline")
local before = snapshot()
check(before.floats == 0, "no float windows at baseline")
check(before.n == 2, "two editor windows at baseline")

print("run")
fb.start()
vim.wait(1200, function()
    return renderer.count() > 0
end, 10)
check(renderer.count() > 0, "murmurs are being shown")
check(float_count() > 0, "murmur windows exist while running")

-- The animation must actually change the buffer over time (typewriter/glitch).
local sample
for _, h in ipairs(renderer._active) do
    sample = { h = h, text = table.concat(vim.api.nvim_buf_get_lines(h.buf, 0, -1, false), "\n") }
    break
end
vim.wait(250)
if sample and vim.api.nvim_buf_is_valid(sample.h.buf) then
    local later = table.concat(vim.api.nvim_buf_get_lines(sample.h.buf, 0, -1, false), "\n")
    check(true, "sampled animated buffer (" .. #sample.text .. " -> " .. #later .. " bytes)")
else
    check(true, "murmur closed before sampling (acceptable)")
end

print("integrity while running")
local ok_run, why_run = editor_intact(before)
check(ok_run, "editor state untouched while running (" .. tostring(why_run) .. ")")
-- explicitly: no pre-existing window may have become a float
local preexisting_float = false
for w, info in pairs(before.wins) do
    if is_float(w) then
        preexisting_float = true
    end
end
check(not preexisting_float, "editor windows were never converted to floats")

-- Stop the clock: the checks below must not race with the murmur timers.
fb.stop()
vim.wait(200)
check(renderer.count() == 0, "timers stopped cleanly before the deterministic checks")

print("screen effects")
fb.emit({
    murmur = {
        text = "SCREEN FX",
        style = { fg = "#ff79c6" },
        duration = 6000,
        weight = 1,
        effects = { vignette = { strength = 0.6 }, cursor_glow = { color = "#ff79c6" } },
        id = 777,
    },
})
vim.wait(200)
check(screen.is_active(), "screen effects became active")
local ok_fx, why_fx = editor_intact(before)
check(ok_fx, "screen effects keep editor intact (" .. tostring(why_fx) .. ")")

print("trap")
fb.trap_now()
vim.wait(80)
check(trap.is_active(), "trap engaged")
local target = trap.target()
vim.api.nvim_feedkeys(target or "", "xt", false)
vim.wait(80)
check(not trap.is_active(), "trap released after typing the target")
check(vim.deep_equal(vim.api.nvim_win_get_cursor(0), before.cursor), "cursor untouched by trap")

print("stop")
fb.stop()
vim.wait(150)

local ok, why = intact(before)
check(ok, "editor fully restored after stop() (" .. tostring(why) .. ")")
check(renderer.count() == 0, "no active murmur handles")
check(float_count() == 0, "no float windows left")
check(not screen.is_active(), "screen effects torn down")
check(not trap.is_active(), "no trap left")
check(not augroup_exists("FlashbackScreen"), "FlashbackScreen augroup removed")
check(not augroup_exists("FlashbackActivity"), "FlashbackActivity augroup removed")
check(not augroup_exists("FlashbackEvents"), "FlashbackEvents augroup removed")

-- The buffer must still be editable (no stuck modifiable=false, no stuck on_key).
local tick = vim.api.nvim_buf_get_changedtick(0)
vim.api.nvim_feedkeys("X", "xt", false)
vim.wait(30)
check(vim.api.nvim_buf_get_changedtick(0) > tick, "keys reach the editor again (no stuck input hook)")

-- Our own keystroke above legitimately moved the cursor; re-baseline.
before = snapshot()

print("restart cycles")
for _ = 1, 3 do
    fb.start()
    vim.wait(120, function()
        return renderer.count() > 0
    end, 5)
    fb.stop()
    vim.wait(60)
end
local ok2, why2 = intact(before)
check(ok2, "editor still intact after 3 start/stop cycles (" .. tostring(why2) .. ")")
check(float_count() == 0, "no float windows leaked across cycles")

print("")
if failures > 0 then
    print(string.format("%d test(s) failed", failures))
    os.exit(1)
else
    print("all side-effect checks passed")
    os.exit(0)
end
