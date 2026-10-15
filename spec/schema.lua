-- Schema / registry drift guard.
--
-- The schema is a hand-written contract; this test makes sure it stays in sync
-- with the effect registry and with the shipped material.
--
--   nvim --headless -l spec/schema.lua

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

local jsonc = require("flashback.jsonc")
local effects = require("flashback.effects")

local function read(path)
    local fd = io.open(path, "r")
    if not fd then
        return nil
    end
    local body = fd:read("*a")
    fd:close()
    return body
end

print("schema file")
local schema_body = read(root .. "/schema/murmurs.schema.json")
check(schema_body ~= nil, "schema/murmurs.schema.json exists")
local ok, schema = pcall(vim.json.decode, schema_body or "")
check(ok, "schema is valid JSON (" .. tostring(schema):sub(1, 80) .. ")")
if not ok then
    os.exit(1)
end

check(type(schema["$id"]) == "string" and schema["$id"]:find("githubusercontent"), "$id points at raw GitHub")
check(schema.title and schema.title:find("flashback"), "schema has a title")
check(type(schema.definitions) == "table", "schema has definitions")

print("registry sync")
local effect_props = schema.definitions.effects and schema.definitions.effects.properties
check(type(effect_props) == "table", "schema defines effects.properties")
local registered = effects.names()
check(#registered >= 14, "registry has all built-in effects (" .. #registered .. ")")
for _, name in ipairs(registered) do
    check(effect_props[name] ~= nil, "schema documents effect: " .. name)
end

print("material keys")
local material_body = read(root .. "/data/murmurs.jsonc")
check(material_body ~= nil, "data/murmurs.jsonc exists")
local decoded = vim.json.decode(jsonc.strip(material_body))
check(decoded["$schema"] ~= nil, "shipped material declares $schema")
check(tostring(decoded["$schema"]):find("flashback%-symptom%.nvim") ~= nil, "$schema points at this repo")

local murmur_props = schema.definitions.murmur.properties
local style_props = schema.definitions.style.properties
local unknown = {}
for i, m in ipairs(decoded.murmurs or {}) do
    for k in pairs(m) do
        if murmur_props[k] == nil then
            unknown[#unknown + 1] = ("murmur #%d key '%s'"):format(i, k)
        end
    end
    for ename in pairs(m.effects or {}) do
        if effect_props[ename] == nil then
            unknown[#unknown + 1] = ("murmur #%d effect '%s'"):format(i, ename)
        end
    end
end
check(#unknown == 0, "every shipped murmur key is documented (" .. table.concat(unknown, ", ") .. ")")

-- The showcase example must exercise every built-in effect and stay schema-clean.
print("showcase example")
local showcase_body = read(root .. "/examples/showcase.jsonc")
check(showcase_body ~= nil, "examples/showcase.jsonc exists")
if showcase_body then
    local sok, showcase = pcall(vim.json.decode, jsonc.strip(showcase_body))
    check(sok, "showcase decodes: " .. tostring(showcase):sub(1, 80))
    if sok then
        local seen = {}
        local bad = {}
        for i, m in ipairs(showcase.murmurs or {}) do
            for k in pairs(m) do
                if murmur_props[k] == nil then
                    bad[#bad + 1] = ("showcase #%d key '%s'"):format(i, k)
                end
            end
            for ename in pairs(m.effects or {}) do
                seen[ename] = true
                if effect_props[ename] == nil then
                    bad[#bad + 1] = ("showcase #%d effect '%s'"):format(i, ename)
                end
            end
            for k in pairs(m.style or {}) do
                if style_props[k] == nil then
                    bad[#bad + 1] = ("showcase #%d style.%s"):format(i, k)
                end
            end
        end
        for name, preset in pairs(showcase.presets or {}) do
            for k in pairs(preset.style or {}) do
                if style_props[k] == nil then
                    bad[#bad + 1] = ("showcase preset %s style.%s"):format(name, k)
                end
            end
            for ename in pairs(preset.effects or {}) do
                if effect_props[ename] == nil then
                    bad[#bad + 1] = ("showcase preset %s effect '%s'"):format(name, ename)
                end
            end
        end
        check(#bad == 0, "showcase keys all documented (" .. table.concat(bad, ", ") .. ")")
        for _, name in ipairs(registered) do
            check(seen[name] == true, "showcase demonstrates effect: " .. name)
        end
    end
end

local bad_style = {}
for i, m in ipairs(decoded.murmurs or {}) do
    for k in pairs(m.style or {}) do
        if style_props[k] == nil then
            bad_style[#bad_style + 1] = ("murmur #%d style.%s"):format(i, k)
        end
    end
end
for name, preset in pairs(decoded.presets or {}) do
    for k in pairs(preset.style or {}) do
        if style_props[k] == nil then
            bad_style[#bad_style + 1] = ("preset %s style.%s"):format(name, k)
        end
    end
end
check(#bad_style == 0, "every style key is documented (" .. table.concat(bad_style, ", ") .. ")")

print("")
if failures > 0 then
    print(string.format("%d test(s) failed", failures))
    os.exit(1)
else
    print("all schema tests passed")
    os.exit(0)
end
