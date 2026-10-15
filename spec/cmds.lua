-- Minimal smoke tests.
--
--   nvim --headless -l spec/cmds.lua

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

print("configs")
local configs = require("flashback.configs")
check(type(configs.defaults) == "table", "defaults exist")
check(configs.defaults.fps > 0, "default fps > 0")
local merged = configs.setup({ timer = { timer_num = 9 } })
check(merged.timer.timer_num == 9, "setup overrides timer_num")
check(merged.timer.interval_ms == configs.defaults.timer.interval_ms, "setup keeps defaults")
check(merged.effects.enabled.glitch == true, "effects.enabled present")

print("json_parser")
local json_parser = require("flashback.json_parser")
local material, err = json_parser.load(configs.defaults.murmurs_path)
check(material ~= nil, "material loads (" .. tostring(err) .. ")")
check(#material.murmurs > 0, "murmurs non-empty")
check(next(material.palette) ~= nil, "palette parsed")
check(next(material.presets) ~= nil, "presets parsed")
check(next(material.glyph_pools) ~= nil, "glyph pools parsed")

local preset_applied = false
for _, m in ipairs(material.murmurs) do
    if m.text == "你确定这里不需要判空吗？" then
        preset_applied = type(m.style) == "table" and m.style.fg == "blood" and type(m.effects.glitch) == "table"
    end
end
check(preset_applied, "preset style + effects merged")

local trapped = false
for _, m in ipairs(material.murmurs) do
    if m.trap then
        trapped = true
    end
end
check(trapped, "at least one trapped murmur")

print("murmurs")
local murmurs = require("flashback.murmurs")
murmurs.set_material(material)
check(murmurs.random() ~= nil, "random picks from the pool")
check(murmurs.random_trap() ~= nil, "random_trap finds one")
check(murmurs.get_palette().blood == "#ff5555", "palette accessible")

print("highlight")
local highlight = require("flashback.highlight")
local g = highlight.group({ fg = "blood", bg = "ink", attrs = { "bold" } }, murmurs.get_palette())
check(type(g) == "string" and g:sub(1, 9) == "Flashback", "style resolves to a group")
local hl = vim.api.nvim_get_hl(0, { name = g })
check(hl.fg == tonumber("ff5555", 16) or hl.fg == "ff5555" or hl.fg ~= nil, "group has a foreground")
check(highlight.hsl(0, 1, 0.5) == "#ff0000", "hsl 0 -> red")

print("text_model")
local text_model = require("flashback.text_model")
local model = text_model.new("ab\ncd")
model.revealed = 3
model.corrupt[2] = "#"
local resolved = text_model.resolve(model)
check(#resolved.lines == 2, "multi-line resolves to 2 lines")
check(resolved.lines[1] == "a#", "corrupt glyph placed")
check(resolved.pos[2].corrupt == true, "corrupt position flagged")

print("effects")
local effects = require("flashback.effects")
for _, name in ipairs({ "typewriter", "glitch", "decay", "caret", "rainbow", "flicker", "pulse", "shake", "drift",
    "fade", "shadow", "vignette", "cursor_glow", "cursor_harass" }) do
    check(effects.get(name) ~= nil, "effect registered: " .. name)
end

print("renderer / composer")
local renderer = require("flashback.renderer")
local composer = require("flashback.composer")
local pick = material.murmurs[1]
local handle = renderer.render(pick, { renderer = "float", render = configs.defaults.render })
check(handle ~= nil and vim.api.nvim_win_is_valid(handle.win), "float window opens")
local control = composer.start(pick, {
    handle = handle,
    config = merged,
    palette = murmurs.get_palette(),
    glyph_pools = murmurs.get_glyph_pools(),
    on_done = function(h)
        renderer.close(h)
    end,
})
check(type(control.stop) == "function", "composer returns a control")
control.stop()
renderer.close(handle)
check(not vim.api.nvim_win_is_valid(handle.win), "float window closes")
check(renderer.count() == 0, "active renderer list drains")

print("commands")
local flashback = require("flashback")
flashback.create_commands(configs.defaults.cmds)
check(vim.fn.exists(":FlashbackStart") == 2, ":FlashbackStart is defined")
check(vim.fn.exists(":FlashbackTrap") == 2, ":FlashbackTrap is defined")

print("")
if failures > 0 then
    print(string.format("%d test(s) failed", failures))
    os.exit(1)
else
    print("all tests passed")
    os.exit(0)
end
