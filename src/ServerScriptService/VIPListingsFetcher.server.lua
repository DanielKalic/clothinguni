-- VIP Listings Fetcher Server Script
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

-- Wait for ProfileStore data to be ready
repeat
    wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

-- Create RemoteEvents
local getListingsEvent = Instance.new("RemoteFunction")
getListingsEvent.Name = "GetPlayerListingsEvent"
getListingsEvent.Parent = ReplicatedStorage

-- Function to check if player owns VIP gamepass
local function hasVIPGamepass(player)
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
    end)
    return success and ownsGamepass
end

-- Function to get active listings for a player using ProfileStore
local function getPlayerListings(userId)
    print("DEBUG: Server fetching listings for userId:", userId)
    
    local ads = ProfileStoreData.GetAds()
    if not ads then
        print("DEBUG: Server - No ads data found in ProfileStore")
        return {}
    end
    
    local playerListings = {}
    local currentTime = os.time()
    
    for listingId, listingData in pairs(ads) do
        print("DEBUG: Server checking listing:", listingId, "userId:", listingData.userId)
        
        -- Check if this listing belongs to the target user
        local adUserId = tonumber(listingData.userId) or listingData.userId
        if adUserId == userId then
            -- Check if listing hasn't expired
            local timestamp = tonumber(listingData.timestamp) or currentTime
            print("DEBUG: Server listing expiration check - current:", currentTime, "expires:", timestamp)
            
            if currentTime < timestamp then
                -- Normalize data to handle both shirt and pants
                local shirtID = listingData.shirtID or ""
                local pantsID = listingData.pantsID or ""
                
                -- Create listings for each asset type
                if shirtID ~= "" and shirtID ~= "None" then
                    print("DEBUG: Server adding shirt listing:", shirtID)
                    table.insert(playerListings, {
                        id = listingId .. "_shirt",
                        assetId = shirtID,
                        assetType = "Shirt",
                        price = nil, -- No price display for Robux items
                        title = (listingData.customName or "Shirt") .. " (Shirt)",
                        description = "Custom shirt listing",
                        createdAt = listingData.creationDate or currentTime,
                        expiresAt = timestamp
                    })
                end
                
                if pantsID ~= "" and pantsID ~= "None" then
                    print("DEBUG: Server adding pants listing:", pantsID)
                    table.insert(playerListings, {
                        id = listingId .. "_pants",
                        assetId = pantsID,
                        assetType = "Pants", 
                        price = nil, -- No price display for Robux items
                        title = (listingData.customName or "Pants") .. " (Pants)",
                        description = "Custom pants listing",
                        createdAt = listingData.creationDate or currentTime,
                        expiresAt = timestamp
                    })
                end
            else
                print("DEBUG: Server listing expired")
            end
        end
    end
    
    print("DEBUG: Server found", #playerListings, "active listings for user", userId)
    return playerListings
end

-- Handle remote function calls
getListingsEvent.OnServerInvoke = function(player, targetUserId)
    print("DEBUG: Server received request from", player.Name, "for user", targetUserId)
    
    -- Check if requesting player has VIP gamepass
    if not hasVIPGamepass(player) then
        warn("Player", player.Name, "tried to use VIP feature without gamepass")
        return {}
    end
    
    -- Get listings for the target user
    local listings = getPlayerListings(targetUserId)
    
    print("DEBUG: Server returning", #listings, "listings to", player.Name)
    return listings
end

print("VIP Listings Fetcher server initialized with ProfileStore") 