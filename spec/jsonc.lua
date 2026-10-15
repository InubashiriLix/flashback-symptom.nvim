-- JSONC pre-processor tests.
--
--   nvim --headless -l spec/jsonc.lua

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

print("comments")
check(jsonc.strip('{"a":1}') == '{"a":1}', "plain json untouched")
check(jsonc.strip('{"a":1} // hi') == '{"a":1} ', "line comment removed")
check(jsonc.strip('{\n// hi\n"a":1\n}') == '{\n\n"a":1\n}', "line comment with newline kept")
check(jsonc.strip('{"a":1 /* x */, "b":2}') == '{"a":1 , "b":2}', "block comment removed")
check(jsonc.strip('/* leading */{"a":1}') == '{"a":1}', "leading block comment removed")
check(jsonc.strip('{"a":1} /* unterminated') == '{"a":1} ', "unterminated block comment is dropped")

print("strings are sacred")
local url = '{"url":"https://example.com//a"}'
check(jsonc.strip(url) == url, "// inside a string is preserved")
local text = '{"t":"/* not a comment */"}'
check(jsonc.strip(text) == text, "block comment markers inside a string are preserved")
local comma = '{"t":"a,}b"}'
check(jsonc.strip(comma) == comma, "trailing-comma-looking text inside a string is preserved")
local esc = '{"t":"he said \\"// nope\\""}'
check(jsonc.strip(esc) == esc, "escaped quotes inside a string are handled")

print("trailing commas")
check(jsonc.strip('{"a":1,}') == '{"a":1}', "object trailing comma removed")
check(jsonc.strip('[1,2,]') == '[1,2]', "array trailing comma removed")
check(jsonc.strip('{"a":[1,2,],}') == '{"a":[1,2]}', "nested trailing commas removed")
check(jsonc.strip('{"a":1, // c\n}') == '{"a":1 \n}', "comma followed by a comment then a brace is dropped")
check(jsonc.strip('[1, /* c */ ]') == '[1  ]', "comma then block comment then a bracket is dropped")

print("end to end")
local path = root .. "/data/murmurs.jsonc"
local fd = io.open(path, "r")
check(fd ~= nil, "material file exists: data/murmurs.jsonc")
if fd then
    local body = fd:read("*a")
    fd:close()
    local ok, decoded = pcall(vim.json.decode, jsonc.strip(body))
    check(ok, "shipped material decodes after stripping (" .. tostring(decoded):sub(1, 60) .. ")")
    if ok then
        check(type(decoded.murmurs) == "table" and #decoded.murmurs > 0, "material has murmurs")
    end
end

print("")
if failures > 0 then
    print(string.format("%d test(s) failed", failures))
    os.exit(1)
else
    print("all jsonc tests passed")
    os.exit(0)
end
