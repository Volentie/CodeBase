local get_service = function(service_name)
    return game:GetService(service_name)
end

while not get_service("RunService"):IsRunning() do
    task.wait(60*5)
    error("Game is not running")
end

local Players = get_service("Players")

local LocalPlayer = Players.LocalPlayer
if LocalPlayer == nil then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- --:[Services]:--
local ReplicatedStorage = get_service("ReplicatedStorage")
local ServerScriptService = get_service("ServerScriptService")
local StarterPlayer = get_service("StarterPlayer")
local StarterGui = get_service("StarterGui")
local Lighting = get_service("Lighting")
local TweenService = get_service("TweenService")
local UserInputService = get_service("UserInputService")
local HttpService = get_service("HttpService")

-- --:[Services Properties]:--
local StarterCharacterScripts = StarterPlayer:WaitForChild("StarterCharacterScripts")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

return {
    get_service = get_service,
    local_player = LocalPlayer,
    replicated_storage = ReplicatedStorage,
    server_script_service = ServerScriptService,
    starter_player = StarterPlayer,
    starter_gui = StarterGui,
    lighting = Lighting,
    tween_service = TweenService,
    user_input_service = UserInputService,
    http_service = HttpService,
    starter_character_scripts = StarterCharacterScripts,
    starter_player_scripts = StarterPlayerScripts
}