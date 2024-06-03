local dialog_manager = {}

function dialog_manager:load_sync(core)
    local event_bus = core:get_singleton("event_bus")
    self.bus = event_bus.new()
    self.food_dialog = core.common.player_gui:WaitForChild("HUD"):WaitForChild("food_dialog")
    self.seller_dialog = core.common.player_gui:WaitForChild("HUD"):WaitForChild("seller_dialog")
    self.job_dialog = core.common.player_gui:WaitForChild("HUD"):WaitForChild("job_dialog")

    local food_dialog_options = {
        self.food_dialog.yes,
        self.food_dialog.no
    }
    
    local seller_dialog_options = {
        self.seller_dialog.get_food,
        self.seller_dialog.get_sanitizer,
        self.seller_dialog.get_job
    }

    local job_options = {
        self.job_dialog.shop_worker,
        self.job_dialog.street_cleaner,
        self.job_dialog.ngo_worker
    }

    for _, food_option in food_dialog_options do
        self.bus:subscribe(food_option.Name .. "_chosen", function()
            self:hide_food_dialog()
        end)
    end

    for _, seller_option in seller_dialog_options do
        self.bus:subscribe(seller_option.Name .. "_chosen", function()
            self:hide_seller_dialog()
        end)
    end

    self.bus:subscribe("hide_food_dialog", function()
        self:hide_food_dialog()
    end)

    self.bus:subscribe("hide_seller_dialog", function()
        self:hide_seller_dialog()
    end)

    self.bus:subscribe("show_food_dialog", function()
        self:show_food_dialog()
    end)
    
    self.bus:subscribe("show_seller_dialog", function()
        self:show_seller_dialog()
    end)
    
    self.bus:subscribe("show_job_options", function()
        self:show_job_options()
    end)

    self.bus:subscribe("hide_job_options", function()
        self:hide_job_options()
    end)

    for _, job_option in job_options do
        self.bus:subscribe(job_option.Name .. "_chosen", function()
            self:hide_job_options()
        end)
    end

    for _, element in food_dialog_options do
        -- Brighten the button when hovered
        element.MouseEnter:Connect(function()
            element.BackgroundTransparency = element.BackgroundTransparency - 0.15
        end)
        element.MouseLeave:Connect(function()
            element.BackgroundTransparency = element.BackgroundTransparency + 0.15
        end)
        
        -- Fires bus for when the button is clicked
        element.Activated:Connect(function(_input)
            self.bus:publish(element.Name .. "_chosen", _input)
        end)
    end
    
    for _, element in seller_dialog_options do
        element.MouseEnter:Connect(function()
            element.BackgroundTransparency = element.BackgroundTransparency - 0.15
        end)
        element.MouseLeave:Connect(function()
            element.BackgroundTransparency = element.BackgroundTransparency + 0.15
        end)
        
        element.Activated:Connect(function(_input)
            self.bus:publish(element.Name .. "_chosen", _input)
        end)
    end
    
    for _, element in job_options do
        element.MouseEnter:Connect(function()
            element.BackgroundTransparency = element.BackgroundTransparency - 0.15
        end)
        element.MouseLeave:Connect(function()
            element.BackgroundTransparency = element.BackgroundTransparency + 0.15
        end)
        
        element.Activated:Connect(function(_input)
            self.bus:publish(element.Name .. "_chosen", _input)
        end)
    end

end

function dialog_manager:show_food_dialog()
    self.food_dialog.Visible = true
end

function dialog_manager:hide_food_dialog()
    self.food_dialog.Visible = false
end

function dialog_manager:show_seller_dialog()
    self.seller_dialog.Visible = true
end

function dialog_manager:hide_seller_dialog()
    self.seller_dialog.Visible = false
end

function dialog_manager:show_job_options()
    self.job_dialog.Visible = true
end

function dialog_manager:hide_job_options()
    self.job_dialog.Visible = false
end

return dialog_manager