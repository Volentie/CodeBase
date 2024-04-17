local ReplicatedStorage = game:GetService("ReplicatedStorage")
local tool = script.Parent

local essentials = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("get_shared")):get_table()

local function onActivated()
    print(essentials.local_player)
    print(essentials.is_player_inside_bounds)
end

tool.Activated:Connect(onActivated)