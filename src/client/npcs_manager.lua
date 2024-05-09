-- Table that will contain all the npcs in the game
local npcs_manager = {
    objects = {},
}

function npcs_manager.new(data: table)
    local self = setmetatable(data, {__index = npcs_manager})

    local npcs_config = self.core:get_config("npcs")
    local npc_config = npcs_config[data["id"]]
    assert(npc_config, "NPC not found in npcs config")
    
    local animation_manager = self.core:get_module("animation_manager")

    function self:try_load_animation()
        if not npc_config.animation_path then
            return
        end
        local animator = Instance.new("Animator")
        animator.Parent = self.model.Humanoid

        self.animation = animation_manager:play_animation(self.model, npc_config.animation_path)
        self.animation_playing = true

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
        
        if self.animation_playing then
            self.animation:Stop()
            self.animation_playing = false
        else
            self.animation:Play()
        end
        
        local player_pos = self.core.common.humanoid_root_part.Position
        local npc_pos = npc_model:GetPivot().Position
        local target_pos = Vector3.new(player_pos.X, npc_pos.Y, player_pos.Z)
        local target_cframe = CFrame.new(npc_pos, target_pos)
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
    local path = self.core.common.pathfinding_service:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        Costs = {
            Water = 10,
            Grass = 1
        },
        IncludeWaypoints = true,
        WaypointSpacing = 5
    })
    
    path:ComputeAsync(npc.HumanoidRootPart.Position, target_pos)
    
    return path
end

function npcs_manager:change_parts_collision_group(group_name: string)
    for _, part in ipairs(self.model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = group_name
        end
    end
end

function npcs_manager:donate_food_to_needy()
    local needy_npc = self.model
    local tool_equipped = self.core.common.character:FindFirstChildWhichIsA("Tool")
    if not tool_equipped then
        return
    end

    local prompt = needy_npc:FindFirstChildWhichIsA("ProximityPrompt")
    prompt:Destroy()

    -- Give the tool (food) to the npc
    needy_npc.Humanoid:EquipTool(tool_equipped)
    tool_equipped:Destroy()
    
    if self.animation_playing then
        self.animation:Stop()
        self.animation_playing = false
    end

    local ngos = workspace.NGOs:GetChildren()
    local nearest_distance = {Magnitude = math.huge}
    local nearest_ngo
    for _, ngo in ipairs(ngos) do
        local entrance_pos = ngo["corrimao.001"]:FindFirstChildWhichIsA("Attachment").WorldPosition
        local distance = (entrance_pos - needy_npc:GetPivot().Position)
        if distance.Magnitude < nearest_distance.Magnitude then
            nearest_distance = distance
            nearest_ngo = ngo
        end
    end

    -- Calculate the path
    local path = self:create_n_calculate_path(needy_npc, nearest_ngo["corrimao.001"]:FindFirstChildWhichIsA("Attachment").WorldPosition)
    if path.Status == Enum.PathStatus.NoPath then
        warn("No path found")
        return
    end

    -- Make the npc collide only with the ground
    self:change_parts_collision_group("npc_walk_mode")
    
    -- Play the default roblox walk animation on the npc
    local animator = needy_npc.Humanoid:FindFirstChildOfClass("Animator")
    local animation = needy_npc["Animate"]["walk"]:GetChildren()[1]
    
    local animation_track = animator:LoadAnimation(animation)
    animation_track:Play()

    local waypoints = path:GetWaypoints()
    local next_waypoint_index = 1
    local humanoid = needy_npc.Humanoid

    local function move_to_next_waypoint()
        if next_waypoint_index <= #waypoints then
            local waypoint = waypoints[next_waypoint_index]
            
            humanoid:MoveTo(waypoint.Position)
            
            local connection
            connection = humanoid.MoveToFinished:Connect(function(reached)
                if reached then
                    next_waypoint_index = next_waypoint_index + 1
                    connection:Disconnect()
                    move_to_next_waypoint()
                end
            end)
        else
            -- Reached the last waypoint
            self:change_parts_collision_group("Default")
            
            -- Stop walk animation
            animation_track:Stop()
            
            -- Make the needy npc disappear
            for _, descendant in ipairs(needy_npc:GetDescendants()) do
                local ok = pcall(function() return descendant["Transparency"] end)
                if ok then
                    local tween = self.core.common.tween_service:Create(descendant, TweenInfo.new(0.5), {Transparency = 1})
                    tween.Completed:Connect(function()
                        tween:Destroy()
                        tween = nil
                    end)
                    tween:Play()
                end
            end
        end
    end

    move_to_next_waypoint()
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
    
    --[[
        needy_names:
            Armars, Arkan, Atticus, Audrey, Ben, Jason, Jonathan, Juan, Leila, Priya, Richard, Rina, Yung Li, Elijah
        civils_names:
            Beth, Charlie, Dan, Joe, Lilly, Mary, Nick, Oliver, Sakura, Sam
        seller_names:
            Elizabeth, Geroge, Hercules, Lucy, Michele, Mike
    ]]

    local folder = self.core.common.npcs_folder
    local descendants = folder:GetDescendants()
    for _, npc in ipairs(descendants) do
        -- Positive checking =)
        if npc:IsA("Model") then
            local npc_name = npc:GetAttribute("name")
            if npc.Name ~= npc_name then
                npc.Name = npc_name
                warn("Name attribute doesn't match the name attribute of the npc model:\t\t", npc_name, npc.Name)
            end

            local npc_instance = npcs_manager.new({
                id = npc:GetAttribute("id"),
                model = npc,
                name = npc_name
            })

            npc_instance:try_load_animation()
        end
    end
end

function npcs_manager:load_async(_core)
    self.core = _core

    -- Get component singleton
    local component = self.core:get_singleton("component")

    -- Load npcs
    self:load_npcs()

    -- Load npcs behaviours
    self.core.filter_call(
        function(npc)
            return npc.model:GetAttribute("id") == "seller_v1"
        end,
        function(npc)
            local prompt = Instance.new("ProximityPrompt")
            prompt.HoldDuration = 0.5
            prompt.ActionText = "Interact"
            prompt.ObjectText = "Interact with " .. npc.model:GetAttribute("name")
            prompt.MaxActivationDistance = 5
            prompt.Name = "interact"
            prompt.Parent = npc.model
            
            npc:connect_lookat_player()
            
            npc:connect_prompt_triggered({
                prompt = prompt,
                callback = function()
                    npc:give_random_food()
                end
            })
        end
    )(
        function(predicate, callback)
            for _, npc in ipairs(npcs_manager.objects) do
                if predicate(npc) then
                    callback(npc)
                end
            end
        end
    )

    self.core.filter_call(
        function(npc)
            return npc.model:GetAttribute("id") == "needy_v1"
        end,
        function(npc)
            local prompt = Instance.new("ProximityPrompt")
            prompt.HoldDuration = 0.5
            prompt.ActionText = "Speak"
            prompt.ObjectText = "Speak with " .. npc.model:GetAttribute("name")
            prompt.MaxActivationDistance = 5
            prompt.Name = "interact"
            prompt.Parent = npc.model
    
            npc:connect_prompt_triggered({
                prompt = prompt,
                callback = function()
                    component:get("Dialog", npc.name):show()
                    --npc:donate_food_to_needy()
                end
            })
        end
    )(
        function(predicate, callback)
            for _, npc in ipairs(npcs_manager.objects) do
                if predicate(npc) then
                    callback(npc)
                end
            end
        end
    )

end

return npcs_manager