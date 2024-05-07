local hud = {}

function hud:load_async(core)
    local component = core.singletons.component
    local hud_gui = core.common.player_gui.HUD
    local t_field = component.new("test", "Button", {
        text = "Any"
    })
    
    t_field:mount(hud_gui)
end

return hud