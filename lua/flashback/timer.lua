local uv = vim.uv or vim.loop

local M = {}

---@type table<any, any>[]
local timers = {}
local running = false

--- Compute the next interval with jitter applied.
---@param interval_ms number
---@param jitter number
---@return number
local function jittered(interval_ms, jitter)
    local factor = 1 + (math.random() * 2 - 1) * (jitter or 0)
    return math.max(200, math.floor(interval_ms * factor))
end

--- Start N timers, each firing on its own jittered cadence.
---@param cfg FlashbackTimerConfig
---@param on_tick fun(index: number)
function M.start(cfg, on_tick)
    M.stop()
    running = true

    local count = math.max(1, math.floor(cfg.timer_num or 1))
    for i = 1, count do
        local t = uv.new_timer()
        local function tick()
            if not running then
                return
            end
            -- uv callbacks run in a fast event context: API calls must be
            -- deferred back to the main loop with vim.schedule().
            if on_tick then
                vim.schedule(function()
                    if not running then
                        return
                    end
                    local ok, err = pcall(on_tick, i)
                    if not ok then
                        vim.notify("flashback: timer callback failed: " .. tostring(err), vim.log.levels.ERROR)
                    end
                end)
            end
            if not running then
                return
            end
            t:start(jittered(cfg.interval_ms, cfg.jitter), 0, tick)
        end
        -- Stagger the initial fire so the timers do not all pop at once.
        t:start(math.random(0, math.max(1, cfg.interval_ms or 1000)), 0, tick)
        timers[#timers + 1] = t
    end
end

function M.stop()
    running = false
    for _, t in ipairs(timers) do
        if not t:is_closing() then
            t:stop()
            t:close()
        end
    end
    timers = {}
end

---@return boolean
function M.is_running()
    return running
end

return M
