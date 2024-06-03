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

function npcs_manager:get_sanitizer()
    local assets_folder = self.core.common.replicated_storage.assets
    local sanitizer = assets_folder:FindFirstChild("sanitizer")
    local sanitizer_object = sanitizer:Clone()
    sanitizer_object.Parent = self.core.common.local_player.Backpack
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

function npcs_manager:bring_to_ngo(npc: Model)
    local ngos = workspace.NGOs:GetChildren()
    local nearest_distance = {Magnitude = math.huge}
    local nearest_ngo
    for _, ngo in ipairs(ngos) do
        local entrance_pos = ngo["corrimao.001"]:FindFirstChildWhichIsA("Attachment").WorldPosition
        local distance = (entrance_pos - npc:GetPivot().Position)
        if distance.Magnitude < nearest_distance.Magnitude then
            nearest_distance = distance
            nearest_ngo = ngo
        end
    end

    -- Calculate the path
    local path = self:create_n_calculate_path(npc, nearest_ngo["corrimao.001"]:FindFirstChildWhichIsA("Attachment").WorldPosition)
    if path.Status == Enum.PathStatus.NoPath then
        warn("No path found")
        return
    end
    
    local animation_manager = self.core:get_module("animation_manager")
    
    local waypoints = path:GetWaypoints()
    local next_waypoint_index = 1
    local humanoid = npc.Humanoid

    -- Set Anchored to false for this npc to be able to move
    npc["HumanoidRootPart"].Anchored = false
   
    -- Stop sit animation

    if self.animation_playing then
        self.animation:Stop()
        self.animation_playing = false
    end
    
    -- Wait some seconds so the player can see the npc before it starts walking
    task.wait(0.5)
    
    -- Play walk animation
    animation_manager:play_animation(npc, "kinetic/walk")
    local walkAnim = npc.Humanoid:GetPlayingAnimationTracks()[1]
    walkAnim.Priority = Enum.AnimationPriority.Action

    self:move_to_next_waypoint(next_waypoint_index, waypoints, humanoid, function()
        local last_tween = nil
        for _, descendant in ipairs(npc:GetDescendants()) do
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
            npc:Destroy()
        end)
    end)
end

function npcs_manager:donate_food_to_needy(): boolean
    local tool_equipped = self.core.common.character:FindFirstChildWhichIsA("Tool")
    if not tool_equipped then
        local msg = game.Players.LocalPlayer.PlayerGui.HUD.info_1.text
        msg.Text = "You need to have a food equipped to donate it!"
        local show = TweenService:Create(msg, TweenInfo.new(1), {TextTransparency = 0})
        show.Completed:Connect(function()
            show:Destroy()
            show = nil
            TweenService:Create(msg, TweenInfo.new(2), {TextTransparency = 1}):Play()
        end)
        show:Play()
        return
    end

    self:create_conversation({
        {
            self.head,
            "Thank you so much, I really appreciate it!"
        },
        {
            self.core.common.character_head,
            "My pleasure! I'm glad I could help you!"
        }
    })

    -- Pass
    self.xp_manager:increment_xp(5)
    self.xp_manager:increment_people_helped()
    self.bus:publish("update_xp")

    tool_equipped:Destroy()
    
    return true
end

function npcs_manager:connect_prompt_triggered(data)
    local event_bus = self.core:get_singleton("event_bus")
    local bus = event_bus.new()
    self.bus = bus
    local type = data.type
    local callback = data.callback
    local prompt = data.prompt
    assert(callback, "Callback not provided")
    assert(prompt, "Prompt not provided")

    local _callback = function()
        if type == "dialog" then
            self.player_manager:set_talking_npc(self)
            if self.id == "seller_v1" then
                npcs_manager.last_talker = self
            end
        end
        callback()
        self.player_manager:set_last_talking_npc(self)
    end

    bus:publish("subscribe_connection", prompt, "Triggered", _callback)
end

-- function npcs_manager:connect_prompt_trigger_ended(data)
--     local event_bus = self.core:get_singleton("event_bus")
--     local bus = event_bus.new()
--     local callback = data.callback
--     local prompt = data.prompt
--     assert(callback, "Callback not provided")
--     assert(prompt, "Prompt not provided")

--     bus:publish("subscribe_connection", prompt, "TriggerEnded", callback)
-- end

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

-- TODO: Move dialog stuff to its own module
function npcs_manager:create_conversation(messages_table: { [string]: {[string]: number} })
    local DELAY = 1
    local common = self.core.common
    local text_chat_service = common.text_chat_service
    local function display_bubble(speaker, message, delay: boolean?)
        text_chat_service:DisplayBubble(speaker, message)
        if delay then
            task.wait(DELAY)
        end
    end
    local routine = coroutine.create(function()
        for _, msg_props in ipairs(messages_table) do
            local speaker = table.remove(msg_props, 1)
            for _, message in ipairs(msg_props) do
                display_bubble(speaker, message, true)
            end
        end
    end)
    coroutine.resume(routine)
    return routine
end

function npcs_manager:load_async(_core)
    self.core = _core
    self.selected_npc = nil
    local event_bus = self.core:get_singleton("event_bus")
    local bus = event_bus.new()
    local common = self.core.common
    local text_chat_service = common.text_chat_service
    self.xp_manager = _core:get_module("xp_manager")
    self.xp = self.xp_manager.xp
    local player_manager = _core:get_module("player_manager")
    self.player_manager = player_manager
    
    -- Load npcs
    self:load_npcs()
    
    do -- Bubble chat config
        --#region bubble_chat_config
        local bubble_chat_message_properties = {
            BackgroundColor3 = Color3.fromHex("000000"),
            BackgroundTransparency = 0.5,
            FontFace = Font.fromEnum(Enum.Font.SourceSans),
            TailVisible = true, -- Determines if the tail at the bottom of the text chat bubbles is visible.
            TextColor3 = Color3.fromHSV(0.7, 0.8, 0.9), -- Color of bubble text.
            TextSize = 20, -- Size of bubble text.
        }
        local bubble_chat_configuration = {
            BubbleDuration = 2,
            BubblesSpacing = 8,
            MaxBubbles = 3,
        }
        --#endregion bubble_chat_config

        function text_chat_service.OnBubbleAdded(_message: TextChatMessage, _adornee: Instance)
            local bubbleProperties = Instance.new("BubbleChatMessageProperties")
            for key, value in pairs(bubble_chat_message_properties) do
                bubbleProperties[key] = value
            end
            return bubbleProperties
        end
        
        -- Apply bubble chat configuration
        local BubbleChatConfiguration = text_chat_service:WaitForChild("BubbleChatConfiguration")
        for key, value in pairs(bubble_chat_configuration) do
            BubbleChatConfiguration[key] = value
        end
    end

    local function create_n_attach_prompt(parent: Model, props: table)
        assert(parent, "Parent required")
        assert(parent.ClassName == "Model", "Parent must be a model")
        local hold_duration = props.hold_duration or 0
        local action_text = props.action_text or ""
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
    local function delete_old_prompt(npc)
        local prompt = npc.model:FindFirstChild("interactable_prompt")
        if prompt then
            prompt:Destroy()
        end
    end
    
    local function _filter(predicate, callback)
        for _, npc in ipairs(npcs_manager.objects) do
            if predicate(npc) then
                npc.head = npc.model:WaitForChild("Head")
                npc.prompt_delay = 2
                callback(npc)
            end
        end
    end
    
    local function _predicate(id)
        return function(npc)
            return npc.model:GetAttribute("id") == id
        end
    end
    
    function self.filtered_map(filter_id: string | table, callback: (table) -> any)
        self.core.filter_call(
            _predicate(filter_id),
            callback
        )(_filter)
    end

    -- local DIALOG_RANGE = 10
    -- bus:publish("subscribe_connection", common.run_service, "Heartbeat", function(_dt)
    --     local is_talking = player_manager:is_talking()
    --     if is_talking then
    --         local ply_pos = common.humanoid_root_part.Position
    --         local npc_obj = player_manager:get_talking_npc()
    --         local talking_npc = npc_obj.model
    --         local prompt_enabled = talking_npc:FindFirstChild("interactable_prompt").Enabled
    --         local npc_pos = talking_npc.HumanoidRootPart.Position
    --         local dist_vec3 = npc_pos - ply_pos
    --         local abs_dist = math.abs(dist_vec3.Magnitude)
    --         if abs_dist < DIALOG_RANGE and prompt_enabled then
    --             talking_npc:FindFirstChild("interactable_prompt").Enabled = false
    --         elseif abs_dist > DIALOG_RANGE and not prompt_enabled then
    --             talking_npc:FindFirstChild("interactable_prompt").Enabled = true
    --             local npc_type = talking_npc:GetAttribute("id")
    --             if npc_type == "seller_v1" then
    --                 bus:publish("hide_seller_dialog")
    --             elseif npc_type == "needy_v1" then
    --                 bus:publish("hide_food_dialog")
    --             end
    --             bus:publish("stop_talking", talking_npc)
    --         end
    --     end
    -- end)
    
    self.filtered_map("seller_v1", function(npc)
        npc:connect_lookat_player()
        local prompt = create_n_attach_prompt(npc.model, {
            action_text = "Talk to " .. npc.name
        })
        npc:connect_prompt_triggered({
            type = "fast_dialog",
            prompt = prompt,
            callback = function()
                self:create_conversation({
                    {
                        npc.head,
                        "Hello! Please help the people in need, I'm sure they will appreciate it!"
                    }
                })
                npc:give_random_food()
            end
        })
        -- npc:connect_prompt_trigger_ended({
        --     prompt = prompt,
        --     callback = function()
        --         task.spawn(function()
        --             prompt.Enabled = not prompt.Enabled
        --             task.wait(npc.prompt_delay)
        --             prompt.Enabled = not prompt.Enabled
        --         end)
        --     end
        -- })
    end)
    
    self.filtered_map("needy_v1", function(npc)
        local prompt = create_n_attach_prompt(npc.model, {
            action_text = "Talk to " .. npc.name
        })
        npc:connect_prompt_triggered({
            type = "dialog",
            prompt = prompt,
            callback = function()
                local handler
                handler = function()
                    player_manager:get_talking_npc():donate_food_to_needy()
                    bus:publish("stop_talking", npc.model)
                end
                bus:subscribe("yes_chosen", handler)
                local routine = self:create_conversation({
                    {
                        common.character_head,
                        "Hi, how are you?",
                    },
                    {
                        npc.head,
                        "Good, but I'm hungry",
                        "Could you please give me some food?",
                    }
                })
                -- Wait for the previous routine to end and then opens dialog
                while coroutine.status(routine) ~= "dead" do
                    task.wait()
                end
                bus:publish("show_food_dialog")
            end
        })
    end)
    
    self.filtered_map("civil_v1", function(npc)
        npc:change_parts_collision_group("npc_walk_mode")
        npc:make_civil_walk()
    end)

    local function sanitizer_handler()
        self:create_conversation({
            {
                common.character_head,
                "Thank you for the sanitizer!",
            },
        })
        self:get_sanitizer()
        bus:publish("stop_talking", player_manager:get_talking_npc().model)
    end
	bus:subscribe("get_sanitizer_chosen", sanitizer_handler)

    local function food_handler()
        local routine = self:create_conversation({
            {
                common.character_head,
                "Thank you for the food!",
            },
        })
        while coroutine.status(routine) ~= "dead" do
            task.wait()
        end
        self:give_random_food()
        bus:publish("stop_talking", player_manager:get_talking_npc().model)
    end
	bus:subscribe("get_food_chosen", food_handler)

    local function job_handler()
        local npc_head = player_manager:get_talking_npc().model:FindFirstChild("Head")
        self:create_conversation({
            {
                common.character_head,
                "Thank you for the opportunity of helping someone!",
            },
            {
                npc_head,
                "Go find someone in need and hire them!"
            }
        })
        player_manager:look_for_job()
        bus:publish("stop_talking", player_manager:get_talking_npc().model)
    end
	bus:subscribe("get_job_chosen", job_handler)
    
    bus:subscribe("stop_looking_for_job", function()
        local npc = player_manager:get_last_talking_npc()
        npc:bring_to_ngo(npc.model)
    end)
    
    local function job_option_shop_worker()
        local npc_model = player_manager:get_talking_npc().model
        local routine = self:create_conversation({
            {
                npc_model,
                "Oh my! Thank you so much for finding me the job of being a shop worker!",
            },
        })
        while coroutine.status(routine) ~= "dead" do
            task.wait()
        end
        bus:publish("stop_looking_for_job", npc_model, npcs_manager.last_talker)
    end
    bus:subscribe("shop_worker_chosen", job_option_shop_worker)

    local function job_option_street_cleaner()
        local npc_model = player_manager:get_talking_npc().model
        local routine = self:create_conversation({
            {
                npc_model,
                "Oh my! Thank you so much for finding me the job of being a street cleaner!",
            },
        })
        while coroutine.status(routine) ~= "dead" do
            task.wait()
        end
        bus:publish("stop_looking_for_job", npc_model, npcs_manager.last_talker)
    end
    bus:subscribe("street_cleaner_chosen", job_option_street_cleaner)

    local function job_option_ngo_worker()
        local npc_model = player_manager:get_talking_npc().model
        local routine = self:create_conversation({
            {
                npc_model,
                "Oh my! Thank you so much for finding me the job of being a NGO worker!",
            },
        })
        while coroutine.status(routine) ~= "dead" do
            task.wait()
        end
        bus:publish("stop_looking_for_job", npc_model, npcs_manager.last_talker)
    end
    bus:subscribe("ngo_worker_chosen", job_option_ngo_worker)
                

    bus:subscribe("level_up", function(level)
        if level == 2 then
            self.filtered_map("seller_v1", function(npc)
                delete_old_prompt(npc)
            end)
            self.filtered_map("seller_v1", function(npc)
                local prompt = create_n_attach_prompt(npc.model, {
                    action_text = "Talk to " .. npc.name
                })
                npc:connect_prompt_triggered({
                    type = "dialog",
                    prompt = prompt,
                    callback = function()
                        if player_manager:get_last_talking_npc() == npc or
                            player_manager:is_looking_for_job() then
                            return
                        end
                        local routine = self:create_conversation({
                            {
                                npc.head,
                                "Hi, how are you?",
                            },
                        })
                        while coroutine.status(routine) ~= "dead" do
                            task.wait()
                        end
                        bus:publish("show_seller_dialog")
                    end
                })
            end)
            
            self.filtered_map("needy_v1", function(npc)
                delete_old_prompt(npc)
            end)
            self.filtered_map("needy_v1", function(npc)
                local npc_prompt = create_n_attach_prompt(npc.model, {
                    action_text = "Interact with " .. npc.name
                })
                npc:connect_prompt_triggered({
                    type = "dialog",
                    prompt = npc_prompt,
                    callback = function()
                        if player_manager:get_last_talking_npc() == npc then
                            return
                        end
                        local routine = self:create_conversation({
                            {
                                npc.head,
                                "Hey, how are you doing today?",
                            }
                        })
                        while coroutine.status(routine) ~= "dead" do
                            task.wait()
                        end
                        if player_manager:is_looking_for_job() then
                            bus:publish("show_job_options")
                        else
                            bus:publish("show_food_dialog")
                        end
                    end
                })
            end)
        end
    end)
end

return npcs_manager