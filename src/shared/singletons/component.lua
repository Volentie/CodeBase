local component = {
    templates = {},
    global = {}
}
component.__index = component

local core = nil

function component:evaluate_templates()
    assert(core, "Core not set")

    self.Roact = core.packages.roact
    local Roact = self.Roact
    
    local empty_ret = function()end

    --[[
        Button.lua
    ]]
    local Button = Roact.Component:extend("Button")

    function Button:render()
        return Roact.createElement("TextButton", {
            Text = self.props.text,
            BackgroundColor3 = self.props.color or Color3.fromRGB(33, 150, 243),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            AutoButtonColor = false,
            Size = self.props.size or UDim2.new(0, 200, 0, 50),
            Font = self.props.font or Enum.Font.SourceSansBold,
            TextSize = self.props.textSize or 16,
            [Roact.Event.Activated] = self.props.onClick
        }, self.props[Roact.Children])
    end

    --[[
        Card.lua
    ]]
    local Card = Roact.Component:extend("Card")

    function Card:render()
        return Roact.createElement("Frame", {
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0,
            Size = self.props.size or UDim2.new(0, 200, 0, 300),
            [Roact.Event.MouseEnter] = self.props.onHover
        }, {
            Title = Roact.createElement("TextLabel", {
                Text = self.props.title,
                Font = Enum.Font.SourceSansBold,
                TextSize = 20,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 30),
                TextColor3 = Color3.fromRGB(33, 33, 33)
            }),
            Content = Roact.createElement("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, -30),
                LayoutOrder = 2
            }, self.props[Roact.Children])
        })
    end

    --[[
        TextField.lua
    ]]
    local TextField = Roact.Component:extend("TextField")

    function TextField:render()
        return Roact.createElement("Frame", {
            BackgroundTransparency = 1,
            Size = self.props.size or UDim2.new(0, 200, 0, 40),
            LayoutOrder = self.props.layoutOrder or 1
        }, {
            TextBox = Roact.createElement("TextBox", {
                Text = self.props.text or "",
                PlaceholderText = self.props.placeholder,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Font = self.props.font or Enum.Font.SourceSans,
                TextSize = self.props.textSize or 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Color3.fromRGB(33, 33, 33),
                [Roact.Event.FocusLost] = self.props.onBlur or empty_ret(),
                [Roact.Event.FocusGained] = self.props.onFocus or empty_ret()
            }),
            Label = Roact.createElement("TextLabel", {
                Text = self.props.label or "Hello, World!",
                Font = self.props.font or Enum.Font.SourceSansBold,
                TextSize = self.props.textSize or 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20),
                TextColor3 = Color3.fromRGB(33, 33, 33),
                Position = UDim2.new(0, 0, 0, -20),
                Visible = self.props.label and true or false
            })
        })
    end

    --[[
        Checkbox.lua
    ]]
    local Checkbox = Roact.Component:extend("Checkbox")

    function Checkbox:render()
        return Roact.createElement("TextButton", {
            BackgroundColor3 = self.props.checked and Color3.fromRGB(33, 150, 243) or Color3.fromRGB(211, 211, 211),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 20, 0, 20),
            AutoButtonColor = false,
            [Roact.Event.Activated] = function()
                self.props.onChange(not self.props.checked)
            end
        }, {
            CheckIcon = Roact.createElement("ImageLabel", {
                BackgroundTransparency = 1,
                Image = "rbxassetid://6031090995",
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(0.5, -8, 0.5, -8),
                Visible = self.props.checked
            })
        })
    end

    --[[
        RadioButton.lua
    ]]
    local RadioButton = Roact.Component:extend("RadioButton")

    function RadioButton:render()
        return Roact.createElement("TextButton", {
            BackgroundColor3 = self.props.checked and Color3.fromRGB(33, 150, 243) or Color3.fromRGB(211, 211, 211),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 20, 0, 20),
            AutoButtonColor = false,
            [Roact.Event.Activated] = function()
                self.props.onChange(self.props.value)
            end
        }, {
            CheckIcon = Roact.createElement("Frame", {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                Size = UDim2.new(0, 12, 0, 12),
                Position = UDim2.new(0.5, -6, 0.5, -6),
                Visible = self.props.checked
            })
        })
    end

    -- Register base templates global
    self.templates["Button"] = Button
    self.templates["Card"] = Card
    self.templates["TextField"] = TextField
    self.templates["Checkbox"] = Checkbox
    self.templates["RadioButton"] = RadioButton
end

function component.new(id: string, base_component: string, props: {})
    assert(component.templates[base_component], "Component not found in templates")
	local self = setmetatable({}, component)

    local base = self.templates[base_component]
    
    -- WARP
    if self.global[id] then
        local function pick_unique_id()
            math.randomseed(tick())
            id = id .. "_" .. math.random(1000)
            if self.global[id] then
                return pick_unique_id()
            end
            return id
        end
        pick_unique_id()
    end

    self.global[id] = self.Roact.createElement(base, props)
    
    self.object = self.global[id]

	return self
end

function component:mount(screen_gui: GuiObject)
    screen_gui = screen_gui or core.common.player_gui
    self.Roact.mount(self.object, screen_gui)
end

return function(_core)
    assert(_core, "Core wasn't provided")
    core = _core
    component:evaluate_templates()
    return component
end