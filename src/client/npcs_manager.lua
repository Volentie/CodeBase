-- Table that will contain all the npcs in the game
local npcs_manager = {
    objects = {},
}

function npcs_manager.new(data: table)
    local self = setmetatable(data, {__index = npcs_manager})

    local npcs_config = self.core:get_config("npcs")
    local npc_config = npcs_config[data["name"]]
    assert(npc_config, "NPC not found in npcs config")
 
    local animation_manager = self.core:get_module("animation_manager")

    function self:try_load_animation()
        if not npc_config.animation_path then
            return
        end
        animation_manager:play_animation(self.model, npc_config.animation_path)
        return true
    end

    table.insert(npcs_manager.objects, self)

    return self
end

function npcs_manager:connect_lookat_player()
    -- Make this model look at the player
    local npc_model = self.model
    local tween_service = self.core.common.tween_service
    local tween_info = TweenInfo.new(0.5, Enum.EasingStyle.Cubic)

    local event_bus = self.core:get_singleton("event_bus")
    local bus = event_bus.new()

    local cframe_value = Instance.new("CFrameValue")
    cframe_value.Value = npc_model:GetPivot()

    cframe_value.Changed:Connect(function(value)
        npc_model:PivotTo(value)
    end)

    bus:publish("subscribe_connection", self.core.common.run_service, "RenderStepped", function()
        local humanoid = self.core.common.humanoid
        if humanoid.MoveDirection.Magnitude <= 0 then
            return
        end
        
        local player_pos = self.core.common.humanoid_root_part.Position
        local npc_pos = npc_model:GetPivot().Position
        local target_cframe = CFrame.new(npc_pos, player_pos)
        local tween_goal = {
            Value = target_cframe
        }
    
        if self.tween then
            self.tween:Cancel()
            self.tween = nil
        end
        
        self.tween = tween_service:Create(cframe_value, tween_info, tween_goal)
        
        self.tween.Completed:Connect(function()
            self.tween = nil
        end)

        self.tween:Play()
    end)
end

function npcs_manager:give_random_food()
    local tools_folder = self.core.common.replicated_storage.tools
    math.randomseed(tick())
    local rand_food = tools_folder:GetChildren()[math.random(1, #tools_folder:GetChildren())]
    local asset_object = rand_food:Clone()
    asset_object.Parent = self.core.common.local_player.Backpack
end

function npcs_manager:create_n_calculate_path(npc, target_pos)
    local path = self.core.common.pathfinding_service:CreatePath()
    path:ComputeAsync(npc.HumanoidRootPart.Position, target_pos)
    return path
end

function npcs_manager:donate_food_to_needy()
    local needy_npc = self.model
    local tool_equipped = self.core.common.character:FindFirstChildWhichIsA("Tool")
    if not tool_equipped then
        warn("No tool equipped")
        return
    end

    tool_equipped:Destroy()
    local needy_npc_pos = needy_npc.HumanoidRootPart.Position
    local ngos = self.core.common.city_folder.NGOs:GetChildren()
    local nearest_distance = {Magnitude = math.huge}
    for _, ngo in ipairs(ngos) do
        local ngo_pos = ngo:GetPivot().Position
        local distance = (ngo_pos - needy_npc_pos)
        if distance.Magnitude < nearest_distance.Magnitude then
            nearest_distance = distance
        end
    end

    -- Calculate the path
    local path = self:create_n_calculate_path(needy_npc, nearest_distance)
    if path.Status == Enum.PathStatus.NoPath then
        warn("No path found")
        return
    end
    -- Move the npc
    for _, point in ipairs(path:GetWaypoints()) do
        needy_npc.Humanoid:MoveTo(point.Position)
        needy_npc.Humanoid.MoveToFinished:Wait()
    end
end

function npcs_manager:connect_prompt_triggered(data)
    local event_bus = self.core:get_singleton("event_bus")
    local bus = event_bus.new()
    local callback = data.callback
    local prompt = data.prompt
    assert(callback, "Callback not provided")
    assert(prompt, "Prompt not provided")

    bus:publish("subscribe_connection", prompt, "Triggered", callback)
end

function npcs_manager:load_npcs()
    if getmetatable(self) then
        warn("Trying to load npcs from an instance of npcs_manager")
        return
    end

    local folder = self.core.common.npcs_folder
    local descendants = folder:GetDescendants()
    for _, npc in ipairs(descendants) do
        -- Positive checking =)
        if npc:IsA("Model") then
            local npc_instance = npcs_manager.new({
                name = npc.Name,
                model = npc
            })

            npc_instance:try_load_animation()
        end
    end
end

-- Filter function
function npcs_manager:load_onto(npc_type, callback: (npc: table) -> any)
    for _, npc_object in ipairs(npcs_manager.objects) do
        if npc_object.name:find(npc_type) then
            callback(npc_object)
        end
    end
end

function npcs_manager:load_async(_core)
    self.core = _core
    
    -- Load npcs
    self:load_npcs()

    -- Load npcs behaviours
    self:load_onto("seller", function(npc)
        npc:connect_lookat_player()
        npc:connect_prompt_triggered({
            prompt = npc.model:FindFirstChildWhichIsA("ProximityPrompt"),
            callback = function()
                npc:give_random_food()
            end
        })
    end)
    
    self:load_onto("needy", function(npc)
        local prompt = Instance.new("ProximityPrompt")
        prompt.HoldDuration = 0.5
        prompt.ActionText = "Give Food"
        prompt.ObjectText = "Homeless"
        prompt.MaxActivationDistance = 5
        prompt.Name = "interact"
        prompt.Parent = npc.model

        npc:connect_prompt_triggered({
            prompt = prompt,
            callback = function()
                npc:donate_food_to_needy()
            end
        })
    end)
end

return npcs_manager