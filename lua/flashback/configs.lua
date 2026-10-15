---@class FlashbackTimerConfig
---@field timer_num number number of concurrent timers that spawn murmurs
---@field interval_ms number base interval between two murmurs, in milliseconds
---@field jitter number 0..1, random fluctuation ratio applied to interval_ms

---@class FlashbackRenderConfig
---@field mode "float"|"large"|"overlay" default display mode for murmurs
---@field large table defaults for the "large" display mode
---@field overlay table defaults for the "overlay" display mode
---@field position "random"|"corner"|"cursor" where a murmur window pops up
---@field corner string corner name used when position == "corner"
---@field cursor_offset { row: number, col: number } offset used when position == "cursor"
---@field max_windows number maximum number of murmurs on screen at once, 0 = unlimited
---@field allow_overlap boolean whether murmur windows may overlap each other
---@field border string|table window border style
---@field winblend number base window transparency, 0..100

---@class FlashbackEffectsConfig
---@field enabled table<string, boolean> global on/off switch for each effect
---@field default_effects table<string, table> effects used when a murmur has none

---@class FlashbackTrapConfig
---@field enabled boolean master switch for the input hijack
---@field strict boolean require a character-perfect match
---@field escape boolean whether the emergency escape key is available
---@field escape_key string the emergency escape key, informational

---@class FlashbackTriggerConfig
---@field enabled table<string, boolean>
---@field filetypes { include: string[], exclude: string[] }
---@field time { ranges: table[] }
---@field idle { min_ms: number }
---@field modes table<string, boolean>

---@class FlashbackDiagnosticsConfig
---@field enabled boolean
---@field weight number
---@field duration number
---@field severity table<string, boolean>

---@class FlashbackTodoConfig
---@field enabled boolean
---@field weight number
---@field duration number
---@field color string
---@field patterns string[]
---@field max number|nil

---@class FlashbackIntegrationsConfig
---@field diagnostics FlashbackDiagnosticsConfig
---@field todo FlashbackTodoConfig

---@class FlashbackStatsConfig
---@field enabled boolean
---@field path string|nil
---@field achievements boolean

---@class FlashbackFeedbackConfig
---@field bell boolean
---@field notify boolean
---@field notify_level "error"|"warn"|"info"|"debug"
---@field only_trap boolean

---@class FlashbackHijackConfig
---@field enabled boolean swallow input while an overlay murmur is on screen
---@field only_fullscreen boolean restrict the hijack to full-screen overlays

---@class FlashbackLspConfig
---@field enabled boolean inject the schema into jsonls on setup()
---@field inject_jsonls boolean merge a json.schemas entry into jsonls (never enables it)
---@field install_to_datadir boolean copy the schema under stdpath("data") for a stable path
---@field schema_url string|nil override for the $schema URL (default: derived from git remote)
---@field file_match string[] fileMatch patterns that select the schema

---@class FlashbackCmdsConfig
---@field start string
---@field stop string
---@field toggle string
---@field once string
---@field trap string
---@field stats string
---@field schema string

---@class FlashbackConfig
---@field autostart boolean
---@field language "en"|"zh-CN"|"auto" UI language; "auto" reads $LANG
---@field murmurs_path string
---@field fps number frame rate cap for the composer
---@field timer FlashbackTimerConfig
---@field render FlashbackRenderConfig
---@field effects FlashbackEffectsConfig
---@field trap FlashbackTrapConfig
---@field trigger FlashbackTriggerConfig
---@field screen table<string, table>
---@field integrations FlashbackIntegrationsConfig
---@field stats FlashbackStatsConfig
---@field feedback FlashbackFeedbackConfig
---@field hijack FlashbackHijackConfig
---@field lsp FlashbackLspConfig
---@field cmds FlashbackCmdsConfig

local M = {}

---@return string
local function plugin_root()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return vim.fn.fnamemodify(vim.fn.fnamemodify(source, ":p:h"), ":h:h")
end

local DEFAULT_MURMURS = plugin_root() .. "/data/murmurs.jsonc"

---@type FlashbackConfig
M.defaults = {
    autostart = false,
    language = "en",
    murmurs_path = DEFAULT_MURMURS,
    fps = 30,

    timer = {
        timer_num = 3,
        interval_ms = 4000,
        jitter = 0.5,
    },

    render = {
        mode = "float",
        large = {
            cover = 0.6,
            align = "center",
            padding = 2,
            border = "rounded",
            opaque = true,
        },
        overlay = {
            cover = 1.0,
            align = "center",
            padding = 3,
            border = "none",
            opaque = true,
        },
        position = "random",
        corner = "botright",
        cursor_offset = { row = 1, col = 0 },
        max_windows = 4,
        allow_overlap = true,
        border = "rounded",
        winblend = 15,
    },

    effects = {
        enabled = {
            typewriter = true,
            glitch = true,
            decay = true,
            caret = true,
            rainbow = true,
            flicker = true,
            pulse = true,
            shake = true,
            drift = true,
            fade = true,
            shadow = true,
            grow = true,
            shrink = true,
            wipe = true,
            vignette = true,
            cursor_glow = true,
            cursor_harass = true,
            cursor_grab = true,
        },
        default_effects = {
            typewriter = {},
            flicker = {},
        },
    },

    trap = {
        enabled = true,
        strict = true,
        escape = true,
        escape_key = "<Esc><Esc>",
    },

    trigger = {
        enabled = {
            filetype = false,
            time = false,
            idle = false,
            mode = false,
            events = false,
        },
        filetypes = { include = {}, exclude = {} },
        time = { ranges = {} },
        idle = { min_ms = 30000 },
        modes = { insert = true, normal = true, visual = false, replace = true },
    },

    screen = {
        cursor_harass = { enabled = false },
        cursor_grab = { enabled = true },
    },

    integrations = {
        diagnostics = {
            enabled = true,
            weight = 1,
            duration = 3500,
            severity = { ERROR = true, WARN = true, INFO = false, HINT = false },
        },
        todo = {
            enabled = true,
            weight = 1,
            duration = 3500,
            color = "#f1fa8c",
            patterns = { "TODO", "FIXME", "XXX", "HACK" },
            max = nil,
        },
    },

    stats = {
        enabled = true,
        path = nil,
        achievements = true,
    },

    feedback = {
        bell = true,
        notify = false,
        notify_level = "info",
        only_trap = false,
    },

    hijack = {
        enabled = true,
        only_fullscreen = true,
    },

    lsp = {
        enabled = true,
        inject_jsonls = true,
        install_to_datadir = true,
        schema_url = nil,
        file_match = {
            "flashback.json",
            "flashback.jsonc",
            "*murmurs*.json",
            "*murmurs*.jsonc",
            "*/flashback/*.json",
            "*/flashback/*.jsonc",
            ".flashback/*.json",
            ".flashback/*.jsonc",
        },
    },

    cmds = {
        start = "FlashbackStart",
        stop = "FlashbackStop",
        toggle = "FlashbackToggle",
        once = "FlashbackOnce",
        trap = "FlashbackTrap",
        stats = "FlashbackStats",
        schema = "FlashbackSchema",
    },
}

---@type FlashbackConfig|nil
M.value = nil

---@param t any
---@return boolean
local function is_list(t)
    return type(t) == "table" and t[1] ~= nil
end

---@param base table
---@param override table?
---@return table
local function deep_merge(base, override)
    if type(override) ~= "table" then
        return base
    end
    local out = {}
    for k, v in pairs(base) do
        if type(v) == "table" and not is_list(v) then
            out[k] = deep_merge(v, type(override[k]) == "table" and override[k] or {})
        else
            out[k] = v
        end
    end
    for k, v in pairs(override) do
        if type(v) == "table" and type(out[k]) == "table" and not is_list(v) and not is_list(out[k]) then
            out[k] = deep_merge(out[k], v)
        else
            out[k] = v
        end
    end
    return out
end

---@param opts FlashbackConfig?
---@return FlashbackConfig
function M.setup(opts)
    M.value = deep_merge(M.defaults, opts or {})
    -- `default_effects` is a set of effect names, not a map to merge into:
    -- replace it wholesale when the user provides one (so `{}` really clears it).
    if opts and type(opts.effects) == "table" and opts.effects.default_effects ~= nil then
        M.value.effects.default_effects = vim.deepcopy(opts.effects.default_effects)
    end
    return M.value
end

---@return FlashbackConfig
function M.get()
    return M.value or M.defaults
end

return M
