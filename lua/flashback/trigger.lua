-- Trigger conditions: decides *whether* a murmur may appear right now, and
-- filters individual murmurs by their `when` tags.

local uv = vim.uv or vim.loop

local M = {}

---@type number
local last_activity = uv.hrtime()
---@type table<string, boolean>
local events = {}
---@type number|nil
local track_group = nil

---@param list any[]
---@param value any
---@return boolean
local function contains(list, value)
    if type(list) ~= "table" then
        return false
    end
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

function M.mark_activity()
    last_activity = uv.hrtime()
end

---@param name string
function M.fire_event(name)
    events[name] = true
end

---@param name string
---@return boolean
function M.consume_event(name)
    if events[name] then
        events[name] = false
        return true
    end
    return false
end

function M.start_tracking()
    if track_group then
        return
    end
    track_group = vim.api.nvim_create_augroup("FlashbackActivity", { clear = true })
    vim.api.nvim_create_autocmd({
        "InsertEnter", "InsertLeave", "TextChanged", "TextChangedI",
        "CursorMoved", "CursorMovedI", "BufEnter", "WinEnter",
    }, {
        group = track_group,
        callback = function()
            M.mark_activity()
        end,
    })
end

function M.stop_tracking()
    if track_group then
        pcall(vim.api.nvim_del_augroup_by_id, track_group)
        track_group = nil
    end
    events = {}
end

---@return string
local function mode_name()
    local m = vim.fn.mode():sub(1, 1)
    if m == "i" then
        return "insert"
    elseif m == "v" or m == "V" or m == "\22" then
        return "visual"
    elseif m == "R" then
        return "replace"
    elseif m == "c" then
        return "cmd"
    elseif m == "t" then
        return "term"
    end
    return "normal"
end

---@param s string|nil
---@return number|nil
local function hhmm(s)
    if type(s) ~= "string" then
        return nil
    end
    local h, m = s:match("^(%d+):(%d+)$")
    if not h then
        return nil
    end
    return tonumber(h) * 60 + tonumber(m)
end

--- Evaluate the global trigger conditions.
---@param cfg FlashbackConfig
---@return boolean, number weight
function M.conditions_ok(cfg)
    local t = cfg.trigger or {}
    local en = t.enabled or {}
    local weight = 1

    if en.filetype then
        local ft = vim.bo.filetype
        local f = t.filetypes or {}
        if f.include and #f.include > 0 and not contains(f.include, ft) then
            return false, weight
        end
        if f.exclude and contains(f.exclude, ft) then
            return false, weight
        end
    end

    if en.mode then
        local modes = t.modes or {}
        if modes[mode_name()] == false then
            return false, weight
        end
    end

    if en.idle then
        local min_ms = (t.idle and t.idle.min_ms) or 30000
        if (uv.hrtime() - last_activity) / 1e6 < min_ms then
            return false, weight
        end
    end

    if en.time then
        local ranges = (t.time and t.time.ranges) or {}
        if #ranges > 0 then
            local now = os.date("*t")
            local mins = now.hour * 60 + now.min
            local hit = false
            local best = 1
            for _, r in ipairs(ranges) do
                local from, to = hhmm(r.from), hhmm(r.to)
                if from and to then
                    local inside
                    if from <= to then
                        inside = mins >= from and mins <= to
                    else
                        inside = mins >= from or mins <= to
                    end
                    if inside then
                        hit = true
                        best = math.max(best, tonumber(r.weight) or 1)
                    end
                end
            end
            if not hit then
                return false, weight
            end
            weight = best
        end
    end

    return true, weight
end

--- Filter a single murmur by its `when` tags.
---@param murmur MurmurItem
---@return boolean
function M.matches_when(murmur)
    local w = murmur.when
    if not w then
        return true
    end
    if w.filetypes and #w.filetypes > 0 and not contains(w.filetypes, vim.bo.filetype) then
        return false
    end
    if w.modes and #w.modes > 0 and not contains(w.modes, mode_name()) then
        return false
    end
    return true
end

---@return string
function M.mode_name()
    return mode_name()
end

return M
