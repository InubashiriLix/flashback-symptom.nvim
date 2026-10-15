-- A second, darker copy of a murmur window drawn behind it. Shared by the float
-- and overlay renderers so there is exactly one place that owns shadow windows.

local pos = require("flashback.renderers.pos")

local M = {}

---@param handle table
---@param spec table|nil { enabled, dx, dy, color, blend }
---@param lines string[]
---@param w number
---@param h number
---@param row number
---@param col number
---@param text_key string
function M.apply(handle, spec, lines, w, h, row, col, text_key)
    if not (spec and spec.enabled) then
        M.close(handle)
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

    if s.last.text ~= text_key then
        vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, lines)
        s.last.text = text_key
    end

    local W, H = pos.area()
    local sr = math.min(math.max(0, H - h), math.max(0, row + (spec.dy or 0)))
    local sc = math.min(math.max(0, W - w), math.max(0, col + (spec.dx or 0)))
    pcall(vim.api.nvim_win_set_config, s.win, {
        relative = "editor",
        row = sr,
        col = sc,
        width = w,
        height = h,
    })
    pcall(vim.api.nvim_set_option_value, "winblend", spec.blend or 60, { win = s.win })
    if spec.color then
        local g = "FlashbackShadow_" .. (spec.color:gsub("[^%w]", ""))
        pcall(vim.api.nvim_set_hl, 0, g, { bg = spec.color })
        pcall(vim.api.nvim_set_option_value, "winhl", "NormalFloat:" .. g, { win = s.win })
    end
end

---@param handle table
function M.close(handle)
    if not handle.shadow then
        return
    end
    local s = handle.shadow
    handle.shadow = nil
    if s.win and vim.api.nvim_win_is_valid(s.win) then
        pcall(vim.api.nvim_win_close, s.win, true)
    end
    if s.buf and vim.api.nvim_buf_is_valid(s.buf) then
        pcall(vim.api.nvim_buf_delete, s.buf, { force = true })
    end
end

return M
