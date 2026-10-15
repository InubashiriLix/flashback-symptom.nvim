-- User-facing strings.
--
-- The API mirrors the convention used by the author's other plugins:
--   i18n.t("some_key")
--   i18n.t("with_args", a, b)   -- string.format
--
-- `config.language` is "en" (default), "zh-CN", or "auto" (detect from $LANG).

local M = {}

---@type table<string, table<string, string>>
local messages = {
    en = {
        -- trap
        trap_hint = "Type the following to break free:",
        trap_progress = "[ %d / %d ]",
        trap_notify = "You have been hijacked",

        -- stats
        stats_title = "flashback statistics",
        stats_emitted = "murmurs shown",
        stats_traps = "traps",
        stats_trap_ms = "time held captive",
        stats_escapes = "escapes",
        stats_path = "stats file",
        stats_achievements = "achievements unlocked",
        stats_none = "(none)",

        achievement_first_flashback = "First flashback",
        achievement_ten_flashbacks = "Ten flashbacks",
        achievement_hundred_flashbacks = "A hundred flashbacks",
        achievement_first_trap = "First trap",
        achievement_escape_artist = "Escape artist",
        achievement_captive = "Captive for a minute",
        achievement_unlocked = "flashback: achievement unlocked - %s",

        -- feedback
        feedback_murmur = "flashback: %s",

        -- material loading
        err_no_material = "no murmurs loaded",
        err_no_path = "no murmurs_path configured",
        err_read_failed = "cannot read %s: %s",
        err_not_object = "%s must contain a JSON object",
        err_invalid_json = "invalid JSON/JSONC in %s: %s",
        err_missing_array = "%s must contain a 'murmurs' array",
        warn_skip_invalid = "flashback: skipping invalid murmur #%d",
        warn_bad_effects = "flashback: '%s'.effects must be a list",

        -- commands
        cmd_start = "Start the flashback murmurs",
        cmd_stop = "Stop the flashback murmurs",
        cmd_toggle = "Toggle the flashback murmurs",
        cmd_once = "Show a single random murmur",
        cmd_trap = "Force a flashback trap",
        cmd_stats = "Show flashback statistics",
        cmd_schema = "Show the murmur JSON schema path, URL and a jsonls snippet (:FlashbackSchema yank to copy)",

        -- :FlashbackSchema
        schema_title = "flashback murmur schema",
        schema_local = "local file",
        schema_remote = "remote URL",
        schema_remote_unknown = "(no GitHub remote detected; set lsp.schema_url in setup)",
        schema_paste = "Drop this into your LSP config for completion and validation:",
        schema_copied = "flashback: schema config copied to register +",

        -- health
        health_title = "flashback-symptom.nvim",
        health_nvim_ok = "Neovim %s (0.11+ required)",
        health_nvim_bad = "Neovim 0.11 or newer is required",
        health_material_ok = "material is readable and parses: %s (%d murmurs)",
        health_material_bad = "material failed to load: %s",
        health_schema_ok = "JSON schema present: %s",
        health_schema_bad = "schema file is missing",
        health_jsonls_ok = "jsonls detected",
        health_jsonls_warn = "jsonls not detected; completion is unavailable but the plugin still works",
        health_schema_injected = "schema injected into jsonls (%d fileMatch patterns)",
        health_schema_not_injected = "schema was not injected into jsonls",
        health_stats_ok = "stats directory is writable: %s",
        health_stats_bad = "stats directory is not writable: %s",
    },

    ["zh-CN"] = {
        -- trap
        trap_hint = "键入以下内容以解脱：",
        trap_progress = "[ %d / %d ]",
        trap_notify = "你被劫持了",

        -- stats
        stats_title = "flashback 统计",
        stats_emitted = "闪回次数",
        stats_traps = "被劫持次数",
        stats_trap_ms = "劫持总时长",
        stats_escapes = "成功逃脱",
        stats_path = "持久化文件",
        stats_achievements = "已解锁成就",
        stats_none = "（无）",

        achievement_first_flashback = "第一次闪回",
        achievement_ten_flashbacks = "闪回十次",
        achievement_hundred_flashbacks = "百次闪回",
        achievement_first_trap = "第一次被劫持",
        achievement_escape_artist = "成功逃脱劫持",
        achievement_captive = "累计被劫持一分钟",
        achievement_unlocked = "flashback: 成就解锁 —— %s",

        -- feedback
        feedback_murmur = "flashback: %s",

        -- material loading
        err_no_material = "没有加载到 murmur 素材",
        err_no_path = "没有配置 murmurs_path",
        err_read_failed = "无法读取 %s：%s",
        err_not_object = "%s 必须是一个 JSON 对象",
        err_invalid_json = "%s 里的 JSON/JSONC 不合法：%s",
        err_missing_array = "%s 必须包含一个 'murmurs' 数组",
        warn_skip_invalid = "flashback: 跳过第 %d 条无效 murmur",
        warn_bad_effects = "flashback: '%s'.effects 必须是列表",

        -- commands
        cmd_start = "开始闪回",
        cmd_stop = "停止闪回并清空所有浮窗",
        cmd_toggle = "开关闪回",
        cmd_once = "立刻随机闪一次",
        cmd_trap = "强制触发一次输入劫持",
        cmd_stats = "查看闪回统计与成就",
        cmd_schema = "显示 murmur JSON schema 的路径、URL 与 jsonls 配置（:FlashbackSchema yank 复制）",

        -- :FlashbackSchema
        schema_title = "flashback murmur schema",
        schema_local = "本地文件",
        schema_remote = "远程地址",
        schema_remote_unknown = "（未探测到 GitHub remote，可在 setup 里设 lsp.schema_url）",
        schema_paste = "把下面这段放进你的 LSP 配置即可获得补全与校验：",
        schema_copied = "flashback: schema 配置已复制到寄存器 +",

        -- health
        health_title = "flashback-symptom.nvim",
        health_nvim_ok = "Neovim %s（需要 0.11+）",
        health_nvim_bad = "需要 Neovim 0.11 或更新版本",
        health_material_ok = "素材可读且可解析：%s（%d 条）",
        health_material_bad = "素材读取失败：%s",
        health_schema_ok = "JSON Schema 存在：%s",
        health_schema_bad = "缺少 schema 文件",
        health_jsonls_ok = "已检测到 jsonls",
        health_jsonls_warn = "未检测到 jsonls（补全不可用，但插件仍可正常工作）",
        health_schema_injected = "已向 jsonls 注入 schema（%d 条 fileMatch）",
        health_schema_not_injected = "未向 jsonls 注入 schema",
        health_stats_ok = "统计目录可写：%s",
        health_stats_bad = "统计目录不可写：%s",
    },
}

--- Detect a supported language from the environment.
---@return string
function M.detect()
    local env = (vim.env.LC_ALL or vim.env.LC_MESSAGES or vim.env.LANG or ""):lower()
    if env:find("zh") then
        return "zh-CN"
    end
    return "en"
end

---@return string
function M.lang()
    local ok, configs = pcall(require, "flashback.configs")
    local language = ok and configs.get().language or "en"
    if language == "auto" or language == nil or language == "" then
        return M.detect()
    end
    if messages[language] then
        return language
    end
    return "en"
end

--- Translate a key. Extra arguments are passed to string.format.
---@param key string
---@param ... any
---@return string
function M.t(key, ...)
    local lang = M.lang()
    local value = (messages[lang] or messages.en)[key] or messages.en[key] or key
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end

---@return string[]
function M.languages()
    local out = {}
    for k in pairs(messages) do
        out[#out + 1] = k
    end
    table.sort(out)
    return out
end

return M
