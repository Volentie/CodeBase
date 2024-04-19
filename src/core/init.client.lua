--=== CONFIG
local folder_struct = {
    Server = "ServerScriptService/Server",
    Client = "StarterPlayer/StarterPlayerScripts/Client",
    Shared = "ReplicatedStorage/Shared"
}

local _common = require(script:WaitForChild('common', 20))
assert(not _common or #_common == 0, "common module didn't load correctly")

local core = {
    modules = {},
    common = _common,
    configs = {}
}

do
    local function evaluate_path(path: string): any
        local path_parts = string.split(path, "/")
        local current = game
        for _, part in ipairs(path_parts) do
            current = current:WaitForChild(part, 5)
        end
        return current
    end

    -- Depth: 1
    for _, side in folder_struct do
        local root_folder = evaluate_path(side)
        if not root_folder then continue end
        for _, module in ipairs(root_folder:GetChildren()) do
            -- Look for configs
            if module:IsA("Folder") and module.Name:lower():match("config.*$") then
                for _, config in ipairs(module:GetChildren()) do
                    if not config:IsA("ModuleScript") then continue end
                    local config_name = config.Name:lower():gsub("_config", "")
                    core.configs[config_name] = require(config)
                end
            end
            if not module:IsA("ModuleScript") then continue end
            core.modules[module.Name] = require(module)
        end
    end
    
    local function load_priority()
        for _, module in core.modules do
            pcall(function()
                module:load_async(core)
            end)
        end
    end
    task.spawn(load_priority)

    local function load_sync()
        for _, module in core.modules do
            pcall(function()
                module:load_sync(core)
            end)
        end
    end
    load_sync()
end