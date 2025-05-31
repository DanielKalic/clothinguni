-- TryOnTracker.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Get the TrackTryOnEvent
local trackTryOnEvent = ReplicatedStorage:WaitForChild("TrackTryOnEvent")

-- Function to manually track a try-on (can be called from other scripts if needed)
local function trackTryOn(assetId, assetType)
    if not assetId or not assetType then
        warn("Invalid parameters for trackTryOn:", assetId, assetType)
        return
    end
    
    -- Validate asset type
    if assetType ~= "Shirt" and assetType ~= "Pants" then
        warn("Invalid asset type for try-on tracking:", assetType)
        return
    end
    
    -- Convert to number if it's a string
    if type(assetId) == "string" then
        assetId = tonumber(assetId)
    end
    
    if not assetId or assetId <= 0 then
        warn("Invalid asset ID for try-on tracking:", assetId)
        return
    end
    
    print("Manually tracking try-on:", assetType, "#" .. assetId)
    trackTryOnEvent:FireServer(assetId, assetType)
end

-- Make the trackTryOn function globally available for other scripts
_G.trackTryOn = trackTryOn

print("Client-side TryOnTracker initialized")
print("Try-ons are now automatically tracked by server scripts when using ProximityPrompts") 