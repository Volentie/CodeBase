local xp_manager = {
    xp = nil
}

function xp_manager:load_sync(core)
    local subject = core:get_singleton("subject")
    local xp = subject.new()
    xp._data = {
        xp = 0,
        people_helped = 0
    }
    self.xp = xp
    self.hud = core.common.player_gui:WaitForChild("HUD"):WaitForChild("xp")
end

return xp_manager