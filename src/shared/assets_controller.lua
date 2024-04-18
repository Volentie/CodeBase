local assets_controller = {
    assets = {}
}

function assets_controller.new(asset: MeshPart | Model | BasePart | Instance): ()
    asset.Touched:Connect(function(hit)
        if hit.Parent:FindFirstChild("Humanoid") then
            local char = hit.Parent
            
        end
    end)

    table.insert(assets_controller.assets, asset)
    
end

function assets_controller:load_async(core)
    local assets_model = workspace:WaitForChild("Assets")
    local assets = assets_model:GetChildren()
end

return assets_controller