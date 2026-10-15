-- Commands are available as soon as the plugin is loaded. If the user calls
-- require("flashback").setup{ cmds = ... } later, setup() recreates them under
-- the configured names.

if vim.g.loaded_flashback then
    return
end
vim.g.loaded_flashback = true

local ok, flashback = pcall(require, "flashback")
if not ok then
    return
end

local configs = require("flashback.configs")
flashback.create_commands(configs.defaults.cmds)
