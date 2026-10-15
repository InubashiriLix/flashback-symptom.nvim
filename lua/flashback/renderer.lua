-- Renderer registry: the seam that keeps the float window from being hard-wired.
-- To add a new presentation (inline virt_text, fullscreen overlay, ...) drop a
-- module under lua/flashback/renderers/ implementing the Renderer interface and
-- it becomes selectable through config.render.renderer (or opts.renderer).
--
---@class Renderer
---@field render fun(murmur: MurmurItem, opts: table): table
---@field close fun(handle: table)

local M = {}

---@type table<string, Renderer>
M._impls = {}

---@type table[]
M._active = {}

---@param name string
---@param impl Renderer
function M.register(name, impl)
    M._impls[name] = impl
end

--- Renderer names are user-facing display modes; large/overlay share one module.
---@type table<string, string>
local MODULE = {
    float = "float",
    large = "overlay",
    overlay = "overlay",
}

--- Resolve a renderer by name, lazily requiring renderers/<name>.
---@param name string?
---@return Renderer|nil
function M.get(name)
    name = name or "float"
    local module_name = MODULE[name] or name
    if M._impls[module_name] then
        return M._impls[module_name]
    end
    local ok, impl = pcall(require, "flashback.renderers." .. module_name)
    if not ok or type(impl) ~= "table" then
        return nil
    end
    M._impls[module_name] = impl
    return impl
end

---@param murmur MurmurItem
---@param opts table
---@return table|nil handle
function M.render(murmur, opts)
    local impl = M.get(opts.renderer)
    if not impl then
        vim.notify("flashback: unknown renderer '" .. tostring(opts.renderer) .. "'", vim.log.levels.ERROR)
        return nil
    end
    local handle = impl.render(murmur, opts)
    if handle then
        M._active[#M._active + 1] = handle
    end
    return handle
end

---@param handle table
function M.close(handle)
    if not handle then
        return
    end
    for i, h in ipairs(M._active) do
        if h == handle then
            table.remove(M._active, i)
            break
        end
    end
    local impl = M.get(handle.renderer_name)
    if impl and impl.close then
        impl.close(handle)
    end
end

function M.close_all()
    local handles = M._active
    M._active = {}
    for _, handle in ipairs(handles) do
        local impl = M.get(handle.renderer_name)
        if impl and impl.close then
            impl.close(handle)
        end
    end
end

---@return number
function M.count()
    return #M._active
end

return M
