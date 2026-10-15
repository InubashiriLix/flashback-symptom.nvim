-- The float renderer. It owns one main window (and optionally a shadow window)
-- and exposes a single `handle.apply(frame)` entry point. The composer hands it
-- a fully resolved frame; everything window-related happens here so there is
-- exactly one place that can (mis)handle windows.
--
-- Safety rules honoured here:
--   * only ever touches windows/buffers created by this module
--   * every position is clamped to the screen
--   * every close path is idempotent and closes shadow + main reliably

local M = {}

local ns = vim.api.nvim_create_namespace("flashback_float")

local next_id = 0

---@return number, number
local function screen()
    local ui = vim.api.nvim_list_uis()[1]
    local w = (ui and ui.width) or vim.o.columns
    local h = (ui and ui.height) or (vim.o.lines - vim.o.cmdheight - 1)
    return w, h
end

---@param lines string[]
---@return number, number
local function measure(lines)
    local w = 1
    for _, l in ipairs(lines) do
        local lw = vim.api.nvim_strwidth(l)
        if lw > w then
            w = lw
        end
    end
    return w, math.max(1, #lines)
end

---@param cfg FlashbackRenderConfig
---@return number
local function border_margin(cfg)
    local b = cfg.border
    if b == nil or b == "none" then
        return 0
    end
    return 1
end

---@param cfg FlashbackRenderConfig
---@param w number
---@param h number
---@return number, number
local function compute_pos(cfg, w, h)
    local W, H = screen()
    local m = border_margin(cfg)
    local maxr = math.max(0, H - h - 2 * m)
    local maxc = math.max(0, W - w - 2 * m)
    local mode = cfg.position or "random"

    if mode == "corner" then
        local c = cfg.corner or "botright"
        local r = c:find("top") and 0 or maxr
        local col = c:find("right") and maxc or 0
        return r, col
    elseif mode == "cursor" then
        local off = cfg.cursor_offset or { row = 1, col = 0 }
        local r = vim.fn.screenrow()
        local col = vim.fn.screencol()
        if not r or r <= 0 then
            r, col = 1, 1
        end
        r = math.min(maxr, math.max(0, r - 1 + (off.row or 1)))
        col = math.min(maxc, math.max(0, col - 1 + (off.col or 0)))
        return r, col
    end

    return math.random(0, maxr), math.random(0, maxc)
end

---@param handle table
---@param frame table
local function apply_shadow(handle, frame, lines, w, h, row, col)
    local shadow = frame.shadow
    if not (shadow and shadow.enabled) then
        if handle.shadow then
            if handle.shadow.win and vim.api.nvim_win_is_valid(handle.shadow.win) then
                pcall(vim.api.nvim_win_close, handle.shadow.win, true)
            end
            if handle.shadow.buf and vim.api.nvim_buf_is_valid(handle.shadow.buf) then
                pcall(vim.api.nvim_buf_delete, handle.shadow.buf, { force = true })
            end
            handle.shadow = nil
        end
        return
    end

    if not handle.shadow then
        local buf = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_open_win(buf, false, {
            relative = "editor",
            row = row,
            col = col,
            width = w,
            height = h,
            style = "minimal",
            focusable = false,
            noautocmd = true,
            zindex = 100,
            border = "none",
        })
        handle.shadow = { buf = buf, win = win, last = {} }
    end

    local s = handle.shadow
    if not vim.api.nvim_win_is_valid(s.win) then
        handle.shadow = nil
        return
    end

    if s.last.text ~= frame.text_key then
        vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, lines)
        s.last.text = frame.text_key
    end

    local W, H = screen()
    local sr = math.min(math.max(0, H - h), math.max(0, row + (shadow.dy or 0)))
    local sc = math.min(math.max(0, W - w), math.max(0, col + (shadow.dx or 0)))
    pcall(vim.api.nvim_win_set_config, s.win, {
        relative = "editor",
        row = sr,
        col = sc,
        width = w,
        height = h,
    })
    pcall(vim.api.nvim_set_option_value, "winblend", shadow.blend or 60, { win = s.win })
    if shadow.color then
        local g = "FlashbackShadow_" .. (shadow.color:gsub("[^%w]", ""))
        pcall(vim.api.nvim_set_hl, 0, g, { bg = shadow.color })
        pcall(vim.api.nvim_set_option_value, "winhl", "NormalFloat:" .. g, { win = s.win })
    end
end

---@param handle table
---@param frame table
local function apply(handle, frame)
    if handle.closed or not vim.api.nvim_win_is_valid(handle.win) or not vim.api.nvim_buf_is_valid(handle.buf) then
        return
    end

    local rc = handle.render_cfg
    local lines = frame.lines or { "" }
    local w, h = measure(lines)
    w = w + 2

    local m = border_margin(rc)
    local W, H = screen()
    local row = (handle.base_row or 0) + math.floor(frame.row_offset or 0)
    local col = (handle.base_col or 0) + math.floor(frame.col_offset or 0)
    row = math.min(math.max(0, H - h - 2 * m), math.max(0, row))
    col = math.min(math.max(0, W - w - 2 * m), math.max(0, col))

    local last = handle.last
    if last.w ~= w or last.h ~= h or last.row ~= row or last.col ~= col then
        pcall(vim.api.nvim_win_set_config, handle.win, {
            relative = "editor",
            row = row,
            col = col,
            width = w,
            height = h,
        })
        last.w, last.h, last.row, last.col = w, h, row, col
    end

    local text_key = frame.text_key
    if last.text ~= text_key then
        vim.api.nvim_buf_set_lines(handle.buf, 0, -1, false, lines)
        last.text = text_key
    end

    vim.api.nvim_buf_clear_namespace(handle.buf, ns, 0, -1)
    for _, s in ipairs(frame.spans or {}) do
        if s.group then
            pcall(vim.api.nvim_buf_add_highlight, handle.buf, ns, s.group, s.line, s.cstart or 0, s.cend or -1)
        end
    end

    if frame.win_group and last.win_group ~= frame.win_group then
        pcall(vim.api.nvim_set_option_value, "winhl", "NormalFloat:" .. frame.win_group, { win = handle.win })
        last.win_group = frame.win_group
    end

    local blend = frame.blend
    if blend == nil then
        blend = handle.base_blend
    end
    blend = math.min(100, math.max(0, math.floor(blend)))
    if last.blend ~= blend then
        pcall(vim.api.nvim_set_option_value, "winblend", blend, { win = handle.win })
        last.blend = blend
    end

    apply_shadow(handle, frame, lines, w, h, row, col)
end

---@param murmur MurmurItem
---@param opts table
---@return table|nil
function M.render(murmur, opts)
    local rc = opts.render or {}
    local lines = vim.split(murmur.text or "", "\n", { plain = true })
    if #lines == 0 then
        lines = { "" }
    end

    local w, h = measure(lines)
    w = w + 2
    local row, col = compute_pos(rc, w, h)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].modifiable = true

    local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        row = row,
        col = col,
        width = w,
        height = h,
        style = "minimal",
        focusable = false,
        noautocmd = true,
        zindex = 200,
        border = rc.border or "rounded",
    })
    pcall(vim.api.nvim_set_option_value, "winblend", rc.winblend or 0, { win = win })

    next_id = next_id + 1
    local handle = {
        renderer_name = "float",
        id = next_id,
        win = win,
        buf = buf,
        base_row = row,
        base_col = col,
        base_blend = rc.winblend or 0,
        render_cfg = rc,
        closed = false,
        murmur = murmur,
        on_close = {},
        last = {},
        shadow = nil,
    }

    function handle.add_on_close(fn)
        handle.on_close[#handle.on_close + 1] = fn
    end

    function handle.apply(frame)
        apply(handle, frame)
    end

    return handle
end

---@param handle table
function M.close(handle)
    if not handle or handle.closed then
        return
    end
    handle.closed = true

    if handle.cancel_lifetime then
        pcall(handle.cancel_lifetime)
        handle.cancel_lifetime = nil
    end
    for _, fn in ipairs(handle.on_close) do
        pcall(fn)
    end

    if handle.shadow then
        if handle.shadow.win and vim.api.nvim_win_is_valid(handle.shadow.win) then
            pcall(vim.api.nvim_win_close, handle.shadow.win, true)
        end
        if handle.shadow.buf and vim.api.nvim_buf_is_valid(handle.shadow.buf) then
            pcall(vim.api.nvim_buf_delete, handle.shadow.buf, { force = true })
        end
        handle.shadow = nil
    end

    if handle.win and vim.api.nvim_win_is_valid(handle.win) then
        pcall(vim.api.nvim_win_close, handle.win, true)
    end
    if handle.buf and vim.api.nvim_buf_is_valid(handle.buf) then
        pcall(vim.api.nvim_buf_delete, handle.buf, { force = true })
    end
end

return M
