local component = {
    storage = {},
}
component.__index = component

local Roact = nil

function component.new(rbx_component: string, id: string, props: () -> (), init: (any) -> nil)
    assert(rbx_component, "Roblox UI component wasn't provided")
    assert(props, "Props weren't provided")
    assert(id, "ID wasn't provided")
    assert(component.storage[id] == nil, "Component with the same ID already exists")

    local self = setmetatable({}, component)

    self.___r = Roact.Component:extend(id)
    -- Element reference
    self.___e = nil
    self.id = id
    
    local roact_component = self.___r
    
    if init then
        roact_component.init = init
    end

    function roact_component:render()
        return Roact.createElement(rbx_component, props(self))
    end
    
    -- Set mounted state to false
    self.mounted = false

    return self
end

function component:show(screen_gui: GuiObject?, props: {any}?): boolean
    screen_gui = screen_gui or game.Players.LocalPlayer.PlayerGui.HUD
    if not self.___e then
        self.___e = Roact.createElement(self.___r, props)
    end
    
    if self.mounted == false then
        self.mounted = true
        Roact.mount(self.___e, screen_gui)
        return true
    end

    self.mounted = false
    Roact.unmount(self.___e, screen_gui)
    return true
end

function component:load_sync(core)
    local event_bus = core:get_singleton("event_bus")
    local bus = event_bus.new()
    Roact = core.packages.roact

    

end

return component