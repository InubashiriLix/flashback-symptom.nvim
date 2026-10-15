-- jsonls integration tests: non-destructive, idempotent, never enables.
--
--   nvim --headless -l spec/lsp.lua

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

local lsp = require("flashback.lsp")

print("schema location")
check(vim.fn.filereadable(lsp.plugin_schema_path()) == 1, "plugin ships the schema")
local installed = lsp.install()
check(installed ~= nil and vim.fn.filereadable(installed) == 1, "install() writes a data-dir copy")
check(lsp.local_path() == installed, "local_path() prefers the data-dir copy")

print("$schema url")
local url = lsp.schema_url()
if url == nil then
    check(true, "no git remote yet -> schema_url is nil (acceptable before the repo exists)")
else
    check(url:find("githubusercontent%.com") ~= nil, "schema_url is a raw GitHub URL: " .. url)
    check(url:find("murmurs%.schema%.json$") ~= nil, "schema_url points at the schema file")
end

print("injection preserves the user's config")
vim.lsp.config("jsonls", {
    settings = { json = { schemas = { { fileMatch = { "mine.json" }, url = "/tmp/mine.json" } } } },
})
local before = vim.lsp.config["jsonls"]
check(#before.settings.json.schemas == 1, "user's own schema is present before injection")

local changed = lsp.inject()
check(changed == true, "first inject reports a change")

local after = vim.lsp.config["jsonls"]
check(#after.settings.json.schemas == 2, "our schema was appended")
local kept = false
local ours = false
for _, s in ipairs(after.settings.json.schemas) do
    if s.url == "/tmp/mine.json" then
        kept = true
    end
    if type(s.url) == "string" and s.url:find("murmurs%.schema%.json") then
        ours = true
        check(type(s.fileMatch) == "table" and #s.fileMatch > 0, "our entry carries fileMatch")
    end
end
check(kept, "the user's schema survived")
check(ours, "our schema is registered")
check(after.settings.json.validate.enable == true, "validation got enabled")

print("idempotency")
local changed2 = lsp.inject()
check(changed2 == false, "second inject is a no-op")
local again = vim.lsp.config["jsonls"]
check(#again.settings.json.schemas == 2, "no duplicate schema entry")

print("file_match is respected")
lsp.inject({ file_match = { "custom-pattern.jsonc" } })
local custom = vim.lsp.config["jsonls"]
local found = false
for _, s in ipairs(custom.settings.json.schemas) do
    if type(s.fileMatch) == "table" and s.fileMatch[1] == "custom-pattern.jsonc" then
        found = true
    end
end
check(found, "custom fileMatch patterns are honoured")

print("we never enable the server")
local enabled = false
do
    local getter = vim.lsp.get_clients or vim.lsp.get_active_clients
    if getter then
        local ok, clients = pcall(getter)
        for _, c in ipairs(ok and clients or {}) do
            if c.name == "jsonls" then
                enabled = true
            end
        end
    end
end
check(not enabled, "no jsonls client was started by us")

print("snippet")
local snip = lsp.snippet()
check(snip:find("vim%.lsp%.config%('jsonls'") ~= nil, "snippet configures jsonls")
check(snip:find("fileMatch") ~= nil, "snippet contains fileMatch")
check(snip:find("url") ~= nil, "snippet contains a url")

print("opt out")
vim.lsp.config("jsonls", { settings = { json = { schemas = {} } } })
lsp.setup({ enabled = false })
check(#vim.lsp.config["jsonls"].settings.json.schemas == 0, "enabled=false injects nothing")

print("")
if failures > 0 then
    print(string.format("%d test(s) failed", failures))
    os.exit(1)
else
    print("all lsp tests passed")
    os.exit(0)
end
