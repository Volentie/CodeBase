--=== CONFIG
local folder_struct = {
    Client = "StarterPlayer/StarterPlayerScripts/Client",
    Shared = "ReplicatedStorage/Shared"
}

local _common = require(script:WaitForChild('common', 20))
assert(not _common or #_common == 0, "common module didn't load correctly")

local core = {
    modules = {},
    common = _common,
    config = {
        animations = require(_common.replicated_storage.Shared.configs.animations_config),
        npcs = require(_common.replicated_storage.Shared.configs.npcs_config)
    }
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
        local side_folder = evaluate_path(side)
        for _, module in ipairs(side_folder:GetChildren()) do
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