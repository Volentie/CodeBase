local component = {
    global = {},
    templates = {}
}
component.__index = component

local Roact

function component.evaluate_templates(core)
    Roact = core.packages.roact

    local Topbar = Roact.Component:extend("Topbar")
    function Topbar:render()
        return Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 50),
            BackgroundColor3 = Color3.fromHex("#331133"),
            BorderSizePixel = 0,
        }, {
            Title = Roact.createElement("TextLabel", {
                Text = self.props.text,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                TextColor3 = Color3.fromHex("#111111"),
                TextSize = 24,
                Font = Enum.Font.SourceSans,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
            })
        })
    end

    local MaterialButton = Roact.Component:extend("MaterialButton")
    function MaterialButton:render()
        return Roact.createElement("TextButton", {
            Text = self.props.text,
            Size = UDim2.new(0, 200, 0, 50),
            BackgroundColor3 = Color3.fromHex("#331133"),
            TextColor3 = Color3.fromHex("#111111"),
            Font = Enum.Font.SourceSans,
            TextSize = 20,
            [Roact.Event.Activated] = self.props.onActivated,
        })
    end

    local MaterialTextField = Roact.Component:extend("MaterialTextField")
    function MaterialTextField:render()
        return Roact.createElement("TextBox", {
            PlaceholderText = self.props.placeholder,
            Size = UDim2.new(0, 200, 0, 50),
            BackgroundColor3 = Color3.fromHex("#111111"),
            TextColor3 = Color3.fromHex("#111111"),
            Font = Enum.Font.SourceSans,
            TextSize = 18,
            ClearTextOnFocus = false,
            Text = self.props.text,
        })
    end

    local MaterialCheckbox = Roact.Component:extend("MaterialCheckbox")
    function MaterialCheckbox:init()
        self.state = {checked = self.props.checked}
    end
    function MaterialCheckbox:render()
        return Roact.createElement("TextButton", {
            Size = UDim2.new(0, 24, 0, 24),
            BackgroundColor3 = self.state.checked and Color3.fromHex("#331133") or Color3.fromHex("#111111"),
            Text = "",
            [Roact.Event.Activated] = function()
                self:setState({checked = not self.state.checked})
                if self.props.onChecked then
                    self.props.onChecked(self.state.checked)
                end
            end,
        })
    end

    local MaterialCard = Roact.Component:extend("MaterialCard")
    function MaterialCard:render()
        return Roact.createElement("Frame", {
            Size = UDim2.new(0, 300, 0, 200),
            BackgroundColor3 = Color3.fromHex("#111111"),
            BorderSizePixel = 0,
            ClipsDescendants = true,
        }, self.props[Roact.Children])
    end

    local MaterialSlider = Roact.Component:extend("MaterialSlider")
    function MaterialSlider:render()
        return Roact.createElement("Frame", {
            Size = UDim2.new(0, 200, 0, 20),
            BackgroundColor3 = Color3.fromHex("#111111"),
        }, {
            SliderButton = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(self.props.value or 0.5, -10, 0.5, -10),
                BackgroundColor3 = Color3.fromHex("#331133"),
                Text = "",
            })
        })
    end

    local MaterialSwitch = Roact.Component:extend("MaterialSwitch")
    function MaterialSwitch:init()
        self.state = {on = self.props.on}
    end
    function MaterialSwitch:render()
        return Roact.createElement("TextButton", {
            Size = UDim2.new(0, 40, 0, 20),
            BackgroundColor3 = self.state.on and Color3.fromHex("#331133") or Color3.fromHex("#111111"),
            Text = "",
            [Roact.Event.Activated] = function()
                self:setState({on = not self.state.on})
                if self.props.onStateChanged then
                    self.props.onStateChanged(self.state.on)
                end
            end,
        }, {
            SwitchKnob = Roact.createElement("Frame", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = self.state.on and UDim2.new(1, -20, 0, 0) or UDim2.new(0, 0, 0, 0),
                BackgroundColor3 = Color3.fromHex("#111111"),
            })
        })
    end

    local MaterialDialog = Roact.Component:extend("MaterialDialog")
    function MaterialDialog:render()
        return Roact.createElement("Frame", {
            Size = UDim2.new(0, 300, 0, 200) or self.props.size,
            BackgroundColor3 = Color3.fromHex("#111111") or self.props.background_color,
            BackgroundTransparency = 0.8 or self.props.transparency,
            BorderSizePixel = 0 or self.props.border_size,
            ClipsDescendants = true or self.props.clips_descendants,
        }, {
            Title = Roact.createElement("TextLabel", {
                Text = self.props.title,
                Size = UDim2.new(1, 0, 0, 50) or self.props.title_size,
                BackgroundColor3 = Color3.fromHex("#331133") or self.props.title_background_color,
                BackgroundTransparency = self.props.title_background_transparency or 0.8,
                TextColor3 = Color3.fromHex("#111111") or self.props.title_text_color,
                TextSize = 20 or self.props.title_text_size,
                Font = Enum.Font.SourceSans or self.props.title_font,
            }),
            Content = Roact.createElement("Frame", {
                Size = self.props.content_size or UDim2.new(1, 0, 1, -50),
                Position = self.props.content_position or UDim2.new(0, 0, 0, 50),
                BackgroundTransparency = self.props.content_transparency or 0.2, -- STOP
            }, self.props[Roact.Children] or self.props.content_children)
        })
    end

    component.templates["Topbar"] = Topbar
    component.templates["MaterialButton"] = MaterialButton
    component.templates["MaterialTextField"] = MaterialTextField
    component.templates["MaterialCheckbox"] = MaterialCheckbox
    component.templates["MaterialCard"] = MaterialCard
    component.templates["MaterialSlider"] = MaterialSlider
    component.templates["MaterialSwitch"] = MaterialSwitch
    component.templates["MaterialDialog"] = MaterialDialog

    --[[
        Topbar props:
            text: string
        MaterialButton props:
            text: string
            onActivated: function
        MaterialTextField props:
            placeholder: string
            text: string
        MaterialCheckbox props:
            checked: boolean
            onChecked: function
        MaterialCard props:
            none
        MaterialSlider props:
            value: number
        MaterialSwitch props:
            on: RoactBinding
            onStateChanged: function
        MaterialDialog props:
            title: string
            size: UDim2
            background_color: Color3
            transparency: number
            border_size: number
            clips_descendants: boolean
            title_size: UDim2
            title_background_color: Color3
            title_text_color: Color3
            title_text_size: number
            title_font: Enum.Font
            content_size: UDim2
            content_position: UDim2
            content_transparency: number
            content_children: RoactChildren
    ]]
end

function component.new(id: string, base_component: string, props: {})
    assert(component.templates[base_component], "Component not found in templates (" .. base_component .. ")")
    assert(props, "Props weren't provided")
    assert(id, "ID wasn't provided")

    local self = setmetatable({}, component)

    local base = self.templates[base_component]

    if self.global[id] then
        error("ID already exists")
    end

    self.global[id] = Roact.createElement(base, props)

    self.object = self.global[id]

    return self
end

function component:get(template: string, ...)
    assert(template and type(template) == "string", "Template wasn't provided or it's type is wrong")

    local available_templates = {
        Dialog = component.new("needy_dialog_1", "MaterialDialog", {
            title = select(1, ...) or "",
            title_background_transparency = 0.5,
            transparency = 0.6
        }),
    }
    
    assert(available_templates[template], "Template not found")
    
    return available_templates[template]
end

function component:show(screen_gui: GuiObject)
    screen_gui = screen_gui or self.core.common.player_gui.HUD
    if not self.mounted then
        self.mounted = true
        Roact.mount(self.object, screen_gui)
    end
end

return function(core)
    assert(core, "Core wasn't provided")
    component.core = core
    component.evaluate_templates(core)
    return component
end