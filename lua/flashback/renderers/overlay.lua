-- The overlay renderer: a large or full-screen murmur.
--
-- It drives the two "big" display modes:
--
--   large      a big window (default 60% of the editor) placed by the normal
--              `render.position` policy
--   overlay    a full-editor window (default 100%) with the text centred
--
-- The text block is centred inside the window with `padding`, and the window
-- rect can be animated by the `grow` / `shrink` / `wipe` effects through
-- `frame.cover` + `frame.anchor`.

local pos = require("flashback.renderers.pos")
local shadow = require("flashback.renderers.shadow")

local M = {}

local ns = vim.api.nvim_create_namespace("flashback_overlay")
local next_id = 0

---@param display table
---@return number
local function target_cover(display)
    if display.cover then
        return math.min(1.0, math.max(0.01, display.cover))
    end
    return display.mode == "large" and 0.6 or 1.0
end

--- Compute the target (unanimated) rect for this murmur.
---@param handle table
---@return number tw, number th, number tr, number tc
local function target_rect(handle)
    local W, H = pos.area()
    local display = handle.display
    local cover = target_cover(display)
    local margin = pos.border_margin(handle.render_cfg)
    local tw = math.max(1, math.floor(W * cover))
    local th = math.max(1, math.floor(H * cover))

    local tr, tc
    if display.mode == "large" then
        tr, tc = pos.place(handle.render_cfg, tw, th)
    else
        tr, tc = pos.align_pos(display.align, tw, th, margin)
    end
    return tw, th, tr, tc
end

--- Pad and centre the text block inside the window.
---@param lines string[]
---@param spans table[]
---@param w number
---@param h number
---@param display table
---@return string[] lines, table[] spans
local function layout(lines, spans, w, h, display)
    local align = display.align or "center"
    local pad = math.max(0, math.floor(display.padding or 0))
    local text_w, text_h = pos.measure(lines)

    local pad_left
    if align:find("left") then
        pad_left = pad
    elseif align:find("right") then
        pad_left = math.max(pad, w - pad - text_w)
    else
        pad_left = math.max(pad, math.floor((w - text_w) / 2))
    end

    local pad_top
    if align:find("top") then
        pad_top = pad
    elseif align:find("bottom") then
        pad_top = math.max(pad, h - pad - text_h)
    else
        pad_top = math.max(pad, math.floor((h - text_h) / 2))
    end
    -- never push the text past the bottom of the window
    if pad_top + text_h > h then
        pad_top = math.max(0, h - text_h)
    end

    local out = {}
    for _ = 1, pad_top do
        out[#out + 1] = ""
    end
    local prefix = string.rep(" ", pad_left)
    for i = 1, #lines do
        out[#out + 1] = prefix .. lines[i]
    end

    local out_spans = {}
    for _, s in ipairs(spans or {}) do
        local cend = s.cend
        if cend ~= nil and cend ~= -1 then
            cend = cend + pad_left
        end
        out_spans[#out_spans + 1] = {
            line = (s.line or 0) + pad_top,
            cstart = (s.cstart or 0) + pad_left,
            cend = cend or -1,
            group = s.group,
        }
    end
    return out, out_spans
end

---@param handle table
---@param frame table
local function apply(handle, frame)
    if handle.closed or not vim.api.nvim_win_is_valid(handle.win) or not vim.api.nvim_buf_is_valid(handle.buf) then
        return
    end

    local display = handle.display
    local tw, th, tr, tc = target_rect(handle)

    local cover_now = frame.cover
    if cover_now == nil then
        cover_now = target_cover(display)
    end
    local ratio = 1
    if tw > 0 then
        ratio = math.min(1, math.max(0, cover_now / target_cover(display)))
    end

    local w = math.max(1, math.floor(tw * ratio))
    local h = math.max(1, math.floor(th * ratio))
    local anchor = frame.anchor or "center"
    local dr, dc = pos.anchor_offset(anchor, tw, th, w, h)
    local margin = pos.border_margin(handle.render_cfg)
    local W, H = pos.area()
    local row = math.min(math.max(0, H - h - 2 * margin), math.max(0, tr + dr))
    local col = math.min(math.max(0, W - w - 2 * margin), math.max(0, tc + dc))

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

    local lines, spans = layout(frame.lines or { "" }, frame.spans, w, h, display)
    local text_key = (frame.text_key or "") .. "|" .. w .. "x" .. h
    if last.text ~= text_key then
        vim.api.nvim_buf_set_lines(handle.buf, 0, -1, false, lines)
        last.text = text_key
    else
        -- spans still need refreshing every frame (colour animations)
        vim.api.nvim_buf_set_lines(handle.buf, 0, -1, false, lines)
    end

    vim.api.nvim_buf_clear_namespace(handle.buf, ns, 0, -1)
    for _, s in ipairs(spans) do
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

    shadow.apply(handle, frame.shadow, lines, w, h, row, col, text_key)
end

---@param murmur MurmurItem
---@param opts table
---@return table|nil
function M.render(murmur, opts)
    local rc = opts.render or {}
    local display = vim.deepcopy(opts.display or {})
    display.mode = display.mode or (opts.renderer == "large" and "large" or "overlay")
    if display.padding == nil then
        display.padding = display.mode == "large" and 2 or 3
    end
    if display.border == nil then
        display.border = display.mode == "large" and (rc.border or "rounded") or "none"
    end

    local opaque = display.opaque ~= false
    local base_blend = opaque and 0 or (display.blend or rc.winblend or 60)

    local handle = {
        renderer_name = "overlay",
        mode = display.mode,
        id = next_id + 1,
        display = display,
        render_cfg = vim.tbl_extend("force", {}, rc, { border = display.border }),
        base_blend = base_blend,
        closed = false,
        murmur = murmur,
        on_close = {},
        last = {},
        shadow = nil,
    }
    next_id = handle.id

    local tw, th, tr, tc = target_rect(handle)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].modifiable = true
    local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        row = tr,
        col = tc,
        width = tw,
        height = th,
        style = "minimal",
        focusable = false,
        noautocmd = true,
        zindex = 200,
        border = display.border,
    })
    handle.win = win
    handle.buf = buf
    pcall(vim.api.nvim_set_option_value, "winblend", base_blend, { win = win })
    handle.last.blend = base_blend

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

    shadow.close(handle)

    if handle.win and vim.api.nvim_win_is_valid(handle.win) then
        pcall(vim.api.nvim_win_close, handle.win, true)
    end
    if handle.buf and vim.api.nvim_buf_is_valid(handle.buf) then
        pcall(vim.api.nvim_buf_delete, handle.buf, { force = true })
    end
end

return M
