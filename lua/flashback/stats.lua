-- Session / lifetime statistics and tiny achievements, persisted to disk.

local uv = vim.uv or vim.loop

local i18n = require("flashback.i18n")

local M = {}

M.enabled = true

---@type table|nil
local data = nil
---@type string|nil
local path = nil

local EMPTY = {
    emitted = 0,
    traps = 0,
    escapes = 0,
    trap_ms = 0,
    by_day = {},
    achievements = {},
}

local ACHIEVEMENTS = {
    { key = "first_flashback", label = "achievement_first_flashback", check = function(d)
        return d.emitted >= 1
    end },
    { key = "ten_flashbacks", label = "achievement_ten_flashbacks", check = function(d)
        return d.emitted >= 10
    end },
    { key = "hundred_flashbacks", label = "achievement_hundred_flashbacks", check = function(d)
        return d.emitted >= 100
    end },
    { key = "first_trap", label = "achievement_first_trap", check = function(d)
        return d.traps >= 1
    end },
    { key = "escape_artist", label = "achievement_escape_artist", check = function(d)
        return d.escapes >= 1
    end },
    { key = "captive", label = "achievement_captive", check = function(d)
        return d.trap_ms >= 60000
    end },
}

local function deep_copy(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = type(v) == "table" and deep_copy(v) or v
    end
    return out
end

---@return table
local function load()
    if not path then
        return deep_copy(EMPTY)
    end
    local fd = io.open(path, "r")
    if not fd then
        return deep_copy(EMPTY)
    end
    local content = fd:read("*a")
    fd:close()
    local ok, decoded = pcall(vim.json.decode, content)
    if not ok or type(decoded) ~= "table" then
        return deep_copy(EMPTY)
    end
    local out = deep_copy(EMPTY)
    for k, v in pairs(decoded) do
        out[k] = v
    end
    return out
end

---@param cfg FlashbackConfig
function M.setup(cfg)
    local sc = cfg.stats or {}
    M.enabled = sc.enabled ~= false
    path = sc.path or (vim.fn.stdpath("data") .. "/flashback/stats.json")
    data = load()
end

function M.save()
    if not M.enabled or not data or not path then
        return
    end
    pcall(vim.fn.mkdir, vim.fn.fnamemodify(path, ":h"), "p")
    local ok, encoded = pcall(vim.json.encode, data)
    if not ok then
        return
    end
    local fd = io.open(path, "w")
    if fd then
        fd:write(encoded)
        fd:close()
    end
end

---@param key string
---@param n number|nil
function M.bump(key, n)
    if not M.enabled or not data then
        return
    end
    data[key] = (data[key] or 0) + (n or 1)
    local day = os.date("%Y-%m-%d")
    if key == "emitted" then
        data.by_day[day] = (data.by_day[day] or 0) + (n or 1)
    end
    M._check_achievements()
end

function M._check_achievements()
    if not data then
        return
    end
    for _, a in ipairs(ACHIEVEMENTS) do
        if not data.achievements[a.key] and a.check(data) then
            data.achievements[a.key] = os.time()
            vim.schedule(function()
                vim.notify(i18n.t("achievement_unlocked", i18n.t(a.label)), vim.log.levels.INFO)
            end)
        end
    end
end

---@return table
function M.get()
    return data or deep_copy(EMPTY)
end

---@return string
function M.summary()
    local d = M.get()
    local function row(label_key, value)
        return "  " .. i18n.t(label_key) .. " : " .. value
    end
    local lines = {
        i18n.t("stats_title"),
        row("stats_emitted", tostring(d.emitted or 0)),
        row("stats_traps", tostring(d.traps or 0)),
        row("stats_trap_ms", string.format("%.1fs", (d.trap_ms or 0) / 1000)),
        row("stats_escapes", tostring(d.escapes or 0)),
        row("stats_path", tostring(path)),
    }
    local unlocked = {}
    for _, a in ipairs(ACHIEVEMENTS) do
        if d.achievements and d.achievements[a.key] then
            unlocked[#unlocked + 1] = i18n.t(a.label)
        end
    end
    lines[#lines + 1] = row("stats_achievements", #unlocked > 0 and table.concat(unlocked, ", ") or i18n.t("stats_none"))
    return table.concat(lines, "\n")
end

---@return string[]
function M.achievement_list()
    local out = {}
    for _, a in ipairs(ACHIEVEMENTS) do
        out[#out + 1] = i18n.t(a.label)
    end
    return out
end

return M
