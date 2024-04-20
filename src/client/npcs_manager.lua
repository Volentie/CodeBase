-- Table that will contain all the npcs in the game
local npcs_manager = {
    objects = {}
}

function npcs_manager:load_sync(core)
    local npcs_config = core:get_config("npcs")
    function npcs_manager:load_instances(): boolean
        for _, model in ipairs(workspace:WaitForChild("NPCs"):GetChildren()) do
            local model_id = model.Name
            local model_config = npcs_config[model_id] or npcs_config[model:GetAttribute("npc_id")]
            if not model_config then
                warn("No configuration found for npc with id: " .. model_id)
                return false
            else
                table.insert(npcs_manager.objects, {
                    model = model,
                    animation_path = model_config.animation_path,
                    name = model.Name
                })
                return true
            end
        end
        return false
    end
    
    self:load_instances()
end

function npcs_manager:load_async(core)
    local animation_manager = core:get_module("animation_manager")
    local objects = self.objects
    animation_manager:play_animation(objects[1].model, objects[1].animation_path)
end

return npcs_manager