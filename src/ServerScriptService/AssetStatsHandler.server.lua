-- AssetStatsHandler.server.lua
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("AssetStatsHandler: Starting after delay for core system initialization...")

-- Delay initialization to reduce server load during startup (asset stats are non-essential)
wait(5)

print("AssetStatsHandler: Starting asset statistics tracking...")

-- Wait for ProfileStore data to be ready
repeat
    wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

-- Initialize remote function for fetching asset stats
local getAssetStatsFunc = ReplicatedStorage:FindFirstChild("GetAssetStatsFunc")
if not getAssetStatsFunc then
    print("DEBUG: [AssetStatsHandler] Creating GetAssetStatsFunc RemoteFunction")
    getAssetStatsFunc = Instance.new("RemoteFunction")
    getAssetStatsFunc.Name = "GetAssetStatsFunc"
    getAssetStatsFunc.Parent = ReplicatedStorage
else
    print("DEBUG: [AssetStatsHandler] Found existing GetAssetStatsFunc RemoteFunction")
end

-- Initialize remote event for opening stats
local openAssetStatsEvent = ReplicatedStorage:FindFirstChild("OpenAssetStatsEvent")
if not openAssetStatsEvent then
    print("DEBUG: [AssetStatsHandler] Creating OpenAssetStatsEvent RemoteEvent")
    openAssetStatsEvent = Instance.new("RemoteEvent")
    openAssetStatsEvent.Name = "OpenAssetStatsEvent"
    openAssetStatsEvent.Parent = ReplicatedStorage
else
    print("DEBUG: [AssetStatsHandler] Found existing OpenAssetStatsEvent RemoteEvent")
end

-- Ensure the event exists before connecting
task.wait(1) -- Small delay to ensure everything is ready

print("DEBUG: [AssetStatsHandler] Setting up openAssetStatsEvent connection...")

-- Get the try-on tracking event (created by TryOnTracker.server.lua)
local trackTryOnEvent = ReplicatedStorage:WaitForChild("TrackTryOnEvent")

-- Function to get shirt and pants sales using ProfileStore
local function getAssetSales(assetId)
    -- Use the new sales tracking system
    local shirtSales = ProfileStoreData.GetSalesCount(assetId, "Shirt")
    local pantsSales = ProfileStoreData.GetSalesCount(assetId, "Pants")
    
    -- Return the higher count (since an asset is either a shirt or pants)
    return math.max(shirtSales, pantsSales)
end

-- Function to get try-on count for an asset using ProfileStore
local function getAssetTryOns(assetId)
    local shirtTryOns = ProfileStoreData.GetTryOnCount(assetId, "Shirt")
    local pantsTryOns = ProfileStoreData.GetTryOnCount(assetId, "Pants")
    
    -- Return the higher count (since an asset is either a shirt or pants)
    return math.max(shirtTryOns, pantsTryOns)
end

-- Function to get recent sales (past 24 hours)
local function getRecentSales(assetId)
    local shirtRecentSales = ProfileStoreData.GetRecentSalesCount(assetId, "Shirt", 24)
    local pantsRecentSales = ProfileStoreData.GetRecentSalesCount(assetId, "Pants", 24)
    
    -- Return the higher count (since an asset is either a shirt or pants)
    return math.max(shirtRecentSales, pantsRecentSales)
end

print("DEBUG: [AssetStatsHandler] Setting up RemoteFunction handler...")

-- Handle asset stats requests
local funcSuccess, funcErr = pcall(function()
    getAssetStatsFunc.OnServerInvoke = function(player, assetId)
        print("DEBUG: [AssetStatsHandler] Received getAssetStatsFunc request from", player.Name, "for assetId:", assetId)
        
        if not assetId then 
            print("DEBUG: [AssetStatsHandler] No assetId provided, returning nil")
            return nil 
        end
        
        local totalSales = getAssetSales(assetId)
        local recentSales = getRecentSales(assetId)
        local tryOns = getAssetTryOns(assetId)
        
        local stats = {
            totalSales = totalSales,
            recentSales = recentSales,
            tryOns = tryOns
        }
        
        print("DEBUG: [AssetStatsHandler] Returning stats for assetId", assetId, "- Sales:", totalSales, "Recent:", recentSales, "TryOns:", tryOns)
        
        return stats
    end
end)

if funcSuccess then
    print("DEBUG: [AssetStatsHandler] Successfully set up RemoteFunction handler!")
else
    warn("DEBUG: [AssetStatsHandler] Failed to set up RemoteFunction handler:", funcErr)
end

-- Handle opening asset stats from button clicks
local success, err = pcall(function()
    openAssetStatsEvent.OnServerEvent:Connect(function(player, assetId, assetType)
        print("DEBUG: [AssetStatsHandler] Received openAssetStatsEvent from", player.Name, "assetId:", assetId, "assetType:", assetType)
        
        if not assetId or not assetType then 
            print("DEBUG: [AssetStatsHandler] Missing assetId or assetType, ignoring request")
            return 
        end
        
        -- Valid asset types
        if assetType ~= "Shirt" and assetType ~= "Pants" then 
            print("DEBUG: [AssetStatsHandler] Invalid assetType:", assetType, "ignoring request")
            return 
        end
        
        print("DEBUG: [AssetStatsHandler] Firing openAssetStatsEvent to client for", player.Name)
        
        -- Use a pcall to catch any errors when firing to client
        local fireSuccess, fireErr = pcall(function()
            openAssetStatsEvent:FireClient(player, assetId, assetType)
        end)
        
        if fireSuccess then
            print("DEBUG: [AssetStatsHandler] Successfully fired openAssetStatsEvent to client")
        else
            warn("DEBUG: [AssetStatsHandler] Failed to fire to client:", fireErr)
        end
    end)
end)

if success then
    print("DEBUG: [AssetStatsHandler] Successfully connected to openAssetStatsEvent!")
else
    warn("DEBUG: [AssetStatsHandler] Failed to connect to openAssetStatsEvent:", err)
end

print("AssetStatsHandler initialized with ProfileStore") 