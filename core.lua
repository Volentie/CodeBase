-- Loc stands for local
local alias = setmetatable({
    _cache = {}
}, {
    __call = function(t, key)
        key = string.gsub(key, key:split("_"):rep() )
        if not t._cache[key] then
            t._cache[key] = game:GetService(key)
        end
        return t._cache[key]
    end
}
    
--=== CONFIG
-- Core will look for modules in the (uncommented) following paths
local folder_struct = {
    --Server = "ServerScriptService/Server",
    Client = "StarterPlayer/StarterPlayerScripts/Client",
    Shared = "ReplicatedStorage/Shared"
}

local core = {
    modules = {}
}

function core:evaluate_path(path: string): Instance
    local path_split = path:split("/")
    local recursive_eval = game
    for _, path in path_split do
        recursive_eval = recursive_eval:WaitForChild(path)
    end
    return recursive_eval
end

-- Shared table to be used across all modules
function core:load_shared(): ()
    local utils = {
        compare_str_lower = function(str1, str2)
            return str1:lower() == str2:lower()
        end,
        compare_str_upper = function(str1, str2)
            return str1:upper() == str2:upper()
        end
    }

    self._shared = setmetatable({
        npcs_config = require(core:evaluate_path("ReplicatedStorage/Configs/npcs_config")),
        animations_config = require(core:evaluate_path("ReplicatedStorage/Configs/animations_config")),
        local_player = services.players.LocalPlayer,
        local_character = services.players.LocalPlayer.Character or services.players.LocalPlayer.CharacterAdded:Wait(),
        local_humanoid = services.players.LocalPlayer.Character:WaitForChild("Humanoid"),
        local_root_part = services.players.LocalPlayer.Character:WaitForChild("HumanoidRootPart")
    }, {
        __index = function(_, key)
            return services[key]
        end
    })
end

function core:load_modules(): ()
    -- Load shared table and it's initial values
    self:load_shared()
    
    -- Boot the modules
    for _, path in folder_struct do
        local instance = self:evaluate_path(path)
        for _, module in ipairs(instance:GetChildren()) do
            local module_name = module.Name
            module = require(module)
            module:boot(self._shared)
            self.modules[module_name] = module
        end
    end

    -- Set the shared table to have access to the modules' tables and keys/values
    setmetatable(self._shared, {
        __index = function(_, key)
            for _, module in self.modules do
                if module[key] then
                    return module[key]
                end
            end
        end
    })

    -- Run the modules if they have the 'Run' function, passing the shared table
    -- now having access to the modules' table and keys/values evaluated until now
    for _, module in self.modules do
        if module.run then
            module:run(self._shared)
        end
    end
    
    -- Call the 'live' method on the modules if they have it
    -- This is useful for modules that need to run code after and with the assurance that the client and the initial Instances in the game
    -- have finished loading.
    for _, module in self.modules do
        if module.live then
            if not game:IsLoaded() then
                game.Loaded:Wait()
            end
            module:live(self._shared)
        end
    end
            
end

core:load_modules()