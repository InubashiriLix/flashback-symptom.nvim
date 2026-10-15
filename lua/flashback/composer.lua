-- The frame composer. It drives every effect on a fixed frame clock, lets them
-- all write into one shared frame, resolves the text model once, and applies the
-- result to the renderer handle in a single shot.
--
-- Because effects only ever write into `frame` / `ctx.text`, arbitrary combos
-- (typewriter + glitch + shake + shadow + rainbow + ...) compose cleanly.

local uv = vim.uv or vim.loop

local text_model = require("flashback.text_model")
local effects = require("flashback.effects")
local highlight = require("flashback.highlight")
local screen = require("flashback.screen")

local M = {}

---@param ctx table
---@param resolved table
---@param frame table
---@return table[]
local function build_spans(ctx, resolved, frame)
    local spans = {}

    if frame.default_group then
        for i = 1, #resolved.lines do
            spans[#spans + 1] = { line = i - 1, cstart = 0, cend = -1, group = frame.default_group }
        end
    end

    if frame.char_style then
        for i, p in pairs(resolved.pos) do
            if p.revealed then
                local st = frame.char_style(i, ctx.text.total)
                if st then
                    spans[#spans + 1] = { line = p.line - 1, cstart = p.cstart, cend = p.cend,
                        group = highlight.group(st, ctx.palette) }
                end
            end
        end
    end

    if ctx.text.corrupt_style then
        local g = highlight.group(ctx.text.corrupt_style, ctx.palette)
        for _, p in pairs(resolved.pos) do
            if p.corrupt then
                spans[#spans + 1] = { line = p.line - 1, cstart = p.cstart, cend = p.cend, group = g }
            end
        end
    end

    if resolved.caret then
        local g = highlight.group(ctx.text.caret_style or frame.style, ctx.palette)
        spans[#spans + 1] = {
            line = resolved.caret.line - 1,
            cstart = resolved.caret.cstart,
            cend = resolved.caret.cend,
            group = g,
        }
    end

    return spans
end

--- Start composing a murmur onto a renderer handle.
---@param murmur MurmurItem
---@param opts { handle: table, config: FlashbackConfig, palette: table|nil, glyph_pools: table|nil, on_done: fun(handle: table)|nil }
---@return table control
function M.start(murmur, opts)
    local handle = opts.handle
    local cfg = opts.config or {}
    local palette = opts.palette
    local glyph_pools = opts.glyph_pools
    local duration = math.max(1, murmur.duration or 3000)

    local schedule = {}
    for name, params in pairs(murmur.effects or {}) do
        local def = effects.get(name)
        if def then
            local p = effects.resolve_params(def, params)
            schedule[#schedule + 1] = {
                name = name,
                def = def,
                params = p,
                delay = math.max(0, tonumber(params.delay) or 0),
                duration = tonumber(params.duration),
                priority = tonumber(params.priority) or def.priority or 0,
            }
        end
    end
    table.sort(schedule, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.delay < b.delay
    end)

    local scratch = {}
    local ctx = {
        handle = handle,
        murmur = murmur,
        palette = palette,
        glyph_pools = glyph_pools,
        config = cfg,
        display = opts.display or {},
        text = text_model.new(murmur.text),
        scratch = scratch,
    }

    local base_style = murmur.style or {}

    ---@param item table
    ---@return table
    local function effect_ctx(item)
        local s = scratch[item.name]
        if not s then
            s = {}
            scratch[item.name] = s
        end
        local eend = item.delay + (item.duration or math.max(0, duration - item.delay))
        return setmetatable({
            params = item.params,
            duration = math.max(1, eend - item.delay),
            scratch = s,
        }, { __index = ctx })
    end

    local start_ns = uv.hrtime()
    local stopped = false
    local timer = nil

    ---@return number
    local function elapsed()
        return (uv.hrtime() - start_ns) / 1e6
    end

    ---@return table
    local function new_frame()
        return {
            style = {
                fg = base_style.fg,
                bg = base_style.bg,
                attrs = base_style.attrs and vim.deepcopy(base_style.attrs) or nil,
                sp = base_style.sp,
            },
            base_blend = handle.base_blend or 0,
            blend = handle.base_blend or 0,
            row_offset = 0,
            col_offset = 0,
            -- set by size effects (grow / shrink / wipe)
            cover = nil,
            anchor = nil,
            screen = {},
            lines = {},
            spans = {},
        }
    end

    ---@param final boolean
    local function render(final)
        local now = elapsed()
        local frame = new_frame()

        for _, item in ipairs(schedule) do
            local eend = item.delay + (item.duration or math.max(0, duration - item.delay))
            local ectx = effect_ctx(item)
            if not final and now >= item.delay and now < eend then
                if not item.entered then
                    item.entered = true
                    pcall(item.def.enter, ectx)
                end
                pcall(item.def.tick, frame, ectx, now - item.delay)
            elseif item.entered and (final or now >= eend) then
                item.entered = false
                pcall(item.def.exit, ectx)
            end
        end

        local resolved = text_model.resolve(ctx.text)
        frame.default_group = highlight.group(frame.style, palette)
        frame.win_group = highlight.win_group(frame.style, palette)
        frame.lines = resolved.lines
        frame.spans = build_spans(ctx, resolved, frame)
        frame.text_key = table.concat(resolved.lines, "\n") .. "|" .. tostring(frame.default_group)

        handle.apply(frame)

        if next(frame.screen) then
            screen.update(handle.id, frame.screen)
        else
            screen.clear(handle.id)
        end
    end

    local control = {}

    local function hard_stop()
        if stopped then
            return
        end
        stopped = true
        if timer and not timer:is_closing() then
            timer:stop()
            timer:close()
        end
        timer = nil
        for _, item in ipairs(schedule) do
            if item.entered then
                item.entered = false
                pcall(item.def.exit, effect_ctx(item))
            end
        end
        screen.clear(handle.id)
    end

    control.stop = hard_stop
    handle.cancel_lifetime = hard_stop
    handle.composer = control

    -- First frame immediately.
    pcall(render, false)

    local interval = math.max(10, math.floor(1000 / math.max(1, cfg.fps or 30)))
    timer = uv.new_timer()
    timer:start(interval, interval, function()
        if stopped then
            return
        end
        -- uv fast event context: defer to the main loop.
        vim.schedule(function()
            if stopped then
                return
            end
            if elapsed() >= duration then
                pcall(render, true)
                hard_stop()
                if opts.on_done then
                    opts.on_done(handle)
                end
            else
                pcall(render, false)
            end
        end)
    end)

    return control
end

return M
