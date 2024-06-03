local xp_manager = {
    xp = nil,
    level = 1
}

function xp_manager:load_sync(core)
    local subject = core:get_singleton("subject")
    local xp = subject.new()
    local event_bus = core:get_singleton("event_bus")
    self.bus = event_bus.new()
    self.config = core:get_config("xp")
    xp._data = {
        xp = 0,
        people_helped = 0
    }
    self.xp = xp
    self.hud = core.common.player_gui:WaitForChild("HUD"):WaitForChild("xp")
    self.level_hud = core.common.player_gui:WaitForChild("HUD"):WaitForChild("level")
    
    self.bus:subscribe("update_xp", function()
        xp_manager.hud.people_helped_info.Text = tostring(xp._data.people_helped)
        xp_manager.hud.xp_info.Text = tostring(xp._data.xp)
    end)
    
    self.bus:subscribe("level_up", function(level: number)
        xp_manager.level_hud.level_info.Text = "Level " .. tostring(level)
    end)
end

function xp_manager:increment_xp(amount: number)
    self.xp._data.xp += amount
    if self.level > #self.config then
        return
    end
    if self.xp._data.xp >= self.config[self.level] then
        self.level += 1
        self.bus:publish("level_up", self.level)
    end
end

function xp_manager:increment_people_helped()
    self.xp._data.people_helped += 1
end

return xp_manager