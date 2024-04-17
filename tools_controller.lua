local tools_controller = {}

function tools_controller:is_player_inside_bounds(player_pos: Vector3, target: Instance, linear_range: number): boolean
    local target_pos = target.Position
    local target_size = target.Size
    local raw_distance = target_pos - player_pos
    local distance = Vector3.new(math.abs(raw_distance.X), math.abs(raw_distance.Y), math.abs(raw_distance.Z))
    return distance.X <= target_size.X +
        linear_range and distance.Y <= target_size.Y +
        linear_range and distance.Z <= target_size.Z
end

function tools_controller:boot()
    
end

return tools_controller