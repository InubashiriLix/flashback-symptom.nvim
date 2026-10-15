-- Turns TODO / FIXME style comments in the current buffer into murmur candidates.

local murmurs = require("flashback.murmurs")

local M = {}

---@param cfg FlashbackConfig
---@param bufnr number?
---@return MurmurItem[]
function M.candidates(cfg, bufnr)
    local integ = (cfg.integrations or {}).todo
    if not integ or integ.enabled == false then
        return {}
    end
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return {}
    end

    local patterns = integ.patterns or { "TODO", "FIXME", "XXX", "HACK" }
    local color = integ.color or "#f1fa8c"
    local list = {}

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for _, line in ipairs(lines) do
        for _, pat in ipairs(patterns) do
            local start = line:find(pat, 1, true)
            if start then
                local text = line:sub(start)
                if #text > 100 then
                    text = text:sub(1, 100)
                end
                local m = murmurs.new(text, { fg = color }, integ.duration or 3500)
                m.effects = { typewriter = {} }
                m.weight = integ.weight or 1
                m.source = "todo"
                list[#list + 1] = m
                break
            end
        end
    end

    if integ.max and #list > integ.max then
        local trimmed = {}
        for i = 1, integ.max do
            trimmed[i] = list[math.random(#list)]
        end
        return trimmed
    end
    return list
end

return M
