local asset_manager = {
    linear_range_int = 15,
    assets_folder = workspace.City
}

function asset_manager:load_async(core)
    local event_bus = core:get_singleton("event_bus")
    local run_service = core.common.run_service
    local bus = event_bus.new()
    local humanoid = core.common.humanoid
    local humanoid_root_part = core.common.humanoid_root_part
    local asset = core:get_singleton("asset")

    -- Create the assets for all models
    self:create_assets_for_models(core)

    -- Subscribe a connection to the event bus
    bus:publish("subscribe_connection", run_service, "RenderStepped", function()
        self:has_player_moved(asset, humanoid, humanoid_root_part)
    end)
end

function asset_manager:create_assets_for_models(core)
    local asset = core:get_singleton("asset")
    for _, model in self.assets_folder:GetChildren() do
        asset.new(model)
    end
end

function asset_manager:on_player_moved(asset_singleton, player_pos)
    for _, asset in ipairs(asset_singleton.global) do
        if asset:is_player_inside_boundaries(player_pos, asset.asset_object, self.linear_range_int) then
            --print("Player is inside the boundaries of the asset: " .. asset.asset_object.Name)
            asset:enable_highlight()
        elseif asset.highlighted then
            asset:disable_highlight()
        end
    end
end

function asset_manager:has_player_moved(asset, humanoid, humanoid_root_part)
    if humanoid.MoveDirection.Magnitude > 0 then
        self:on_player_moved(asset, humanoid_root_part.Position)
    end
end

return asset_manager