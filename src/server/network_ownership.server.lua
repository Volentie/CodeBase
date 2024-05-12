local remoteFunction = Instance.new("RemoteFunction")
remoteFunction.Name = "SetNetworkOwnershipFunction"
remoteFunction.Parent = game.ReplicatedStorage

remoteFunction.OnServerInvoke = function(player)
    task.spawn(function()
        local to_stream = {}
        local function collect_descendants(folder)
            for _, npc in ipairs(workspace:WaitForChild("NPCs"):WaitForChild(folder):GetChildren()) do
                for _, part in ipairs(npc:GetDescendants()) do
                    if part:IsA("BasePart") then
                        table.insert(to_stream, part)
                    end
                end
            end
        end
        collect_descendants("Needy")
        collect_descendants("Civils")
        for _, part in ipairs(to_stream) do
            part:SetNetworkOwner(player)
        end
        remoteFunction:InvokeClient(player, true)
    end)
end