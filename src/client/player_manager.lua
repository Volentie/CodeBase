local player_manager = {
    configs = {},
    talking_npc = nil,
    last_talking_npc = nil,
    states = {
        looking_for_job = false
    }
}

function player_manager:bind_key(key: Enum.KeyCode, stage_event: string, callback: () -> any)
    local event_bus = self.core:get_singleton("event_bus")
    local bus = event_bus.new()

    local connection = function(input: InputObject)
        if input.KeyCode == key then
            callback()
        end
    end
    bus:publish("subscribe_connection", self.core.common.user_input_service, stage_event, connection)
end

function player_manager:load_async(core)
    self.core = core
    self:load_configs()
    self:bind_run()

    local xp_manager = core:get_module("xp_manager")
    
    -- Handle some bus events
    local event_bus = core:get_singleton("event_bus")
    self.bus = event_bus.new()
    
    self.bus:subscribe("looking_for_job", function(npc_model: Model)
        local prompt = npc_model:FindFirstChild("interactable_prompt")
        prompt.Enabled = false
        --prompt.Parent = self.core.common.replicated_storage.assets.temp
        -- xp_manager:increment_xp(20)
        -- self.bus:publish("update_xp")
    end)
    
    self.bus:subscribe("stop_looking_for_job", function(npc_model: Model, last_talker)
        --local prompt = npc_model:FindFirstChild("interactable_prompt")
        --prompt:Destroy()
        self.bus:publish("stop_talking")
        npc_model:FindFirstChild("interactable_prompt").Enabled = true
        self:stop_looking_for_job()
        local last_talker_prompt = last_talker.model:FindFirstChild("interactable_prompt")
        if last_talker_prompt.Enabled == false then
            last_talker_prompt.Enabled = true
        end
        xp_manager:increment_xp(20)
        self.bus:publish("update_xp")
    end)

    self.bus:subscribe("stop_talking", function(npc_model, unsub_event: string?, unsub_handler: () -> any?)
        self:stop_talking()
        -- if npc_model then
        --     if npc_model:FindFirstChild("interactable_prompt").Enabled == false then
        --         npc_model:FindFirstChild("interactable_prompt").Enabled = true
        --     end
        -- end
        if unsub_event then
            assert(unsub_handler, "unsub_handler is required")
            self.bus:unsubscribe(unsub_event, unsub_handler)
        end
    end)
end

function player_manager:load_configs()
    local config = self.core:get_config("player")
    local load_config = config.load

    for key, value in pairs(load_config) do
        local i = key:sub(1, 1)
        local j = key:match("^.+_(.)")
        local humanoid_property = key:gsub("^%w(.+)_%w(.+)", i:upper().."%1"..j:upper().."%2")
        self.core.common.humanoid[humanoid_property] = value
        self.configs[key] = value
    end
    config.load = nil

    for key, value in pairs(config) do
        self.configs[key] = value
    end
end

function player_manager:bind_run(key: Enum.KeyCode)
    key = key or Enum.KeyCode.LeftShift
    local player = self.core.common.local_player
    
    local player_run_speed = self.configs.run_speed
    
    if self.core.common.run_service:IsStudio() then
        player_run_speed *= 2
    end

    self:bind_key(key, "InputBegan", function()
        player.Character.Humanoid.WalkSpeed = player_run_speed
    end)

    self:bind_key(key, "InputEnded", function()
        player.Character.Humanoid.WalkSpeed = self.configs.walk_speed
    end)
end

function player_manager:switch_state(state: string): boolean
    local _state = self.states[state]
    assert(_state ~= nil, "State not found")
    self.states[state] = not _state
    return _state
end

function player_manager:get_state(state: string): boolean
    assert(self.states[state] ~= nil, "State not found")
    return self.states[state]
end

function player_manager:set_talking_npc(npc)
    self.talking_npc = npc
end

function player_manager:get_talking_npc()
    return self.talking_npc
end

function player_manager:is_talking()
    return self.talking_npc ~= nil
end

function player_manager:stop_talking()
    self.talking_npc = nil
end

function player_manager:look_for_job(): boolean
    self:switch_state("looking_for_job")
    return true
end

function player_manager:is_looking_for_job()
    return self:get_state("looking_for_job")
end

function player_manager:stop_looking_for_job(): boolean
    self:switch_state("looking_for_job")
    return false
end

function player_manager:set_last_talking_npc(npc)
    self.last_talking_npc = npc
end

function player_manager:get_last_talking_npc()
    return self.last_talking_npc
end

return player_manager