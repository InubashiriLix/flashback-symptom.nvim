-- Audible / visual feedback when a murmur fires.

local M = {}

---@param cfg FlashbackConfig
---@param murmur MurmurItem
---@param kind string "murmur" | "trap"
function M.fire(cfg, murmur, kind)
    local f = cfg.feedback or {}
    if f.only_trap and kind ~= "trap" then
        return
    end

    if f.bell then
        -- Ring the terminal bell without disturbing the screen.
        pcall(function()
            io.stdout:write("\a")
            io.stdout:flush()
        end)
    end

    if f.notify then
        local levels = {
            error = vim.log.levels.ERROR,
            warn = vim.log.levels.WARN,
            info = vim.log.levels.INFO,
            debug = vim.log.levels.DEBUG,
        }
        local msg = kind == "trap" and "flashback: 你被劫持了" or ("flashback: " .. (murmur and murmur.text or ""))
        vim.notify(msg, levels[f.notify_level or "info"] or vim.log.levels.INFO)
    end
end

return M
