export type asset_object = MeshPart | Model | BasePart | Instance
export type asset = {
    is_player_inside_boundaries: (Vector3, Instance, number) -> boolean,
}
local asset: asset = {
    global = {}
}
asset.__index = asset

function asset.new(obj: asset_object): asset
    if table.find(asset.global, obj) then
        return asset.global[table.find(asset.global, obj)]
    end
    
    local asset_object: asset_object = obj
    local _highlight = Instance.new("Highlight")
    _highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    _highlight.FillTransparency = 1
    _highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    _highlight.Name = "InRange_" .. asset_object.Name


    local self: asset = setmetatable({
        asset_object = asset_object,
        highlighted = false,
        highlight = _highlight
    }, {__index = asset})
    
    table.insert(asset.global, self)
    
    return self
end

function asset:enable_highlight()
    if self.highlighted then
        return
    end
    self.highlight.Adornee = self.asset_object
    self.highlight.Parent = game.ReplicatedStorage.assets.Highlights
    self.highlighted = true
end

function asset:disable_highlight()
    if not self.highlighted then
        return
    end
    self.highlight.Adornee = nil
    self.highlight.Parent = nil
    self.highlighted = false
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

