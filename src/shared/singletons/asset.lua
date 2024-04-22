export type asset_object = MeshPart | Model | BasePart | Instance
export type asset = {
    is_player_inside_boundaries: (Vector3, Instance, number) -> boolean,
}
local asset: asset = {
    global = {}
}
asset.__index = asset

function asset.new(obj: asset_object): asset
    local asset_object: asset_object = obj

    local self: asset = setmetatable({
        asset_object = asset_object
    }, {__index = asset})
    
    table.insert(asset.global, self)
    return self
end

function asset:is_player_inside_boundaries(player_pos: Vector3, target: Instance, linear_range: number): boolean
    if target.ClassName == "Model" then
        target = {
            Size = target:GetExtentsSize(),
            Position = target:GetPivot().Position
        }
    elseif not target:IsA("BasePart") then
        return false
    end

    local target_pos = target.Position
    local target_size = target.Size
    local raw_distance = target_pos - player_pos
    local distance = Vector3.new(math.abs(raw_distance.X), math.abs(raw_distance.Y), math.abs(raw_distance.Z))
    return distance.X  - (target_size.X / 2) <= linear_range and
           --distance.Y  - (target_size.Y / 2) <= linear_range and
           distance.Z  - (target_size.Z / 2) <= linear_range
end

return asset

