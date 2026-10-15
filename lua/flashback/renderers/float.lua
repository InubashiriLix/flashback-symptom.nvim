-- The classic float renderer: a window sized to its text.
--
-- The composer hands `handle.apply(frame)` a fully resolved frame; everything
-- window-related happens here so there is exactly one place that can
-- (mis)handle windows.
--
-- Safety rules honoured here:
--   * only ever touches windows/buffers created by this module
--   * every position is clamped to the screen
--   * every close path is idempotent and closes shadow + main reliably

local pos = require("flashback.renderers.pos")
local shadow = require("flashback.renderers.shadow")

local M = {}

local ns = vim.api.nvim_create_namespace("flashback_float")
local next_id = 0

---@param handle table
---@param frame table
local function apply(handle, frame)
    if handle.closed or not vim.api.nvim_win_is_valid(handle.win) or not vim.api.nvim_buf_is_valid(handle.buf) then
        return
    end

    local rc = handle.render_cfg
    local lines = frame.lines or { "" }
    local w, h = pos.measure(lines)
    w = w + 2

    local m = pos.border_margin(rc)
    local W, H = pos.area()
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

    shadow.apply(handle, frame.shadow, lines, w, h, row, col, text_key)
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

    local w, h = pos.measure(lines)
    w = w + 2
    local row, col = pos.place(rc, w, h)

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
        mode = "float",
        id = next_id,
        win = win,
        buf = buf,
        base_row = row,
        base_col = col,
        base_blend = rc.winblend or 0,
        render_cfg = rc,
        display = opts.display or {},
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

    shadow.close(handle)

    if handle.win and vim.api.nvim_win_is_valid(handle.win) then
        pcall(vim.api.nvim_win_close, handle.win, true)
    end
    if handle.buf and vim.api.nvim_buf_is_valid(handle.buf) then
        pcall(vim.api.nvim_buf_delete, handle.buf, { force = true })
    end
end

return M
