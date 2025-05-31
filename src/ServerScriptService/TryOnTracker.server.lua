-- TryOnTracker.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Create the TrackTryOnEvent
local trackTryOnEvent = Instance.new("RemoteEvent")
trackTryOnEvent.Name = "TrackTryOnEvent"
trackTryOnEvent.Parent = ReplicatedStorage

-- Wait for ProfileStore data to be ready
repeat
    wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

-- Function to increment try-on count for an asset using ProfileStore
local function incrementTryOnCount(assetId, assetType)
    local success = ProfileStoreData.IncrementTryOn(assetId, assetType)
    
    if success then
        local newCount = ProfileStoreData.GetTryOnCount(assetId, assetType)
        print("Updated try-on count for asset " .. assetId .. " to " .. newCount)
        return true
    else
        warn("Failed to update try-on count for asset " .. assetId)
        return false
    end
end

-- Function to track clothing changes
local function trackClothingChange(player, clothing)
    if not clothing then return end
    
    local assetId = nil
    local assetType = nil
    
    -- Extract asset ID from the clothing template
    if clothing:IsA("Shirt") and clothing.ShirtTemplate then
        local template = clothing.ShirtTemplate
        -- Try both URL formats
        assetId = template:match("rbxassetid://(%d+)") or template:match("id=(%d+)")
        assetType = "Shirt"
    elseif clothing:IsA("Pants") and clothing.PantsTemplate then
        local template = clothing.PantsTemplate
        -- Try both URL formats
        assetId = template:match("rbxassetid://(%d+)") or template:match("id=(%d+)")
        assetType = "Pants"
    end
    
    -- Only track if we have valid data
    if assetId and assetType then
        assetId = tonumber(assetId)
        if assetId and assetId > 0 then
            -- Validate asset ID range (Roblox asset IDs are typically under 10^13)
            if assetId > 10000000000000 then -- 10^13
                warn("Invalid asset ID detected (too large):", assetId, "from player:", player.Name)
                return
            end
            
            print("Player " .. player.Name .. " tried on " .. assetType .. " #" .. assetId)
            -- Call our local function to increment the try-on count
            incrementTryOnCount(assetId, assetType)
        end
    end
end

-- Function to set up tracking for a player
local function setupPlayerTracking(player)
    local character = player.Character or player.CharacterAdded:Wait()
    
    -- Track when clothing is added to the character
    character.ChildAdded:Connect(function(child)
        if child:IsA("Shirt") or child:IsA("Pants") then
            -- Small delay to ensure the template is set
            task.wait(0.1)
            trackClothingChange(player, child)
            
            -- Also track when the template changes (for existing clothing items)
            if child:IsA("Shirt") then
                child:GetPropertyChangedSignal("ShirtTemplate"):Connect(function()
                    task.wait(0.1) -- Small delay to ensure template is fully set
                    trackClothingChange(player, child)
                end)
            elseif child:IsA("Pants") then
                child:GetPropertyChangedSignal("PantsTemplate"):Connect(function()
                    task.wait(0.1) -- Small delay to ensure template is fully set
                    trackClothingChange(player, child)
                end)
            end
        end
    end)
    
    -- Also track existing clothing when character spawns and set up template change tracking
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Shirt") or child:IsA("Pants") then
            trackClothingChange(player, child)
            
            -- Set up template change tracking for existing clothing
            if child:IsA("Shirt") then
                child:GetPropertyChangedSignal("ShirtTemplate"):Connect(function()
                    task.wait(0.1) -- Small delay to ensure template is fully set
                    trackClothingChange(player, child)
                end)
            elseif child:IsA("Pants") then
                child:GetPropertyChangedSignal("PantsTemplate"):Connect(function()
                    task.wait(0.1) -- Small delay to ensure template is fully set
                    trackClothingChange(player, child)
                end)
            end
        end
    end
end

-- NOTE: Automatic character tracking is disabled
-- Try-ons should only be tracked when players use ProximityPrompts on NPCs
-- The manual tracking via RemoteEvent is still active below

-- Handle client-side try-on tracking requests
trackTryOnEvent.OnServerEvent:Connect(function(player, assetId, assetType)
    print("SERVER DEBUG: Received try-on request from", player.Name, "assetId:", assetId, "assetType:", assetType)
    
    -- Validate parameters
    if not assetId or not assetType then
        warn("Invalid try-on tracking request from " .. player.Name .. ": missing parameters")
        return
    end
    
    -- Convert to number if needed
    if type(assetId) == "string" then
        assetId = tonumber(assetId)
    end
    
    if not assetId or assetId <= 0 then
        warn("Invalid asset ID from " .. player.Name .. ": " .. tostring(assetId))
        return
    end
    
    -- Validate asset ID range
    if assetId > 10000000000000 then -- 10^13
        warn("Asset ID too large from " .. player.Name .. ": " .. tostring(assetId))
        return
    end
    
    -- Validate asset type
    if assetType ~= "Shirt" and assetType ~= "Pants" then
        warn("Invalid asset type from " .. player.Name .. ": " .. tostring(assetType))
        return
    end
    
    print("SERVER: Processing try-on tracking: " .. player.Name .. " tried on " .. assetType .. " #" .. assetId)
    local success = incrementTryOnCount(assetId, assetType)
    if success then
        print("SERVER: Successfully updated try-on count for asset", assetId)
    else
        print("SERVER: Failed to update try-on count for asset", assetId)
    end
end)

print("TryOnTracker initialized with ProfileStore") 