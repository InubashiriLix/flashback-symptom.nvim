-- Screen-level effects host. These are the only effects that reach outside a
-- murmur's own float window, so this module is written defensively:
--   * it owns every window/buffer/autocmd/timer it creates
--   * exactly one murmur may own the screen at a time
--   * teardown() removes absolutely everything

local uv = vim.uv or vim.loop

local M = {}

-- An empty group to map NormalFloat to, so the glow window stays transparent.
vim.api.nvim_set_hl(0, "FlashbackGlowNormal", {})

---@type any
local owner = nil

local vign = { wins = {}, bufs = {}, active = false, spec = nil }
local glow = { win = nil, buf = nil, active = false, spec = nil, group = nil }
local harass = { active = false, timer = nil, orig_win = nil, orig = nil }
local grab = { active = false, timer = nil, win = nil, orig = nil, hold = nil, spec = nil }
local resize_group = nil

---@return number, number
local function dims()
    local ui = vim.api.nvim_list_uis()[1]
    local w = (ui and ui.width) or vim.o.columns
    local h = (ui and ui.height) or (vim.o.lines - vim.o.cmdheight - 1)
    return w, h
end

---@param color string|nil
---@return string
local function bg_group(color)
    color = color or "#000000"
    local name = "FlashbackScreenBG_" .. (color:gsub("[^%w]", ""))
    vim.api.nvim_set_hl(0, name, { bg = color })
    return name
end

---@param color string|nil
---@return string
local function border_group(color)
    color = color or "#ffffff"
    local name = "FlashbackScreenBorder_" .. (color:gsub("[^%w]", ""))
    vim.api.nvim_set_hl(0, name, { fg = color, bg = "NONE" })
    return name
end

---@param spec table
local function vign_apply(spec)
    vign.spec = spec
    local W, H = dims()
    local t = math.max(1, math.floor(spec.thickness or 1))
    local group = bg_group(spec.color)
    local blend = math.min(95, math.max(0, math.floor((1 - (spec.strength or 0.6)) * 100)))

    local rects = {
        { row = 0, col = 0, width = W, height = t },
        { row = math.max(0, H - t), col = 0, width = W, height = t },
        { row = 0, col = 0, width = t, height = H },
        { row = 0, col = math.max(0, W - t), width = t, height = H },
    }

    for i, r in ipairs(rects) do
        if not vign.wins[i] or not vim.api.nvim_win_is_valid(vign.wins[i]) then
            local buf = vim.api.nvim_create_buf(false, true)
            local win = vim.api.nvim_open_win(buf, false, {
                relative = "editor",
                row = r.row,
                col = r.col,
                width = r.width,
                height = r.height,
                style = "minimal",
                focusable = false,
                noautocmd = true,
                zindex = 150,
                border = "none",
            })
            vign.wins[i], vign.bufs[i] = win, buf
        end
        local win = vign.wins[i]
        pcall(vim.api.nvim_win_set_config, win, {
            relative = "editor",
            row = r.row,
            col = r.col,
            width = r.width,
            height = r.height,
        })
        pcall(vim.api.nvim_set_option_value, "winblend", blend, { win = win })
        pcall(vim.api.nvim_set_option_value, "winhl", "NormalFloat:" .. group, { win = win })
    end
    vign.active = true
end

local function vign_clear()
    for i, win in ipairs(vign.wins) do
        if win and vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_close, win, true)
        end
        local buf = vign.bufs[i]
        if buf and vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end
    vign.wins, vign.bufs = {}, {}
    vign.active = false
    vign.spec = nil
end

local function glow_place()
    if not glow.active or not glow.win or not vim.api.nvim_win_is_valid(glow.win) then
        return
    end
    local r = vim.fn.screenrow()
    local c = vim.fn.screencol()
    if not r or r <= 0 then
        return
    end
    local W, H = dims()
    local row = math.min(math.max(0, H - 1), r - 1)
    local col = math.min(math.max(0, W - 1), c - 1)
    pcall(vim.api.nvim_win_set_config, glow.win, {
        relative = "editor",
        row = row,
        col = col,
        width = 1,
        height = 1,
    })
end

---@param spec table
local function glow_apply(spec)
    glow.spec = spec
    if not glow.win or not vim.api.nvim_win_is_valid(glow.win) then
        local buf = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_open_win(buf, false, {
            relative = "editor",
            row = 0,
            col = 0,
            width = 1,
            height = 1,
            style = "minimal",
            focusable = false,
            noautocmd = true,
            zindex = 160,
            border = "rounded",
        })
        glow.win, glow.buf = win, buf
    end
    local group = border_group(spec.color)
    pcall(vim.api.nvim_set_option_value, "winblend", math.min(95, math.max(0, spec.blend or 55)),
        { win = glow.win })
    pcall(vim.api.nvim_set_option_value, "winhl",
        "NormalFloat:FlashbackGlowNormal,FloatBorder:" .. group, { win = glow.win })
    glow.active = true
    glow_place()
end

local function glow_clear()
    if glow.win and vim.api.nvim_win_is_valid(glow.win) then
        pcall(vim.api.nvim_win_close, glow.win, true)
    end
    if glow.buf and vim.api.nvim_buf_is_valid(glow.buf) then
        pcall(vim.api.nvim_buf_delete, glow.buf, { force = true })
    end
    glow.win, glow.buf, glow.active, glow.spec = nil, nil, false, nil
end

local function harass_clear()
    harass.active = false
    if harass.timer and not harass.timer:is_closing() then
        harass.timer:stop()
        harass.timer:close()
    end
    harass.timer = nil
    -- Always restore the cursor we may have nudged.
    if harass.orig_win and harass.orig and vim.api.nvim_win_is_valid(harass.orig_win) then
        pcall(vim.api.nvim_win_set_cursor, harass.orig_win, harass.orig)
    end
    harass.orig_win, harass.orig = nil, nil
end

---@param spec table
local function harass_apply(spec)
    if harass.active then
        return
    end
    local win = vim.api.nvim_get_current_win()
    local ok, pos = pcall(vim.api.nvim_win_get_cursor, win)
    harass.active = true
    harass.orig_win = win
    harass.orig = ok and pos or nil

    harass.timer = uv.new_timer()
    local interval = math.max(200, spec.interval or 700)
    harass.timer:start(interval, interval, function()
        vim.schedule(function()
            if not harass.active then
                return
            end
            local w = harass.orig_win
            if not w or not vim.api.nvim_win_is_valid(w) or vim.api.nvim_get_current_win() ~= w then
                return
            end
            if not spec.allow_insert and vim.fn.mode():sub(1, 1) == "i" then
                return
            end
            local cur = vim.api.nvim_win_get_cursor(w)
            local amp = math.max(1, spec.amplitude or 1)
            local delta = (math.random(0, 1) == 0) and -amp or amp
            if spec.jump and math.random() < (spec.jump_chance or 0.15) then
                delta = delta * math.max(2, spec.jump)
            end
            local target = { cur[1], math.max(0, cur[2] + delta) }
            if spec.axes == "both" then
                local last = math.max(1, vim.api.nvim_buf_line_count(0))
                local row = cur[1] + ((math.random(0, 1) == 0) and -1 or 1)
                target[1] = math.min(last, math.max(1, row))
            end
            pcall(vim.api.nvim_win_set_cursor, w, target)
            vim.defer_fn(function()
                if harass.active and vim.api.nvim_win_is_valid(w) then
                    pcall(vim.api.nvim_win_set_cursor, w, cur)
                end
            end, 150)
        end)
    end)
end

local function grab_clear()
    grab.active = false
    if grab.timer and not grab.timer:is_closing() then
        grab.timer:stop()
        grab.timer:close()
    end
    grab.timer = nil
    -- Always restore the exact cursor we captured, in the exact window.
    if grab.win and grab.orig and vim.api.nvim_win_is_valid(grab.win) then
        pcall(vim.api.nvim_win_set_cursor, grab.win, grab.orig)
    end
    grab.win, grab.orig, grab.hold, grab.spec = nil, nil, nil, nil
end

---@param spec table
local function grab_apply(spec)
    if grab.active then
        return
    end
    -- Never yank the cursor out from under someone who is typing.
    if not spec.insert and vim.fn.mode():sub(1, 1) == "i" then
        return
    end

    local win = vim.api.nvim_get_current_win()
    local ok, pos = pcall(vim.api.nvim_win_get_cursor, win)
    if not ok then
        return
    end

    grab.active = true
    grab.win = win
    grab.orig = pos
    grab.hold = pos
    grab.spec = spec

    if spec.to == "center" then
        local h = vim.api.nvim_win_get_height(win)
        local top = vim.fn.line("w0")
        local last = math.max(1, vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win)))
        local row = math.min(last, math.max(1, top + math.floor(h / 2) - 1))
        local target = { row, 0 }
        pcall(vim.api.nvim_win_set_cursor, win, target)
        grab.hold = target
    end

    grab.timer = uv.new_timer()
    grab.timer:start(80, 80, function()
        vim.schedule(function()
            if not grab.active then
                return
            end
            local w = grab.win
            if not w or not vim.api.nvim_win_is_valid(w) or vim.api.nvim_get_current_win() ~= w then
                return
            end
            if not (grab.spec and grab.spec.insert) and vim.fn.mode():sub(1, 1) == "i" then
                return
            end
            pcall(vim.api.nvim_win_set_cursor, w, grab.hold)
        end)
    end)
end

local function ensure_resize_autocmd()
    if resize_group then
        return
    end
    resize_group = vim.api.nvim_create_augroup("FlashbackScreen", { clear = true })
    vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "CursorMoved", "CursorMovedI" }, {
        group = resize_group,
        callback = function()
            if vign.active and vign.spec then
                vign_apply(vign.spec)
            end
            if glow.active then
                glow_place()
            end
        end,
    })
end

local function delete_resize_autocmd()
    if resize_group then
        pcall(vim.api.nvim_del_augroup_by_id, resize_group)
        resize_group = nil
    end
end

---@param key any
---@param spec table
function M.update(key, spec)
    if owner ~= nil and owner ~= key then
        M.teardown()
    end
    owner = key
    ensure_resize_autocmd()

    if spec.vignette then
        vign_apply(spec.vignette)
    else
        vign_clear()
    end

    if spec.cursor_glow then
        glow_apply(spec.cursor_glow)
    else
        glow_clear()
    end

    if spec.cursor_harass then
        harass_apply(spec.cursor_harass)
    else
        harass_clear()
    end

    if spec.cursor_grab then
        grab_apply(spec.cursor_grab)
    else
        grab_clear()
    end
end

---@param key any
function M.clear(key)
    if owner == nil or owner == key then
        M.teardown()
    end
end

function M.teardown()
    owner = nil
    vign_clear()
    glow_clear()
    harass_clear()
    grab_clear()
    delete_resize_autocmd()
end

---@return boolean
function M.is_active()
    return vign.active or glow.active or harass.active or grab.active
end

return M
