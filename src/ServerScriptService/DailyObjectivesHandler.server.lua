-- Daily Objectives Handler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

print("DailyObjectivesHandler: Starting after ProfileStore initialization...")

-- Small delay to let ProfileStore initialize
wait(3)

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

-- Wait for ProfileStore data to be ready
repeat
    wait(0.1)
until _G.ProfileStoreData and _G.ProfileStoreData.IsReady

local ProfileStoreData = _G.ProfileStoreData

-- Time constants (same as daily bonus)
local TIME_BETWEEN_RESETS = 24 * 60 * 60 -- 24 hours in seconds

-- Objective categories and their options
local OBJECTIVE_CATEGORIES = {
    buyAsset = {
        {target = 1, xp = 20, coins = 20, description = "Buy 1 Asset"},
        {target = 2, xp = 50, coins = 50, description = "Buy 2 Assets"},
        {target = 3, xp = 100, coins = 100, description = "Buy 3 Assets"}
    },
    openCrate = {
        {target = 1, xp = 20, coins = 20, description = "Open 1 Crate"},
        {target = 2, xp = 50, coins = 50, description = "Open 2 Crates"},
        {target = 3, xp = 100, coins = 100, description = "Open 3 Crates"}
    },
    collectCoins = {
        {target = 10, xp = 20, coins = 20, description = "Collect 10 Coins"},
        {target = 15, xp = 50, coins = 50, description = "Collect 15 Coins"},
        {target = 20, xp = 100, coins = 100, description = "Collect 20 Coins"}
    },
    tryOnClothes = {
        {target = 10, xp = 20, coins = 20, description = "Try on 10 Clothes"},
        {target = 15, xp = 50, coins = 50, description = "Try on 15 Clothes"},
        {target = 20, xp = 100, coins = 100, description = "Try on 20 Clothes"}
    },
    listClothing = {
        {target = 1, xp = 20, coins = 20, description = "List 1 Clothing"},
        {target = 3, xp = 50, coins = 50, description = "List 3 Clothing"},
        {target = 5, xp = 100, coins = 100, description = "List 5 Clothing"}
    }
}

-- Completion bonus for finishing all objectives
local ALL_OBJECTIVES_BONUS = {xp = 200, coins = 200}

-- Create remote events
local objectivesFolder = ReplicatedStorage:WaitForChild("DailyObjectives")

local getObjectivesEvent = objectivesFolder:FindFirstChild("GetObjectivesFunc")
if not getObjectivesEvent then
    getObjectivesEvent = Instance.new("RemoteFunction")
    getObjectivesEvent.Name = "GetObjectivesFunc"
    getObjectivesEvent.Parent = objectivesFolder
end

local updateObjectiveEvent = objectivesFolder:FindFirstChild("UpdateObjectiveEvent")
if not updateObjectiveEvent then
    updateObjectiveEvent = Instance.new("RemoteEvent")
    updateObjectiveEvent.Name = "UpdateObjectiveEvent"
    updateObjectiveEvent.Parent = objectivesFolder
end

local objectivesUpdatedEvent = objectivesFolder:FindFirstChild("ObjectivesUpdatedEvent")
if not objectivesUpdatedEvent then
    objectivesUpdatedEvent = Instance.new("RemoteEvent")
    objectivesUpdatedEvent.Name = "ObjectivesUpdatedEvent"
    objectivesUpdatedEvent.Parent = objectivesFolder
end

-- Notification event
local notificationEvent = ReplicatedStorage:WaitForChild("NotificationEvent")

-- Function to check if player has VIP gamepass
local function hasVIPGamepass(player)
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
    end)
    return success and ownsGamepass
end

-- Function to award XP and coins to player
local function awardRewards(player, xp, coins)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return false end
    
    local xpStat = leaderstats:FindFirstChild("XP")
    local coinsStat = leaderstats:FindFirstChild("Coins")
    
    if xpStat and coinsStat then
        -- Check for VIP bonus
        local isVIP = hasVIPGamepass(player)
        local finalCoins = isVIP and (coins * 2) or coins
        
        xpStat.Value = xpStat.Value + xp
        coinsStat.Value = coinsStat.Value + finalCoins
        
        -- Note: XP and Coins are automatically saved to ProfileStore by LeaderstatsSetupWithLevel.server.lua
        
        -- Send notification
        local message = "Objective Complete! +" .. xp .. " XP, +" .. finalCoins .. " Coins"
        if isVIP then
            message = message .. " (VIP 2x Coins)"
        end
        notificationEvent:FireClient(player, message, Color3.fromRGB(255, 215, 0))
        
        return true
    end
    
    return false
end

-- Function to generate random objectives for a player
local function generateRandomObjectives()
    local objectives = {}
    
    -- Get all category names
    local categoryNames = {}
    for category, _ in pairs(OBJECTIVE_CATEGORIES) do
        table.insert(categoryNames, category)
    end
    
    -- Shuffle the categories and pick only 3
    for i = #categoryNames, 2, -1 do
        local j = math.random(i)
        categoryNames[i], categoryNames[j] = categoryNames[j], categoryNames[i]
    end
    
    -- Take only the first 3 categories
    for i = 1, math.min(3, #categoryNames) do
        local category = categoryNames[i]
        local options = OBJECTIVE_CATEGORIES[category]
        
        -- Pick a random difficulty level (1, 2, or 3)
        local randomIndex = math.random(1, #options)
        local selectedObjective = options[randomIndex]
        
        objectives[category] = {
            target = selectedObjective.target,
            current = 0,
            completed = false,
            xp = selectedObjective.xp,
            coins = selectedObjective.coins,
            description = selectedObjective.description
        }
    end
    
    return objectives
end

-- Function to get player's objectives from ProfileStore
local function getPlayerObjectives(player)
    local profile = ProfileStoreData.GetPlayerProfile(player)
    if not profile or not profile:IsActive() then
        return generateRandomObjectives(), os.time()
    end
    
    -- Initialize objectives data if it doesn't exist
    if not profile.Data.dailyObjectives then
        profile.Data.dailyObjectives = {
            objectives = generateRandomObjectives(),
            lastReset = os.time()
        }
        return profile.Data.dailyObjectives.objectives, profile.Data.dailyObjectives.lastReset
    end
    
    local data = profile.Data.dailyObjectives
    if data.objectives and data.lastReset then
        -- Check if objectives need to be reset
        local currentTime = os.time()
        local timeSinceReset = currentTime - data.lastReset
        
        if timeSinceReset >= TIME_BETWEEN_RESETS then
            -- Time to reset objectives
            print("Resetting objectives for user " .. player.UserId .. " - time elapsed: " .. timeSinceReset)
            local newObjectives = generateRandomObjectives()
            profile.Data.dailyObjectives.objectives = newObjectives
            profile.Data.dailyObjectives.lastReset = currentTime
            return newObjectives, currentTime
        else
            -- Check if existing objectives have more than 3 - if so, regenerate
            local objectiveCount = 0
            for _ in pairs(data.objectives) do
                objectiveCount = objectiveCount + 1
            end
            
            if objectiveCount > 3 then
                print("Found " .. objectiveCount .. " objectives for user " .. player.UserId .. ", regenerating to 3")
                local newObjectives = generateRandomObjectives()
                profile.Data.dailyObjectives.objectives = newObjectives
                profile.Data.dailyObjectives.lastReset = currentTime
                return newObjectives, currentTime
            else
                -- Return existing objectives
                return data.objectives, data.lastReset
            end
        end
    end
    
    -- No data found or error, generate new objectives
    local newObjectives = generateRandomObjectives()
    profile.Data.dailyObjectives = {
        objectives = newObjectives,
        lastReset = os.time()
    }
    return newObjectives, os.time()
end

-- Function to save player's objectives to ProfileStore
local function savePlayerObjectives(player, objectives, lastReset)
    local profile = ProfileStoreData.GetPlayerProfile(player)
    if profile and profile:IsActive() then
        profile.Data.dailyObjectives = {
            objectives = objectives,
            lastReset = lastReset
        }
        return true
    else
        warn("Failed to save objectives for user " .. player.UserId .. ": Profile not active")
        return false
    end
end

-- Function to update objective progress
local function updateObjectiveProgress(player, objectiveType, amount)
    amount = amount or 1
    local userId = player.UserId
    
    print("DEBUG: updateObjectiveProgress called for " .. player.Name .. " - Type: " .. objectiveType .. " - Amount: " .. amount)
    
    -- Get current objectives
    local objectives, lastReset = getPlayerObjectives(player)
    
    -- Debug: Print current objectives
    print("DEBUG: Current objectives for " .. player.Name .. ":")
    for objType, objData in pairs(objectives) do
        print("  " .. objType .. ": " .. objData.current .. "/" .. objData.target .. " (completed: " .. tostring(objData.completed) .. ")")
    end
    
    if objectives[objectiveType] and not objectives[objectiveType].completed then
        print("DEBUG: Updating objective " .. objectiveType .. " for " .. player.Name)
        -- Update progress
        objectives[objectiveType].current = math.min(
            objectives[objectiveType].current + amount,
            objectives[objectiveType].target
        )
        
        -- Check if objective is completed
        if objectives[objectiveType].current >= objectives[objectiveType].target then
            objectives[objectiveType].completed = true
            
            -- Award rewards
            local xp = objectives[objectiveType].xp
            local coins = objectives[objectiveType].coins
            
            if awardRewards(player, xp, coins) then
                print("Player " .. player.Name .. " completed objective: " .. objectiveType)
                
                -- Check if all objectives are completed
                local allCompleted = true
                for _, obj in pairs(objectives) do
                    if not obj.completed then
                        allCompleted = false
                        break
                    end
                end
                
                -- Award bonus if all objectives completed
                if allCompleted then
                    if awardRewards(player, ALL_OBJECTIVES_BONUS.xp, ALL_OBJECTIVES_BONUS.coins) then
                        notificationEvent:FireClient(player, "ALL OBJECTIVES COMPLETE! Bonus: +" .. ALL_OBJECTIVES_BONUS.xp .. " XP, +" .. ALL_OBJECTIVES_BONUS.coins .. " Coins!", Color3.fromRGB(255, 100, 255))
                    end
                end
            end
        end
        
        -- Save updated objectives
        savePlayerObjectives(player, objectives, lastReset)
        
        -- Notify client of update
        print("DEBUG: Firing client update event for " .. player.Name)
        objectivesUpdatedEvent:FireClient(player, objectives)
    else
        print("DEBUG: Objective " .. objectiveType .. " not found or already completed for " .. player.Name)
    end
end

-- Handle get objectives request
getObjectivesEvent.OnServerInvoke = function(player)
    local userId = player.UserId
    local objectives, lastReset = getPlayerObjectives(player)
    
    -- Save if this is new data
    savePlayerObjectives(player, objectives, lastReset)
    
    return objectives, lastReset
end

-- Listen for objective updates from other scripts
updateObjectiveEvent.OnServerEvent:Connect(function(player, objectiveType, amount)
    updateObjectiveProgress(player, objectiveType, amount)
end)

-- Create a function for direct server-side calls
function updateObjectiveProgress_Direct(player, objectiveType, amount)
    print("DEBUG: _G.UpdateDailyObjective called for " .. player.Name .. " - Type: " .. objectiveType .. " - Amount: " .. (amount or 1))
    updateObjectiveProgress(player, objectiveType, amount)
end

-- Store the function globally so other scripts can access it
_G.UpdateDailyObjective = updateObjectiveProgress_Direct

-- Connect to existing events to track progress

-- Track asset purchases (clothing purchases)
local function onClothingPurchase(player)
    updateObjectiveProgress(player, "buyAsset", 1)
end

-- Track crate openings
local function onCrateOpening(player)
    updateObjectiveProgress(player, "openCrate", 1)
end

-- Track coin collection (count each pickup as 1, regardless of VIP bonus)
local function onCoinCollection(player, amount)
    -- For Daily Objectives, we count each coin pickup as 1 action, not the coin amount
    updateObjectiveProgress(player, "collectCoins", 1)
end

-- Track clothing try-ons
local function onClothingTryOn(player)
    updateObjectiveProgress(player, "tryOnClothes", 1)
end

-- Track clothing listings
local function onClothingListing(player)
    updateObjectiveProgress(player, "listClothing", 1)
end

-- Connect to MarketplaceService for clothing purchases
MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
    if not isPurchased then return end
    
    -- Check if the product is a shirt or pants
    local success, assetInfo = pcall(function()
        return MarketplaceService:GetProductInfo(assetId)
    end)
    
    if success and assetInfo and (assetInfo.AssetTypeId == Enum.AssetType.Shirt.Value or assetInfo.AssetTypeId == Enum.AssetType.Pants.Value) then
        onClothingPurchase(player)
    end
end)

-- Note: CrateOpeningEvent is a RemoteEvent that fires from server to client for animations
-- Crate opening tracking is handled directly in the crate purchase handlers via _G.UpdateDailyObjective

-- Note: Coin collection is tracked directly in CoinSpawner.server.lua via _G.UpdateDailyObjective
-- No need to connect to CoinNotificationEvent as that's for client notifications only

-- Create events for other systems to fire
local clothingTryOnEvent = Instance.new("RemoteEvent")
clothingTryOnEvent.Name = "ClothingTryOnEvent"
clothingTryOnEvent.Parent = objectivesFolder

local clothingListingEvent = Instance.new("RemoteEvent")
clothingListingEvent.Name = "ClothingListingEvent"
clothingListingEvent.Parent = objectivesFolder

clothingTryOnEvent.OnServerEvent:Connect(function(player)
    onClothingTryOn(player)
end)

clothingListingEvent.OnServerEvent:Connect(function(player)
    onClothingListing(player)
end)

print("Daily Objectives Handler initialized") 