local uv = vim.uv or vim.loop

local configs = require("flashback.configs")
local json_parser = require("flashback.json_parser")
local murmurs = require("flashback.murmurs")
local timer = require("flashback.timer")
local renderer = require("flashback.renderer")
local composer = require("flashback.composer")
local trap = require("flashback.trap")
local screen = require("flashback.screen")
local trigger = require("flashback.trigger")
local stats = require("flashback.stats")
local feedback = require("flashback.feedback")
local highlight = require("flashback.highlight")
local text_model = require("flashback.text_model")
local diagnostics = require("flashback.integrations.diagnostics")
local todo = require("flashback.integrations.todo")
local lsp = require("flashback.lsp")

local M = {}

math.randomseed(os.time() + (tonumber(tostring(uv.hrtime()):sub(-6)) or 0))

local started = false
---@type number|nil
local event_group = nil

---@return FlashbackConfig
local function cfg()
    return configs.get()
end

---@return boolean
function M.reload_murmurs()
    local material, err = json_parser.load(cfg().murmurs_path)
    if not material then
        vim.notify("flashback: " .. tostring(err), vim.log.levels.ERROR)
        return false
    end
    murmurs.set_material(material)
    return true
end

local function ensure_material()
    if #murmurs.get_pool() == 0 then
        M.reload_murmurs()
    end
end

--- Resolve which effects a murmur should actually run.
---@param murmur MurmurItem
---@return table<string, table>
local function resolve_effects(murmur)
    local c = cfg()
    local enabled = c.effects.enabled or {}
    local out = {}

    local has_own = false
    for _ in pairs(murmur.effects or {}) do
        has_own = true
        break
    end

    local source = has_own and murmur.effects or (c.effects.default_effects or {})
    for name, params in pairs(source) do
        if enabled[name] ~= false then
            out[name] = vim.deepcopy(params)
        end
    end

    -- Screen effects have their own master switch.
    if out.cursor_harass and (c.screen and c.screen.cursor_harass and c.screen.cursor_harass.enabled) == false then
        out.cursor_harass = nil
    end

    return out
end

--- Render a murmur with no animation (used for the trap prompt frame).
---@param handle table
---@param murmur MurmurItem
local function render_static(handle, murmur)
    local palette = murmurs.get_palette()
    local resolved = text_model.resolve(text_model.new(murmur.text))
    local group = highlight.group(murmur.style, palette)
    local spans = {}
    for i = 1, #resolved.lines do
        spans[#spans + 1] = { line = i - 1, cstart = 0, cend = -1, group = group }
    end
    handle.apply({
        lines = resolved.lines,
        spans = spans,
        win_group = highlight.win_group(murmur.style, palette),
        blend = handle.base_blend,
        text_key = table.concat(resolved.lines, "\n") .. "|static",
    })
end

---@param opts { murmur?: MurmurItem }|nil
---@return table|nil handle
function M.emit(opts)
    opts = opts or {}
    local c = cfg()

    local allowed, weight = trigger.conditions_ok(c)
    if not allowed then
        return nil
    end
    if c.render.max_windows > 0 and renderer.count() >= c.render.max_windows then
        return nil
    end

    local murmur = opts.murmur
    if not murmur then
        ensure_material()
        local candidates = {}
        for _, m in ipairs(murmurs.get_pool()) do
            if trigger.matches_when(m) then
                candidates[#candidates + 1] = m
            end
        end
        for _, m in ipairs(diagnostics.candidates(c)) do
            candidates[#candidates + 1] = m
        end
        for _, m in ipairs(todo.candidates(c)) do
            candidates[#candidates + 1] = m
        end
        if weight and weight ~= 1 then
            for _, m in ipairs(candidates) do
                m.weight = (tonumber(m.weight) or 1) * weight
            end
        end
        murmur = murmurs.pick(candidates)
    end

    if not murmur then
        return nil
    end

    local handle = renderer.render(murmur, { renderer = "float", render = c.render })
    if not handle then
        return nil
    end

    local run = vim.deepcopy(murmur)
    run.effects = resolve_effects(murmur)

    if run.trap and c.trap.enabled then
        render_static(handle, run)
        trap.engage(run, handle, c.trap)
        stats.bump("traps")
    else
        composer.start(run, {
            handle = handle,
            config = c,
            palette = murmurs.get_palette(),
            glyph_pools = murmurs.get_glyph_pools(),
            on_done = function(h)
                renderer.close(h)
            end,
        })
    end

    stats.bump("emitted")
    feedback.fire(c, run, run.trap and "trap" or "murmur")
    return handle
end

---@return table|nil handle
function M.once()
    return M.emit()
end

---@return table|nil handle
function M.trap_now()
    ensure_material()
    local c = cfg()
    local murmur = murmurs.random_trap() or murmurs.random()
    if not murmur then
        vim.notify("flashback: no murmurs loaded", vim.log.levels.WARN)
        return nil
    end
    return M.emit({ murmur = murmur })
end

local function start_events()
    local c = cfg()
    if not (c.trigger and c.trigger.enabled and c.trigger.enabled.events) then
        return
    end
    if event_group then
        return
    end
    event_group = vim.api.nvim_create_augroup("FlashbackEvents", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWritePost", "DiagnosticChanged" }, {
        group = event_group,
        callback = function()
            M.emit()
        end,
    })
end

local function stop_events()
    if event_group then
        pcall(vim.api.nvim_del_augroup_by_id, event_group)
        event_group = nil
    end
end

function M.start()
    if started then
        return
    end
    ensure_material()
    started = true
    trigger.start_tracking()
    start_events()
    timer.start(cfg().timer, function()
        M.emit()
    end)
end

function M.stop()
    started = false
    timer.stop()
    trap.disengage(false)
    stop_events()
    trigger.stop_tracking()
    screen.teardown()
    renderer.close_all()
    stats.save()
end

function M.toggle()
    if started then
        M.stop()
    else
        M.start()
    end
end

---@return boolean
function M.is_running()
    return started
end

---@return string
function M.stats_summary()
    return stats.summary()
end

---@type string[]
local created_cmds = {}

---@param name string
local function del_if_exists(name)
    if name and name ~= "" and vim.fn.exists(":" .. name) == 2 then
        pcall(vim.api.nvim_del_user_command, name)
    end
end

---@param names FlashbackCmdsConfig
function M.create_commands(names)
    for _, n in ipairs(created_cmds) do
        del_if_exists(n)
    end
    created_cmds = {}

    local defs = {
        { names.start, M.start, "Start the flashback murmurs" },
        { names.stop, M.stop, "Stop the flashback murmurs" },
        { names.toggle, M.toggle, "Toggle the flashback murmurs" },
        { names.once, function()
            M.once()
        end, "Show a single random murmur" },
        { names.trap, function()
            M.trap_now()
        end, "Force a flashback trap" },
        { names.stats, function()
            vim.notify(M.stats_summary(), vim.log.levels.INFO)
        end, "Show flashback statistics" },
        { names.schema, function(arg)
            local info = lsp.info()
            local text = table.concat({
                "flashback murmur schema",
                "  本地文件 : " .. info.local_path,
                "  远程地址 : " .. (info.url or "(未探测到 GitHub remote，可在 setup 里设 lsp.schema_url)"),
                "",
                "把下面这段放进你的 LSP 配置即可获得补全与校验：",
                "",
                info.snippet,
            }, "\n")
            if type(arg) == "string" and arg:lower() == "yank" then
                pcall(vim.fn.setreg, "+", text)
                vim.fn.setreg('"', text)
                vim.notify("flashback: schema 配置已复制到寄存器 +", vim.log.levels.INFO)
            else
                vim.notify(text, vim.log.levels.INFO)
            end
        end, "Show the murmur JSON schema path, URL and a jsonls snippet (:FlashbackSchema yank to copy)",
            { nargs = "?" } },
    }

    for _, d in ipairs(defs) do
        if d[1] and d[1] ~= "" then
            del_if_exists(d[1])
            vim.api.nvim_create_user_command(d[1], function(args)
                d[2](args and args.args or nil)
            end, vim.tbl_extend("force", { desc = d[3] }, d[4] or {}))
            created_cmds[#created_cmds + 1] = d[1]
        end
    end
end

local function schedule_autostart()
    if vim.v.vim_did_enter == 1 then
        vim.schedule(function()
            M.start()
        end)
    else
        vim.api.nvim_create_autocmd("VimEnter", {
            once = true,
            callback = function()
                M.start()
            end,
        })
    end
end

---@param opts FlashbackConfig?
---@return table
function M.setup(opts)
    local c = configs.setup(opts)
    M.create_commands(c.cmds)
    stats.setup(c)
    M.reload_murmurs()
    pcall(lsp.setup, c.lsp)
    if c.autostart then
        schedule_autostart()
    end
    return M
end

return M
