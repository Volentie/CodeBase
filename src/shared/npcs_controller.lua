-- Table that will contain all the npcs in the game
local npcs_controller = {
    objects = {}
}

function npcs_controller:boot(_shared: table)
    local npcs_config = _shared.npcs_config
    function npcs_controller:load_instances(): boolean
        for _, model in ipairs(workspace:WaitForChild("NPCs"):GetChildren()) do
            local model_id = model.Name
            local model_config = npcs_config[model_id] or npcs_config[model:GetAttribute("npc_id")]
            if not model_config then
                warn("No configuration found for npc with id: " .. model_id)
                return false
            else
                table.insert(npcs_controller.objects, {
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

function npcs_controller:run(_shared: table)
    local objects = self.objects
    _shared:play_animation(objects[1].model, objects[1].animation_path)
end

return npcs_controller