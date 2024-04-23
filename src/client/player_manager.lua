local player_manager = {
    configs = {}
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

    self:bind_key(key, "InputBegan", function()
        player.Character.Humanoid.WalkSpeed = self.configs.run_speed
    end)

    self:bind_key(key, "InputEnded", function()
        player.Character.Humanoid.WalkSpeed = self.configs.walk_speed
    end)
end

function player_manager:load_async(core)
    self.core = core
    self:load_configs()
    self:bind_run()
end

return player_manager