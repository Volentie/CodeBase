--=== CONFIG
local folder_struct = {
    Server = "ServerScriptService/server",
    Client = "StarterPlayer/StarterPlayerScripts/client",
    Shared = "ReplicatedStorage/shared"
}

local DEBUG_MODE = true

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
    packages = {},
    name = "Fox",
} :: core

-- Set pretty name for debugging purposes
do
    local str = core.name:gsub("%w+", string.upper)
    core.pretty_name = str:gsub("(.+)", "-=:[%1 DEBUG]:=-")
end

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

core.cache = {}

--#region Loading screen
-- Loading screen (TODO: Move to a separate module)
function core:create_loading_screen()
    self.cache["loading_screen"] = _common.player_gui:WaitForChild("HUD"):WaitForChild("loading")
    local loading_screen_text = self.cache["loading_screen"]:WaitForChild("TextLabel")
    self.cache["loading_routine"] = coroutine.create(function()
        while true do
            loading_screen_text.Text = "Loading"
            task.wait(0.5)
            loading_screen_text.Text = "Loading."
            task.wait(0.5)
            loading_screen_text.Text = "Loading.."
            task.wait(0.5)
            loading_screen_text.Text = "Loading..."
            task.wait(0.5)
        end
    end)
    self.cache["loading_blur"] = _common.lighting:WaitForChild("Blur")
end

function core:show_loading_screen()
    self.cache["loading_blur"].Enabled = true
    self.cache["loading_screen"].Visible = true
    coroutine.resume(self.cache["loading_routine"])
end
function core:destroy_loading_screen()
    self.cache["loading_blur"].Enabled = false
    self.cache["loading_screen"].Visible = false
    coroutine.close(self.cache["loading_routine"])
    self.cache["loading_routine"] = nil
    self.cache["loading_screen"]:Destroy()
    self.cache["loading_screen"] = nil
    self.cache["loading_blur"]:Destroy()
    self.cache["loading_blur"] = nil
end
--#endregion Loading screen

local function call_remote()
    local function get_back()
        for _, npc_model in workspace.NPCs.Needy:GetChildren() do
            task.spawn(function()
                local hrp = npc_model:FindFirstChild("HumanoidRootPart")
                while not hrp do
                    hrp = npc_model:FindFirstChild("HumanoidRootPart")
                    task.wait(0.1)
                end
                npc_model:WaitForChild("HumanoidRootPart").Anchored = true
            end)
        end
    end

    local remoteFunction = game.ReplicatedStorage:WaitForChild("SetNetworkOwnershipFunction")
    remoteFunction:InvokeServer()
    -- Get response
    remoteFunction.OnClientInvoke = function(_response)
        task.spawn(get_back)
        return
    end
end

local function debug(...)
    if DEBUG_MODE then
        warn(core.pretty_name, ...)
    end
end

local function boot()
    -- Show loading screen
    core:create_loading_screen()
    core:show_loading_screen()
    -- Set network ownership of NPCs to the client before anything
    -- Humanoid control doesn't work properly otherwise
    call_remote()
    
    --[[
        Boot sequence n' availability:
            1. Load packages (core.packages)
            2. Include singleton templates (core.singletons)
            4. Require modules and configs (core.modules, core.configs)
            5. Load sync of modules
            6. Load async of modules
    ]]

    local function evaluate_path(path: string): any
        local path_parts = string.split(path, "/")
        local current = game
        for _, part in ipairs(path_parts) do
            current = current:WaitForChild(part, 0.5)
        end
        return current
    end

     -- Load packages
    local function include_packages()
        local packages = _common.replicated_storage:WaitForChild("packages")
        for _, package in ipairs(packages:GetChildren()) do
            core.packages[package.Name] = require(package)
            debug("(Package) Included:", package.Name)
        end
    end
    include_packages()

    -- Include singleton templates
    local function include_singletons()
        local singletons = _common.replicated_storage["shared"].singletons:GetChildren()
        for _, singleton in pairs(singletons) do
            core.singletons[singleton.Name] = require(singleton)
            if type(core.singletons[singleton.Name]) == "function" then
                core.singletons[singleton.Name] = core.singletons[singleton.Name](core)
            end
            debug("(Singleton) Included:", singleton.Name)
        end
    end
    include_singletons()

    -- local function load_uis()
    --     local ui_folder = _common.replicated_storage["shared"]:WaitForChild("ui")
    --     -- Require the rest of the UI elements
    --     for _, ui in ipairs(ui_folder:GetChildren()) do
    --         core.uis[ui.Name] = require(ui)
    --         debug("(UI) Included: ", ui.Name)
    --     end
        
    --     -- Load sync
    --     for ui_name, ui in core.uis do
    --         pcall(ui.load_sync, ui, core)
    --         ui.load_sync = nil
    --         debug("(UI) Loaded sync of:", ui_name)
    --     end
    --     -- Load async
    --     for ui_name, ui in core.uis do
    --         pcall(task.spawn, ui.load_async, ui, core)
    --         ui.load_async = nil
    --         debug("(UI) Loaded async of:", ui_name)
    --     end
    -- end
    -- load_uis()
    
    local function load_all_sync()
        for module_name, module in core.modules do
            if not module.load_sync then
                continue
            end
            module:load_sync(core)
            module.load_sync = nil
            debug("(Module) Loaded sync of:", module_name)
        end
    end

    local function load_all_async()
        local async_tasks = {}
        
        for module_name, module in core.modules do
            if not module.load_async then
                continue
            end
            local _task = task.spawn(function()
                module:load_async(core)
                module.load_async = nil
            end)
            debug("(Module) Called async of:", module_name)
            async_tasks[module_name] = _task
        end
        
        -- Create a separate thread to monitor async tasks
        task.spawn(function()
            -- Wait for all async tasks to complete
            for module_name, async_task in pairs(async_tasks) do
                while coroutine.status(async_task) ~= "dead" do
                    task.wait()
                end
                debug("(Module) Finished loading async of:", module_name)
            end
            -- All async tasks are done, hide the loading screen
            core:destroy_loading_screen()
            debug(string.rep("-", 10), "CORE BOOT SEQUENCE FINISHED", string.rep("-", 10), core.pretty_name)
        end)
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
                    debug("Included config:", config.Name)
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
                debug("Included module:", module.Name)
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
