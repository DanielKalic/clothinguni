-- BoomBox Giver Server Script
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Gamepass settings
local BOOMBOX_GAMEPASS_ID = 1236848449

print("BoomBox Giver: Server script starting...")

-- Create RemoteFunction
local getBoomBoxFunction = Instance.new("RemoteFunction")
getBoomBoxFunction.Name = "GetBoomBoxFunction"
getBoomBoxFunction.Parent = ReplicatedStorage

print("BoomBox Giver: Created GetBoomBoxFunction in ReplicatedStorage")

-- Function to check if player owns gamepass
local function checkGamepass(userId)
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(userId, BOOMBOX_GAMEPASS_ID)
    end)
    
    if success then
        return ownsGamepass
    else
        warn("Failed to check gamepass for user:", userId)
        return false
    end
end

-- Function to get BoomBox from ServerStorage
local function getBoomBoxTool()
    local tool = ServerStorage:FindFirstChild("BoomBox")
    if tool and tool:IsA("Tool") then
        return tool:Clone()
    else
        warn("BoomBox tool not found in ServerStorage")
        return nil
    end
end

-- Handle RemoteFunction calls
getBoomBoxFunction.OnServerInvoke = function(player)
    print("BoomBox Giver: Request received from player:", player.Name)
    
    -- Check if player owns gamepass
    local ownsGamepass = checkGamepass(player.UserId)
    print("BoomBox Giver: Player", player.Name, "owns gamepass:", ownsGamepass)
    
    if not ownsGamepass then
        print("BoomBox Giver: Player doesn't own gamepass, denying request")
        return false, "You need to purchase the Boombox gamepass!"
    end
    
    -- Check if player already has BoomBox in backpack
    if player.Backpack:FindFirstChild("BoomBox") then
        print("BoomBox Giver: Player already has BoomBox in backpack")
        return false, "You already have a BoomBox!"
    end
    
    -- Check if player has BoomBox equipped
    if player.Character and player.Character:FindFirstChild("BoomBox") then
        print("BoomBox Giver: Player already has BoomBox equipped")
        return false, "You already have a BoomBox equipped!"
    end
    
    -- Get BoomBox tool
    local boomboxTool = getBoomBoxTool()
    if not boomboxTool then
        warn("BoomBox Giver: Failed to get BoomBox tool")
        return false, "Failed to get BoomBox tool"
    end
    
    print("BoomBox Giver: Giving BoomBox to player:", player.Name)
    
    -- Give to player's backpack
    boomboxTool.Parent = player.Backpack
    
    print("BoomBox Giver: BoomBox successfully given to player:", player.Name)
    return true, "BoomBox added to your backpack!"
end

print("BoomBox Giver: Server script loaded and ready!") 