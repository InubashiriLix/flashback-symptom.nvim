-- `:checkhealth flashback`

local i18n = require("flashback.i18n")

local M = {}

---@param path string
---@return boolean
local function dir_writable(path)
    local dir = vim.fn.fnamemodify(path, ":h")
    if vim.fn.isdirectory(dir) == 0 then
        local ok = pcall(vim.fn.mkdir, dir, "p")
        if not ok or vim.fn.isdirectory(dir) == 0 then
            return false
        end
    end
    return vim.fn.filewritable(dir) == 2 or vim.fn.filewritable(dir) == 1
end

function M.check()
    vim.health.start(i18n.t("health_title"))

    if vim.fn.has("nvim-0.11") == 1 then
        vim.health.ok(i18n.t("health_nvim_ok", tostring(vim.version())))
    else
        vim.health.error(i18n.t("health_nvim_bad"))
    end

    local configs = require("flashback.configs")
    local json_parser = require("flashback.json_parser")
    local lsp = require("flashback.lsp")
    local cfg = configs.get()

    -- material
    local material, err = json_parser.load(cfg.murmurs_path)
    if material then
        vim.health.ok(i18n.t("health_material_ok", cfg.murmurs_path, #material.murmurs))
        if #material.murmurs == 0 then
            vim.health.warn("the material contains no murmurs")
        end
    else
        vim.health.error(i18n.t("health_material_bad", tostring(err)), {
            "check `murmurs_path` in your setup()",
        })
    end

    -- schema
    if vim.fn.filereadable(lsp.plugin_schema_path()) == 1 then
        vim.health.ok(i18n.t("health_schema_ok", lsp.local_path()))
    else
        vim.health.error(i18n.t("health_schema_bad"))
    end

    -- jsonls availability
    local jsonls_bins = { "vscode-json-language-server", "json-languageserver" }
    local jsonls_found = false
    for _, bin in ipairs(jsonls_bins) do
        if vim.fn.executable(bin) == 1 then
            jsonls_found = true
            break
        end
    end
    if jsonls_found then
        vim.health.ok(i18n.t("health_jsonls_ok"))
    else
        vim.health.warn(i18n.t("health_jsonls_warn"), {
            "install vscode-json-languageserver or json-languageserver",
        })
    end

    -- injection status
    local injected = 0
    local ok_cfg, jsonls_cfg = pcall(function()
        return vim.lsp.config["jsonls"]
    end)
    if ok_cfg and type(jsonls_cfg) == "table" and jsonls_cfg.settings then
        local schemas = (jsonls_cfg.settings.json or {}).schemas
        for _, s in ipairs(schemas or {}) do
            if type(s) == "table" and type(s.url) == "string" and s.url:find("murmurs%.schema%.json") then
                injected = injected + 1
            end
        end
    end
    if injected > 0 then
        vim.health.ok(i18n.t("health_schema_injected", injected))
    else
        vim.health.warn(i18n.t("health_schema_not_injected"), {
            "run require('flashback.lsp').inject() or see :FlashbackSchema",
        })
    end

    -- stats
    local stats_path = cfg.stats.path or (vim.fn.stdpath("data") .. "/flashback/stats.json")
    if dir_writable(stats_path) then
        vim.health.ok(i18n.t("health_stats_ok", stats_path))
    else
        vim.health.warn(i18n.t("health_stats_bad", stats_path))
    end
end

return M
