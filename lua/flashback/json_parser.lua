local murmur_item = require("flashback.murmurs")
local jsonc = require("flashback.jsonc")
local i18n = require("flashback.i18n")

local M = {}

---@param v any
---@return boolean
local function is_nil(v)
    return v == nil or v == vim.NIL
end

---@param path string
---@return string|nil, string|nil
local function read_file(path)
    local fd, err = io.open(path, "r")
    if not fd then
        return nil, err
    end
    local content = fd:read("*a")
    fd:close()
    return content
end

--- Normalise an `effects` value (array of names OR named table) into a table of
--- effect name -> params.
---@param value any
---@return table<string, table>
local function normalize_effects(value)
    local out = {}
    if is_nil(value) or type(value) ~= "table" then
        return out
    end
    if value[1] ~= nil then
        -- Legacy array form: ["glitch", "flicker"]
        for _, name in ipairs(value) do
            if type(name) == "string" then
                out[name] = {}
            end
        end
    else
        for name, params in pairs(value) do
            if is_nil(params) or params == true then
                out[name] = {}
            elseif type(params) == "table" then
                out[name] = vim.deepcopy(params)
            elseif params == false then
                -- explicitly disabled: skip
            else
                out[name] = {}
            end
        end
    end
    return out
end

---@param a table<string, table>
---@param b table<string, table>
---@return table<string, table>
local function merge_effects(a, b)
    local out = vim.deepcopy(a or {})
    for name, params in pairs(b or {}) do
        if out[name] then
            for k, v in pairs(params) do
                out[name][k] = v
            end
        else
            out[name] = vim.deepcopy(params)
        end
    end
    return out
end

--- Load a v2 murmur material file.
---@param path string
---@return table|nil material, string|nil err
function M.load(path)
    if type(path) ~= "string" or path == "" then
        return nil, i18n.t("err_no_path")
    end

    local content, err = read_file(path)
    if not content then
        return nil, i18n.t("err_read_failed", path, tostring(err))
    end

    local ok, decoded = pcall(vim.json.decode, jsonc.strip(content))
    if not ok then
        return nil, i18n.t("err_invalid_json", path, tostring(decoded))
    end
    if type(decoded) ~= "table" then
        return nil, i18n.t("err_not_object", path)
    end

    local palette = is_nil(decoded.palette) and {} or decoded.palette
    local glyph_pools = is_nil(decoded.glyph_pools) and {} or decoded.glyph_pools
    local presets = is_nil(decoded.presets) and {} or decoded.presets
    local raw = decoded.murmurs

    if type(raw) ~= "table" then
        return nil, i18n.t("err_missing_array", path)
    end

    local list = {}
    for i, item in ipairs(raw) do
        if type(item) ~= "table" or type(item.text) ~= "string" then
            vim.notify(i18n.t("warn_skip_invalid", i), vim.log.levels.WARN)
        else
            local style = {}
            local eff = {}

            if type(item.preset) == "string" and presets[item.preset] then
                local preset = presets[item.preset]
                style = vim.deepcopy(preset.style or {})
                eff = normalize_effects(preset.effects)
            end

            if type(item.style) == "table" and not is_nil(item.style) then
                for k, v in pairs(item.style) do
                    style[k] = v
                end
            end
            -- Legacy single-colour form.
            if type(item.color) == "string" and style.fg == nil then
                style.fg = item.color
            end

            eff = merge_effects(eff, normalize_effects(item.effects))

            local m = murmur_item.new(item.text, style, tonumber(item.duration) or 3000)
            m.effects = eff
            m.weight = tonumber(item.weight) or 1
            m.trap = item.trap == true
            m.unlock_text = type(item.unlock_text) == "string" and item.unlock_text or item.text
            m.when = (type(item.when) == "table" and not is_nil(item.when)) and item.when or nil
            m.source = "material"
            list[#list + 1] = m
        end
    end

    return {
        murmurs = list,
        palette = palette,
        glyph_pools = glyph_pools,
        presets = presets,
    }
end

return M
