local TweenService = game:GetService("TweenService")
-- Table that will contain all the npcs in the game
local npcs_manager = {
    objects = {}
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
        -- Make the sidewalks the best choice to walk onto (default = 1, set higher for those should be ignored)
        Costs = {
            Pavement = 1,
            Water = 10,
            Grass = 5
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

function npcs_manager:move_to_next_waypoint(next_waypoint_index, waypoints, humanoid, and_then)
    if next_waypoint_index <= #waypoints then
        local waypoint = waypoints[next_waypoint_index]
        humanoid:MoveTo(waypoint.Position)
        local connection
        connection = humanoid.MoveToFinished:Connect(function(reached)
            if reached then
                next_waypoint_index = next_waypoint_index + 1
                connection:Disconnect()
                self:move_to_next_waypoint(next_waypoint_index, waypoints, humanoid, and_then)
            end
        end)
    else
        and_then()
    end
end

function npcs_manager:donate_food_to_needy()
    local needy_npc = self.model
    local tool_equipped = self.core.common.character:FindFirstChildWhichIsA("Tool")
    if not tool_equipped then
        local msg = game.Players.LocalPlayer.PlayerGui.HUD.info_1.text
        msg.Text = "You need to have a food equipped to donate it!"
        local show = TweenService:Create(msg, TweenInfo.new(1), {TextTransparency = 0})
        show.Completed:Connect(function()
            show:Destroy()
            show = nil
            TweenService:Create(msg, TweenInfo.new(1), {TextTransparency = 1}):Play()
        end)
        show:Play()
        return
    end
    
    -- Pass
    local data = self.subject._data
    self.subject:notify({
        xp = data.xp + 10,
        people_helped = data.people_helped + 1
    })

    -- Give the tool (food) to the npc
    needy_npc.Humanoid:EquipTool(tool_equipped)
    tool_equipped:Destroy()
    
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
    
    
    local animation_manager = self.core:get_module("animation_manager")
    
    local waypoints = path:GetWaypoints()
    local next_waypoint_index = 1
    local humanoid = needy_npc.Humanoid

    -- Set Anchored to false for this npc to be able to move
    needy_npc["HumanoidRootPart"].Anchored = false
   
    -- Stop sit animation
    if self.animation_playing then
        self.animation:Stop()
        self.animation_playing = false
    end
    
    -- Wait some seconds so the player can see the npc before it starts walking
    task.wait(1.7)
    
    -- Play walk animation
    animation_manager:play_animation(needy_npc, "kinetic/walk")
    local walkAnim = needy_npc.Humanoid:GetPlayingAnimationTracks()[1]
    walkAnim.Priority = Enum.AnimationPriority.Action

    self:move_to_next_waypoint(next_waypoint_index, waypoints, humanoid, function()
        local last_tween = nil
        for _, descendant in ipairs(needy_npc:GetDescendants()) do
            local ok = pcall(function() return descendant["Transparency"] end)
            if ok then
                local tween = self.core.common.tween_service:Create(descendant, TweenInfo.new(0.5), {Transparency = 1})
                tween.Completed:Connect(function()
                    tween:Destroy()
                    tween = nil
                end)
                tween:Play()
                last_tween = tween
            end
        end
        last_tween.Completed:Connect(function()
            needy_npc:Destroy()
        end)
    end)
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
    for _, npc_model in ipairs(descendants) do
        -- Positive checking =)
        if npc_model:IsA("Model") then
            local npc_name = npc_model:GetAttribute("name")
            if npc_model.Name ~= npc_name then
                npc_model.Name = npc_name
                warn("Name attribute doesn't match the name attribute of the npc model:\t\t", npc_name, npc_model.Name)
            end

            local npc_instance = npcs_manager.new({
                id = npc_model:GetAttribute("id"),
                model = npc_model,
                name = npc_name
            })
            npc_instance:try_load_animation()
        end
    end
end


function npcs_manager:get_road_attachments(eliminate: table?)
    local road_atts = {}
    local road_folder = workspace.Road
    for _, model in ipairs(road_folder:GetChildren()) do
        for _, obj in ipairs(model:GetDescendants()) do
            if obj:IsA("Attachment") then
                local skip = false
                if eliminate then
                    for _, attachment in ipairs(eliminate) do
                        if attachment == obj then
                            skip = not skip
                            break
                        end
                    end
                    if skip then
                        continue
                    end
                end
                table.insert(road_atts, obj)
            end
        end
    end
    return road_atts
end

function npcs_manager:make_civil_walk(eliminate: table?)
    local walk_points = self:get_road_attachments(eliminate)
    local npc = self
    
    eliminate = eliminate or {}

    local npc_pos = npc.model:WaitForChild("HumanoidRootPart").Position

    local function find_closest_walk_point_to()
        local closest_distance = math.huge
        local closest_walk_attachment
        for _, walk_attachment in ipairs(walk_points) do
            local walk_point = walk_attachment.WorldPosition
            local distance = (npc_pos - walk_point).Magnitude
            if distance < closest_distance then
                closest_distance = distance
                closest_walk_attachment = walk_attachment
            end
        end
        return closest_walk_attachment
    end

    local humanoid = npc.model.Humanoid
    
    -- Find the first closest walk point to the npc
    local closest_walk_attachment = find_closest_walk_point_to()
    local closest_walk_point = closest_walk_attachment.WorldPosition
    
    -- Calculate the path
    local path = self:create_n_calculate_path(npc.model, closest_walk_point)
    if path.Status == Enum.PathStatus.NoPath then
        warn("No path found")
        return
    end

    local waypoints = path:GetWaypoints()
    local next_waypoint_index = 1

    -- Make the npc walk to the next waypoint
    self:move_to_next_waypoint(next_waypoint_index, waypoints, humanoid, function()
        -- When it reaches the last waypoint, look for the next closest walk point in a infinite loop to close a routine
        table.insert(eliminate, closest_walk_attachment)
        if #eliminate > 4 then
            table.remove(eliminate, 1)
        end
        npc:make_civil_walk(eliminate)
    end)

end

function npcs_manager:load_async(_core)
    self.core = _core
    local common = self.core.common
    local text_chat_service = common.text_chat_service
    local xp_manager = _core:get_module("xp_manager")
    local xp = xp_manager.xp
    local observer = _core:get_singleton("observer")
    local npcs_observer = observer.new(function(data)
        xp_manager.hud.people_helped_info.Text = tostring(data.people_helped)
    end)

    xp:attach(npcs_observer)
    self.observer = npcs_observer
    self.subject = xp


    -- Load npcs
    self:load_npcs()
    
    do -- Chat bubble configuration
        -- Bubble chat properties to customize
        --#region bubble_chat_props
        local bubble_configuration = {
            BackgroundColor3 = Color3.fromHex("F5CD30"),
            BackgroundTransparency = 0.5,
            FontFace = Font.fromEnum(Enum.Font.SourceSans),
            TailVisible = true, -- Determines if the tail at the bottom of the text chat bubbles is visible.
            TextColor3 = Color3.fromHSV(0.7, 0.8, 0.9), -- Color of bubble text.
            TextSize = 20, -- Size of bubble text.
        }
        --#endregion bubble_chat_props

        function text_chat_service.OnBubbleAdded(_message: TextChatMessage, _adornee: Instance)
            local bubbleProperties = Instance.new("BubbleChatMessageProperties")
            for key, value in pairs(bubble_configuration) do
                bubbleProperties[key] = value
            end
            return bubbleProperties
        end
    end

    local function create_n_attach_prompt(parent: Model, props: table)
        assert(parent, "Parent required")
        assert(parent.ClassName == "Model", "Parent must be a model")
        local hold_duration = props.hold_duration or 0
        local action_text = props.action_text or "Interact"
        local object_text = props.object_text or ""
        local distance = props.distance or 5
        local name = props.name or "interactable_prompt"

        local prompt = Instance.new("ProximityPrompt")
        prompt.HoldDuration = hold_duration
        prompt.ActionText = action_text
        prompt.ObjectText = object_text
        prompt.MaxActivationDistance = distance
        prompt.Name = name
        prompt.Parent = parent
        return prompt
    end

    -- Load npcs behaviours
    self.core.filter_call(
        function(npc)
            return npc.model:GetAttribute("id") == "seller_v1"
        end,
        function(npc)
            npc:connect_lookat_player()

            local prompt = create_n_attach_prompt(npc.model, {
                object_text = "Talk to " .. npc.name
            })

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
            local prompt = create_n_attach_prompt(npc.model, {
                object_text = "Talk to " .. npc.name
            })
            
            local npc_head = npc.model:WaitForChild("Head")
            prompt.Triggered:Connect(function()
                text_chat_service:DisplayBubble(npc_head, "Ho")
            end)
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
            return npc.model:GetAttribute("id") == "civil_v1"
        end,
        function(npc)
            npc:change_parts_collision_group("npc_walk_mode")
            npc:make_civil_walk()
        end
    )(
        function(predicate, callback)
            for _, npc in ipairs(npcs_manager.objects) do
                if predicate(npc) then
                    task.spawn(callback, npc)
                end
            end
        end
    )
end

return npcs_manager