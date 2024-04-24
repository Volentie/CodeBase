local animation_manager = {
    all_animations = {}
}

function animation_manager:play_animation(model: Model, animation_path: string): boolean
    -- Get the animation id
    local animation_id = self.all_animations[animation_path]
    if not animation_id then
        warn("No animation found for path: " .. animation_path)
        return false
    end

    local anim_id = "rbxassetid://" .. animation_id
    local animation = model:FindFirstChild(anim_id)
    if not animation then
        animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://" .. animation_id
    elseif animation.IsPlaying then
        warn("Animation is already playing")
        return
    end

    local animator = model.Humanoid:FindFirstChildOfClass("Animator")
    assert(animator, "No animator found in model")

    local animation_track = animator:LoadAnimation(animation)
    animation_track:Play()

    return animation_track
end

function animation_manager:load_sync(core)
    local global_anim = self.all_animations
    local animations_config = core:get_config("animations")

    -- Function to load all the animations in the game
    function self:load_all(): ()
        for animation_type, animation_obj in pairs(animations_config) do
            for animation_name, animation_id in pairs(animation_obj) do
                local animation_path = animation_type .. "/" .. animation_name
                global_anim[animation_path] = animation_id
            end
        end
    end

    self:load_all()
end

return animation_manager