local assets_manager = {
    assets = {},
    buffer = setmetatable({}, {__mode = "k"})
}

function assets_manager.new(asset: MeshPart | Model | BasePart | Instance): ()
    asset.Touched:Connect(function(hit)
        if hit.Parent:FindFirstChild("Humanoid") then
            local char = hit.Parent
           
        end
    end)

    local self = setmetatable({
        asset = asset
    }, {__index = assets_manager})

    table.insert(assets_manager.assets, self)
    return self
end

function assets_manager:is_player_inside_bounds(player_pos: Vector3, target: Instance, linear_range: number): boolean
    local target_pos = target.Position
    local target_size = target.Size
    local raw_distance = target_pos - player_pos
    local distance = Vector3.new(math.abs(raw_distance.X), math.abs(raw_distance.Y), math.abs(raw_distance.Z))
    return distance.X <= target_size.X +
        linear_range and distance.Y <= target_size.Y +
        linear_range and distance.Z <= target_size.Z
end

function assets_manager:load_sync()
    local buffer = self.buffer
    buffer.assets_folder = workspace:WaitForChild("Assets")
    buffer.assets = buffer.assets_folder:GetChildren()
end

function assets_manager:load_async()
    local buffer = self.buffer
    for _, asset in ipairs(buffer.assets) do
        self.new(asset)
    end
    
    function self:breath()
        for _, asset_object in self.assets do
            local asset = asset_object.asset

        end
    end

end

return assets_manager