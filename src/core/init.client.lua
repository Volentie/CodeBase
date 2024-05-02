--!nonstrict
--=== CONFIG
local folder_struct = {
    Server = "ServerScriptService/server",
    Client = "StarterPlayer/StarterPlayerScripts/client",
    Shared = "ReplicatedStorage/shared"
}

local _common = require(script:WaitForChild('common', 1))
assert(_common, "common module didn't load correctly")

export type core = {
    modules: {[string]: table},
    common: {[string]: any},
    configs: {[string]: table},
    singletons: {[string]: table}
}

local core = {
    modules = {},
    common = _common,
    configs = {},
    uis = {},
    singletons = {},
    packages = {}
} :: core

local core_behaviour = {
    get_module = function(self: core, module_name: string): table
        return self.modules[module_name]
    end,
    get_singleton = function(self: core, singleton_name: string): table
        return self.singletons[singleton_name]
    end,
    get_ui = function(self: core, ui_name: string): table
        return self.uis[ui_name]
    end,
    get_config = function(self: core, config_name: string): table
        return self.configs[config_name]
    end,
    filter_call = function(predicate: (any) -> boolean, callback: (any) -> nil): (((any) -> boolean, (any) -> nil) -> nil) -> nil
        return function(func: ((any) -> boolean, (any) -> nil) -> nil)
            func(predicate, callback)
        end
    end
}

setmetatable(core, {__index = core_behaviour})

local function call_remote()
    local remoteFunction = game.ReplicatedStorage:WaitForChild("SetNetworkOwnershipFunction")
    remoteFunction:InvokeServer()
end

local function boot()
    
    call_remote()

    local function evaluate_path(path: string): any
        local path_parts = string.split(path, "/")
        local current = game
        for _, part in ipairs(path_parts) do
            current = current:WaitForChild(part, 0.5)
        end
        return current
    end
   
    -- Include singleton templates
    local function include_singletons()
        local singletons = _common.replicated_storage["shared"].singletons:GetChildren()
        for _, singleton in ipairs(singletons) do
            core.singletons[singleton.Name] = require(singleton)
        end
    end
    include_singletons()
    
    -- Load packages
    local function load_packages()
        local packages = _common.replicated_storage:WaitForChild("packages")
        for _, package in ipairs(packages:GetChildren()) do
            core.packages[package.Name] = require(package)
        end
    end
    load_packages()
    
    local function load_uis()
        local ui_folder = _common.replicated_storage["shared"]:WaitForChild("ui")
        -- Require the rest of the UI elements
        for _, ui in ipairs(ui_folder:GetChildren()) do
            core.uis[ui.Name] = require(ui)
        end
        -- Load the templates
        assert(core.uis["templates"], "templates ui module not found")
        core.uis["templates"]:load_sync(core)
        -- Load the UI elements with the possibility of using the templates
        for ui_name, ui in ipairs(core.uis) do
            if ui_name ~= "templates" then
                core.uis[ui.Name]:load_sync(core)
            end
        end
    end
    load_uis()
    
    local function load_all_sync()
        for _, module in core.modules do
            pcall(module.load_sync, module, core)
            module.load_sync = nil
        end
    end

    local function load_all_async()
        for _, module in core.modules do
            pcall(task.spawn, module.load_async, module, core)
            module.load_async = nil
        end
    end

    local function require_modules_n_configs()
        for _, side in folder_struct do
            local root_folder = evaluate_path(side)
            if not root_folder then
                continue
            end
            -- 
            --#region Load configs
            local config_folder = root_folder:FindFirstChild("configs")
            config_folder = config_folder and config_folder:IsA("Folder") and config_folder or nil
            if config_folder then
                for _, config in ipairs(config_folder:GetChildren()) do
                    if not config:IsA("ModuleScript") then
                        continue
                    end
                    core.configs[config.Name:gsub("_config", "")] = require(config)
                end 
            end
            --#endregion
            --
            --#region Require modules
            for _, module in ipairs(root_folder:GetChildren()) do
                -- This could've been done differently, removing the config folder from the root_children, for instance
                if not module:IsA("ModuleScript") then
                    continue
                end
                core.modules[module.Name] = require(module)
            end
            --#endregion
        end
    end
    --
    --#region BOOT SEQUENCE
    -- Require modules tables
    require_modules_n_configs()
    -- Run the load_sync function of each module (priority: sync > async)
    load_all_sync()
    -- Run the load_async function of each module
    load_all_async()
    --#endregion
end

boot()