-- Boombox Gamepass System
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Wait for RemoteFunction
local getBoomBoxFunction = ReplicatedStorage:WaitForChild("GetBoomBoxFunction")

print("Boombox Gamepass System: Found GetBoomBoxFunction")

-- Function to request BoomBox from server
local function requestBoomBox()
    print("Requesting BoomBox from server...")
    
    local success, result, message = pcall(function()
        return getBoomBoxFunction:InvokeServer()
    end)
    
    if success then
        if result then
            print("✅ Success:", message)
            return true
        else
            print("❌ Failed:", message)
            return false
        end
    else
        warn("Error requesting BoomBox:", result)
        return false
    end
end

-- Function to give boombox to player's backpack
local function giveBoomboxToBackpack()
    -- Check if player already has a BoomBox in backpack
    if player.Backpack:FindFirstChild("BoomBox") then
        print("Player already has BoomBox in backpack")
        return true
    end
    
    -- Check if player has BoomBox equipped
    if player.Character and player.Character:FindFirstChild("BoomBox") then
        print("Player already has BoomBox equipped")
        return true
    end
    
    print("Requesting BoomBox from server...")
    return requestBoomBox()
end

-- Handle character respawning
player.CharacterAdded:Connect(function(newCharacter)
    print("Character respawned, requesting BoomBox...")
    
    -- Wait a moment for character to fully load, then request BoomBox
    task.wait(2)
    giveBoomboxToBackpack()
end)

-- Initialize when character is ready
local function initialize()
    print("Boombox Gamepass System initialized")
    
    -- Wait a moment for everything to load, then request BoomBox
    task.wait(2)
    giveBoomboxToBackpack()
end

-- Wait for character to load
if player.Character then
    initialize()
else
    player.CharacterAdded:Wait()
    initialize()
end

-- Periodically try to get BoomBox if needed
task.spawn(function()
    while true do
        task.wait(30) -- Check every 30 seconds
        
        -- Only request if we don't have one
        if not player.Backpack:FindFirstChild("BoomBox") and 
           not (player.Character and player.Character:FindFirstChild("BoomBox")) then
            print("Periodic check: Requesting BoomBox...")
            giveBoomboxToBackpack()
        end
    end
end)

print("Boombox Gamepass System loaded") 