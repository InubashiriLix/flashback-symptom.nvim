-- Turns diagnostics into one-off murmur candidates.

local murmurs = require("flashback.murmurs")

local M = {}

local SEV_COLOR = { [1] = "#ff5555", [2] = "#ffb86c", [3] = "#8be9fd", [4] = "#6272a4" }
local SEV_NAME = { [1] = "ERROR", [2] = "WARN", [3] = "INFO", [4] = "HINT" }

---@param cfg FlashbackConfig
---@param bufnr number?
---@return MurmurItem[]
function M.candidates(cfg, bufnr)
    local integ = (cfg.integrations or {}).diagnostics
    if not integ or integ.enabled == false then
        return {}
    end
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return {}
    end

    local list = {}
    for _, d in ipairs(vim.diagnostic.get(bufnr)) do
        local sev = d.severity or 2
        local name = SEV_NAME[sev] or "INFO"
        if not integ.severity or integ.severity[name] ~= false then
            local color = SEV_COLOR[sev] or "#ffffff"
            local text = d.message or ""
            if #text > 120 then
                text = text:sub(1, 120)
            end
            local m = murmurs.new(text, { fg = color }, integ.duration or 3500)
            m.effects = { glitch = { color = color } }
            m.weight = integ.weight or 1
            m.source = "diagnostics"
            list[#list + 1] = m
        end
    end
    return list
end

return M
