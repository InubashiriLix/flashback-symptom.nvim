-- jsonls (JSON Language Server) integration.
--
-- Two independent routes get the schema onto the user's material file:
--   1. injection  -- merge a `json.schemas` entry into the user's jsonls config
--                    using fileMatch patterns. Offline, works everywhere.
--   2. `$schema`  -- a URL the user can put inside the file, useful when the
--                    material travels outside this machine.
--
-- Injection is deliberately non-destructive: the user's existing schemas are
-- read back and preserved, and we never touch `vim.lsp.enable`.

local M = {}

local DEFAULT_FILE_MATCH = {
    "flashback.json",
    "flashback.jsonc",
    "*murmurs*.json",
    "*murmurs*.jsonc",
    "*/flashback/*.json",
    "*/flashback/*.jsonc",
    ".flashback/*.json",
    ".flashback/*.jsonc",
}

local SCHEMA_REL = "schema/murmurs.schema.json"

---@type string|nil
local cached_url = nil
---@type boolean
local url_resolved = false

---@return string
local function plugin_root()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return vim.fn.fnamemodify(vim.fn.fnamemodify(source, ":p:h"), ":h:h")
end

---@return string
function M.default_file_match()
    local out = {}
    for i, v in ipairs(DEFAULT_FILE_MATCH) do
        out[i] = v
    end
    return out
end

--- The schema shipped inside the plugin.
---@return string
function M.plugin_schema_path()
    return plugin_root() .. "/" .. SCHEMA_REL
end

--- A copy under stdpath("data") with a stable path.
---@return string
function M.datadir_schema_path()
    return vim.fn.stdpath("data") .. "/flashback/murmurs.schema.json"
end

--- Copy the schema into the data dir (idempotent; only writes when changed).
---@return string|nil
function M.install()
    local src = M.plugin_schema_path()
    local dst = M.datadir_schema_path()
    local content = io.open(src, "r")
    if not content then
        return nil
    end
    local body = content:read("*a")
    content:close()

    local existing = io.open(dst, "r")
    if existing then
        local old = existing:read("*a")
        existing:close()
        if old == body then
            return dst
        end
    end

    pcall(vim.fn.mkdir, vim.fn.fnamemodify(dst, ":h"), "p")
    local out = io.open(dst, "w")
    if not out then
        return nil
    end
    out:write(body)
    out:close()
    return dst
end

--- Prefer the stable data-dir copy, fall back to the plugin copy.
---@return string
function M.local_path()
    local dst = M.datadir_schema_path()
    if vim.fn.filereadable(dst) == 1 then
        return dst
    end
    return M.plugin_schema_path()
end

--- Raw GitHub URL for the schema, derived from the origin remote when unset.
---@return string|nil
function M.schema_url()
    if url_resolved then
        return cached_url
    end
    url_resolved = true

    local override = vim.g.flashback_schema_url
    if type(override) == "string" and override ~= "" then
        cached_url = override
        return cached_url
    end

    local ok, out = pcall(vim.fn.system, { "git", "-C", plugin_root(), "remote", "get-url", "origin" })
    if not ok or vim.v.shell_error ~= 0 or type(out) ~= "string" then
        return nil
    end
    out = vim.trim(out)
    local owner, repo = out:match("github%.com[:/]([^/]+)/([^/]+)%.git$")
    if not owner then
        owner, repo = out:match("github%.com[:/]([^/]+)/([^/]+)/?$")
    end
    if not owner or not repo then
        return nil
    end
    cached_url = ("https://raw.githubusercontent.com/%s/%s/HEAD/schema/murmurs.schema.json"):format(owner, repo)
    return cached_url
end

---@param list string[]
---@return string
local function format_list(list)
    local parts = {}
    for _, v in ipairs(list) do
        parts[#parts + 1] = ("%q"):format(v)
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

--- A ready-to-paste jsonls config block.
---@param file_match string[]|nil
---@return string
function M.snippet(file_match)
    local url = vim.uri_from_fname(M.local_path())
    return table.concat({
        "vim.lsp.config('jsonls', {",
        "  settings = {",
        "    json = {",
        "      validate = { enable = true },",
        "      schemas = {",
        ("        { fileMatch = %s, url = %q },"):format(format_list(file_match or M.default_file_match()), url),
        "      },",
        "    },",
        "  },",
        "})",
    }, "\n")
end

--- Read the user's current jsonls config, wherever it lives.
---@return table
local function current_jsonls_config()
    local ok, cfg = pcall(function()
        return vim.lsp.config["jsonls"]
    end)
    if ok and type(cfg) == "table" then
        return cfg
    end
    return {}
end

--- Merge (idempotently) our schema entry into the user's jsonls config.
---@param opts { file_match?: string[] }|nil
---@return boolean changed
function M.inject(opts)
    opts = opts or {}
    local file_match = opts.file_match or M.default_file_match()
    local url = vim.uri_from_fname(M.local_path())

    local current = current_jsonls_config()
    local settings = vim.deepcopy(current.settings or {})
    settings.json = settings.json or {}

    local schemas = type(settings.json.schemas) == "table" and settings.json.schemas or {}

    local changed = false
    local matched = false
    for i, s in ipairs(schemas) do
        if type(s) == "table" and s.fileMatch and vim.deep_equal(s.fileMatch, file_match) then
            matched = true
            if s.url ~= url then
                schemas[i] = { fileMatch = file_match, url = url }
                changed = true
            end
            break
        end
    end
    if not matched then
        schemas[#schemas + 1] = { fileMatch = file_match, url = url }
        changed = true
    end

    if settings.json.validate == nil then
        settings.json.validate = { enable = true }
        changed = true
    end

    if not changed then
        return false
    end

    settings.json.schemas = schemas
    current.settings = settings
    pcall(vim.lsp.config, "jsonls", current)
    return true
end

---@param opts table|nil
function M.setup(opts)
    opts = opts or {}
    if opts.enabled == false then
        return
    end
    if opts.install_to_datadir ~= false then
        pcall(M.install)
    end
    if opts.inject_jsonls == false then
        return
    end
    pcall(M.inject, { file_match = opts.file_match })
end

--- Everything the :FlashbackSchema command needs.
---@return table
function M.info()
    return {
        local_path = M.local_path(),
        plugin_path = M.plugin_schema_path(),
        url = M.schema_url(),
        snippet = M.snippet(),
    }
end

return M
