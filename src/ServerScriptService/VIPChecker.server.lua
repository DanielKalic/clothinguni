-- VIP Checker Server Script
-- Handles VIP gamepass checking for client scripts

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

print("DEBUG: [VIPChecker] Server script starting...")

-- Wait for ReplicatedStorage to be ready
while not ReplicatedStorage do
    task.wait(0.1)
end

-- Create RemoteFunction for VIP checking
local vipCheckEvent = Instance.new("RemoteFunction")
vipCheckEvent.Name = "VIPCheckEvent"
vipCheckEvent.Parent = ReplicatedStorage

print("DEBUG: [VIPChecker] Created VIPCheckEvent RemoteFunction")

-- Function to check if player owns VIP gamepass
local function hasVIPGamepass(player)
    print("DEBUG: [VIPChecker] Checking VIP gamepass for " .. player.Name .. " (UserID: " .. player.UserId .. ")")
    
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
    end)
    
    if success then
        print("DEBUG: [VIPChecker] VIP check successful for " .. player.Name .. " - Result: " .. tostring(ownsGamepass))
        return ownsGamepass
    else
        warn("DEBUG: [VIPChecker] VIP check failed for " .. player.Name .. " - Error: " .. tostring(ownsGamepass))
        return false
    end
end

-- Handle VIP check requests
vipCheckEvent.OnServerInvoke = function(player)
    print("DEBUG: [VIPChecker] VIP check request from " .. player.Name)
    
    local isVIP = hasVIPGamepass(player)
    print("DEBUG: [VIPChecker] " .. player.Name .. " VIP status: " .. tostring(isVIP))
    
    return isVIP
end

print("DEBUG: [VIPChecker] VIP Checker server initialized and ready") 