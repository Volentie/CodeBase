local remoteFunction = Instance.new("RemoteFunction")
remoteFunction.Name = "SetNetworkOwnershipFunction"
remoteFunction.Parent = game.ReplicatedStorage

remoteFunction.OnServerInvoke = function(player)
    for _, npc in ipairs(workspace:WaitForChild("NPCs"):WaitForChild("Needy"):GetChildren()) do
        task.spawn(function()
            for _, descendant in ipairs(npc:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    descendant:SetNetworkOwner(player)
                end
            end
        end)
    end
    task.spawn(remoteFunction.InvokeClient, remoteFunction, player, true)
end