-- Rent Billboard Handler
-- Now using ProfileStore for billboard data storage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Wait for ProfileStore to be ready
while not _G.ProfileStoreData or not _G.ProfileStoreData.IsReady do
    task.wait(0.1)
end

local ProfileStoreData = _G.ProfileStoreData

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

-- Duration constants
local NORMAL_DURATION = 259200 -- 3 days (3 * 24 * 60 * 60 = 259200 seconds)
local VIP_DURATION = 604800 -- 7 days (7 * 24 * 60 * 60 = 604800 seconds)

-- Dev Product ID for billboard rental
local BILLBOARD_DEV_PRODUCT_ID = 3293434478

-- Create remote events
local billboardFolder = Instance.new("Folder")
billboardFolder.Name = "RentBillboard"
billboardFolder.Parent = ReplicatedStorage

local rentBillboardEvent = Instance.new("RemoteEvent")
rentBillboardEvent.Name = "RentBillboardEvent"
rentBillboardEvent.Parent = billboardFolder

local getBillboardDataEvent = Instance.new("RemoteFunction")
getBillboardDataEvent.Name = "GetBillboardDataEvent"
getBillboardDataEvent.Parent = billboardFolder

local billboardResponseEvent = Instance.new("RemoteEvent")
billboardResponseEvent.Name = "BillboardResponseEvent"
billboardResponseEvent.Parent = billboardFolder

local removeBillboardEvent = Instance.new("RemoteEvent")
removeBillboardEvent.Name = "RemoveBillboardEvent"
removeBillboardEvent.Parent = billboardFolder

-- Add billboard renewal events
local renewBillboardEvent = Instance.new("RemoteEvent")
renewBillboardEvent.Name = "RenewBillboardEvent"
renewBillboardEvent.Parent = billboardFolder

local renewBillboardSuccessEvent = Instance.new("RemoteEvent")
renewBillboardSuccessEvent.Name = "RenewBillboardSuccessEvent"
renewBillboardSuccessEvent.Parent = billboardFolder

local renewBillboardFailedEvent = Instance.new("RemoteEvent")
renewBillboardFailedEvent.Name = "RenewBillboardFailedEvent"
renewBillboardFailedEvent.Parent = billboardFolder

-- TEST: Add test event for debugging
local testEvent = Instance.new("RemoteEvent")
testEvent.Name = "TestEvent"
testEvent.Parent = billboardFolder

local testResponseEvent = Instance.new("RemoteEvent")
testResponseEvent.Name = "TestResponseEvent"
testResponseEvent.Parent = billboardFolder

-- Notification event
local notificationEvent = ReplicatedStorage:WaitForChild("NotificationEvent")

-- Billboard rotation system
local ROTATION_INTERVAL = 20 -- seconds between billboard changes

-- Function to check if player has VIP gamepass
local function hasVIPGamepass(player)
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
    end)
    return success and ownsGamepass
end

-- Function to validate asset ID
local function validateAssetId(assetId)
    if not assetId or assetId == "" then
        return false, "Invalid asset ID"
    end
    
    -- Check if it's a number
    local numericId = tonumber(assetId)
    if not numericId then
        return false, "Asset ID must be a number"
    end
    
    -- Try to get asset info to validate it exists
    local success, assetInfo = pcall(function()
        return MarketplaceService:GetProductInfo(numericId)
    end)
    
    if not success then
        return false, "Failed to validate asset ID"
    end
    
    if not assetInfo then
        return false, "Asset not found"
    end
    
    -- Accept any asset type (images, decals, etc.)
    -- Common asset types that work with rbxassetid:// include:
    -- Decal (1), Image (13), Audio (3), etc.
    
    return true, "Valid asset"
end

-- Function to get current billboard data using ProfileStore
local function getCurrentBillboard()
    return ProfileStoreData.GetCurrentBillboard()
end

-- Function to save billboard data using ProfileStore
local function saveBillboardData(assetId, playerName, playerId, duration)
    return ProfileStoreData.SaveBillboardData(assetId, playerName, playerId, duration)
end

-- Function to update billboard in workspace
local function updateBillboardInWorkspace(assetId)
    local billboardsFolder = workspace:FindFirstChild("Billboards")
    if not billboardsFolder then
        warn("Billboards folder not found in workspace!")
        return
    end
    
    local updatedScreens = 0
    
    -- Loop through all billboard models in the Billboards folder
    for _, billboardModel in pairs(billboardsFolder:GetChildren()) do
        if billboardModel:IsA("Model") and billboardModel.Name:lower():find("billboard") then
            -- Look for Screen1 and Screen2 parts
            for _, screenPart in pairs(billboardModel:GetChildren()) do
                if screenPart:IsA("Part") and (screenPart.Name == "Screen1" or screenPart.Name == "Screen2") then
                    -- Find the SurfaceGui
                    local surfaceGui = screenPart:FindFirstChildOfClass("SurfaceGui")
                    if surfaceGui then
                        -- Find the ImageLabel inside the SurfaceGui
                        local imageLabel = surfaceGui:FindFirstChildOfClass("ImageLabel")
                        if imageLabel then
                            imageLabel.Image = "rbxassetid://" .. assetId
                            updatedScreens = updatedScreens + 1
                        else
                            warn("ImageLabel not found in SurfaceGui of " .. screenPart.Name .. " in " .. billboardModel.Name)
                        end
                    else
                        warn("SurfaceGui not found in " .. screenPart.Name .. " in " .. billboardModel.Name)
                    end
                end
            end
        end
    end
    
    -- Also update ship billboards in the Ships folder
    local shipsFolder = billboardsFolder:FindFirstChild("Ships")
    if shipsFolder then
        for _, shipModel in pairs(shipsFolder:GetChildren()) do
            if shipModel:IsA("Model") and shipModel.Name:lower():find("shipbillboard") then
                -- Look for Screen1 part in ship billboards
                local screenPart = shipModel:FindFirstChild("Screen1")
                if screenPart and screenPart:IsA("Part") then
                    -- Find the SurfaceGui
                    local surfaceGui = screenPart:FindFirstChildOfClass("SurfaceGui")
                    if surfaceGui then
                        -- Find the ImageLabel inside the SurfaceGui
                        local imageLabel = surfaceGui:FindFirstChildOfClass("ImageLabel")
                        if imageLabel then
                            imageLabel.Image = "rbxassetid://" .. assetId
                            updatedScreens = updatedScreens + 1
                        else
                            warn("ImageLabel not found in SurfaceGui of " .. screenPart.Name .. " in " .. shipModel.Name)
                        end
                    else
                        warn("SurfaceGui not found in " .. screenPart.Name .. " in " .. shipModel.Name)
                    end
                end
            end
        end
    end
    
    print("Updated " .. updatedScreens .. " billboard screens (including ships) with asset ID: " .. assetId)
end

-- Function to clear billboard in workspace
local function clearBillboardInWorkspace()
    local billboardsFolder = workspace:FindFirstChild("Billboards")
    if not billboardsFolder then
        warn("Billboards folder not found in workspace!")
        return
    end
    
    local clearedScreens = 0
    
    -- Loop through all billboard models in the Billboards folder
    for _, billboardModel in pairs(billboardsFolder:GetChildren()) do
        if billboardModel:IsA("Model") and billboardModel.Name:lower():find("billboard") then
            -- Look for Screen1 and Screen2 parts
            for _, screenPart in pairs(billboardModel:GetChildren()) do
                if screenPart:IsA("Part") and (screenPart.Name == "Screen1" or screenPart.Name == "Screen2") then
                    -- Find the SurfaceGui
                    local surfaceGui = screenPart:FindFirstChildOfClass("SurfaceGui")
                    if surfaceGui then
                        -- Find the ImageLabel inside the SurfaceGui
                        local imageLabel = surfaceGui:FindFirstChildOfClass("ImageLabel")
                        if imageLabel then
                            imageLabel.Image = "" -- Clear the image
                            clearedScreens = clearedScreens + 1
                        end
                    end
                end
            end
        end
    end
    
    -- Also clear ship billboards in the Ships folder
    local shipsFolder = billboardsFolder:FindFirstChild("Ships")
    if shipsFolder then
        for _, shipModel in pairs(shipsFolder:GetChildren()) do
            if shipModel:IsA("Model") and shipModel.Name:lower():find("shipbillboard") then
                -- Look for Screen1 part in ship billboards
                local screenPart = shipModel:FindFirstChild("Screen1")
                if screenPart and screenPart:IsA("Part") then
                    -- Find the SurfaceGui
                    local surfaceGui = screenPart:FindFirstChildOfClass("SurfaceGui")
                    if surfaceGui then
                        -- Find the ImageLabel inside the SurfaceGui
                        local imageLabel = surfaceGui:FindFirstChildOfClass("ImageLabel")
                        if imageLabel then
                            imageLabel.Image = "" -- Clear the image
                            clearedScreens = clearedScreens + 1
                        end
                    end
                end
            end
        end
    end
    
    print("Cleared " .. clearedScreens .. " billboard screens (including ships)")
end

-- Store pending billboard requests
local pendingBillboardRequests = {}

-- Function to renew a billboard (moved to top before it's used)
local function renewBillboard(player, billboardIndex)
    local playerBillboards = ProfileStoreData.GetPlayerBillboards(player.UserId, true)
    
    if not playerBillboards[billboardIndex] then
        warn("Billboard index " .. billboardIndex .. " not found for player " .. player.Name)
        return false
    end
    
    local billboard = playerBillboards[billboardIndex]
    local currentTime = os.time()
    
    -- Check if billboard is actually expired
    if billboard.expiresAt > currentTime then
        warn("Billboard is not expired for player " .. player.Name)
        return false
    end
    
    -- Check if player has VIP gamepass for duration
    local hasLongerListings = hasVIPGamepass(player)
    local renewalDuration = hasLongerListings and VIP_DURATION or NORMAL_DURATION
    local newExpiration = currentTime + renewalDuration
    
    print("DEBUG: [BillboardHandler] Renewing billboard for", player.Name, "New expiration:", newExpiration)
    
    -- Update the billboard's expiration time using ProfileStore method
    local success = ProfileStoreData.RenewBillboard(player.UserId, billboard.assetId, billboard.rentedAt, newExpiration)
    
    if success then
        print("DEBUG: [BillboardHandler] Billboard renewed successfully")
        return true
    else
        warn("Failed to renew billboard in ProfileStore")
        return false
    end
end

-- Handle rent billboard requests
rentBillboardEvent.OnServerEvent:Connect(function(player, assetId)
    print("Billboard rent request from " .. player.Name .. " for asset ID: " .. assetId)
    print("DEBUG: [BillboardHandler] Using dev product ID:", BILLBOARD_DEV_PRODUCT_ID)
    
    -- Validate asset ID
    print("DEBUG: [BillboardHandler] Validating asset ID:", assetId)
    local isValid, message
    local validateSuccess, validateError = pcall(function()
        isValid, message = validateAssetId(assetId)
    end)
    
    if not validateSuccess then
        print("DEBUG: [BillboardHandler] Error during asset validation:", tostring(validateError))
        billboardResponseEvent:FireClient(player, false, "Failed to validate asset. Please try again.")
        return
    end
    
    if not isValid then
        print("DEBUG: [BillboardHandler] Asset validation failed:", message)
        billboardResponseEvent:FireClient(player, false, message)
        return
    end
    print("DEBUG: [BillboardHandler] Asset validation passed")
    
    -- Check if there's already an active billboard
    print("DEBUG: [BillboardHandler] Checking for existing billboard...")
    local currentBillboard = getCurrentBillboard()
    if currentBillboard then
        print("DEBUG: [BillboardHandler] Found active billboard system with", #ProfileStoreData.GetAllActiveBillboards(), "active billboards")
    else
        print("DEBUG: [BillboardHandler] No active billboards found")
    end
    
    -- Allow all players to rent billboards (they will rotate)
    print("DEBUG: [BillboardHandler] Proceeding with billboard rental...")
    
    -- Store the request and prompt for dev product purchase
    pendingBillboardRequests[player.UserId] = {
        action = "purchase",
        assetId = assetId,
        timestamp = os.time()
    }
    
    -- Verify dev product exists first
    print("DEBUG: [BillboardHandler] Attempting to verify dev product:", BILLBOARD_DEV_PRODUCT_ID)
    local productExists = false
    local productInfo = nil
    local verifySuccess, verifyError = pcall(function()
        productInfo = MarketplaceService:GetProductInfo(BILLBOARD_DEV_PRODUCT_ID)
        productExists = productInfo ~= nil
    end)
    
    if not verifySuccess then
        print("DEBUG: [BillboardHandler] Error verifying dev product:", tostring(verifyError))
        pendingBillboardRequests[player.UserId] = nil
        billboardResponseEvent:FireClient(player, false, "Failed to verify billboard service. Error: " .. tostring(verifyError))
        return
    end
    
    if not productExists or not productInfo then
        print("DEBUG: [BillboardHandler] Dev product does not exist or is not accessible:", BILLBOARD_DEV_PRODUCT_ID)
        pendingBillboardRequests[player.UserId] = nil
        billboardResponseEvent:FireClient(player, false, "Billboard rental service is currently unavailable.")
        return
    end
    
    print("DEBUG: [BillboardHandler] Dev product verified successfully!")
    print("DEBUG: [BillboardHandler] Product Name:", productInfo.Name)
    print("DEBUG: [BillboardHandler] Product Price:", productInfo.PriceInRobux, "Robux")
    
    -- Prompt dev product purchase
    print("DEBUG: [BillboardHandler] Attempting to prompt purchase for player:", player.Name, "Product ID:", BILLBOARD_DEV_PRODUCT_ID)
    
    local success, err = pcall(function()
        MarketplaceService:PromptProductPurchase(player, BILLBOARD_DEV_PRODUCT_ID)
    end)
    
    if not success then
        print("DEBUG: [BillboardHandler] Failed to prompt purchase:", tostring(err))
        pendingBillboardRequests[player.UserId] = nil
        billboardResponseEvent:FireClient(player, false, "Failed to prompt purchase. Please try again.")
        warn("Failed to prompt dev product purchase: " .. tostring(err))
    else
        print("DEBUG: [BillboardHandler] Purchase prompt sent successfully for player:", player.Name)
        
        -- Set up a timeout to clean up if no response
        local userId = player.UserId
        task.spawn(function()
            task.wait(30) -- 30 second timeout
            -- Check if the request is still pending
            if pendingBillboardRequests[userId] then
                local currentPlayer = Players:GetPlayerByUserId(userId)
                local playerName = currentPlayer and currentPlayer.Name or ("UserId: " .. userId)
                print("DEBUG: [BillboardHandler] Billboard request timed out for player:", playerName)
                pendingBillboardRequests[userId] = nil
                -- Only fire client event if player is still in game
                if currentPlayer then
                    billboardResponseEvent:FireClient(currentPlayer, false, "Purchase request timed out. Please try again.")
                end
            end
        end)
    end
end)

-- Handle dev product purchases (backup method)
local function processBillboardReceipt(receiptInfo)
    print("DEBUG: [BillboardHandler] processBillboardReceipt called for ProductId:", receiptInfo.ProductId, "PlayerId:", receiptInfo.PlayerId)
    
    if receiptInfo.ProductId == BILLBOARD_DEV_PRODUCT_ID then
        print("DEBUG: [BillboardHandler] Billboard product detected in ProcessReceipt - but should have been handled by PromptProductPurchaseFinished")
        -- Just return PurchaseGranted since we handle it in PromptProductPurchaseFinished
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    return nil -- Let other handlers process this
end

-- Set up ProcessReceipt hook to work with other handlers
local function setupBillboardProcessReceiptHook()
	-- DISABLED: Using centralized PurchaseRouter instead
	print("DEBUG: [BillboardHandler] ProcessReceipt disabled - using centralized PurchaseRouter")
	
	print("DEBUG: [BillboardHandler] Setting up ProcessReceipt hook")
	local originalProcessReceipt = nil
	
	-- Get the current ProcessReceipt handler if it exists
	local success, result = pcall(function()
		return MarketplaceService.ProcessReceipt
	end)
	
	if success and result and type(result) == "function" then
		originalProcessReceipt = result
		print("DEBUG: [BillboardHandler] Found existing ProcessReceipt handler")
	else
		print("DEBUG: [BillboardHandler] No existing ProcessReceipt handler found")
	end
end

-- Use our safer approach to register the ProcessReceipt handler
setupBillboardProcessReceiptHook()

-- Add purchase tracking for debugging
local promptSuccess, promptError = pcall(function()
    MarketplaceService.PromptProductPurchaseFinished:Connect(function(player, productId, wasPurchased)
        -- Get player name safely
        local playerName = "Unknown"
        local userId = nil
        
        if typeof(player) == "Instance" and player:IsA("Player") then
            playerName = player.Name
            userId = player.UserId
        elseif typeof(player) == "number" then
            userId = player
            local actualPlayer = Players:GetPlayerByUserId(userId)
            if actualPlayer then
                playerName = actualPlayer.Name
                player = actualPlayer
            end
        end
        
        print("DEBUG: [BillboardHandler] PromptProductPurchaseFinished - Player:", playerName, "ProductId:", productId, "WasPurchased:", wasPurchased)
        
        if productId == BILLBOARD_DEV_PRODUCT_ID and userId then
            if wasPurchased then
                print("DEBUG: [BillboardHandler] Player " .. playerName .. " completed purchase of billboard product")
                print("DEBUG: [BillboardHandler] Checking pending requests for userId:", userId)
                print("DEBUG: [BillboardHandler] Current pending requests:", pendingBillboardRequests)
                
                -- Handle the purchase directly here since ProcessReceipt may not be reliable
                if pendingBillboardRequests[userId] and player then
                    print("DEBUG: [BillboardHandler] Processing purchase directly from PromptProductPurchaseFinished")
                    
                    local requestData = pendingBillboardRequests[userId]
                    
                    -- Clear the pending request
                    pendingBillboardRequests[userId] = nil
                    
                    if requestData.action == "renewal" then
                        -- Handle billboard renewal
                        print("DEBUG: [BillboardHandler] Processing billboard renewal for index:", requestData.billboardIndex)
                        
                        local renewalSuccess = renewBillboard(player, requestData.billboardIndex)
                        
                        if renewalSuccess then
                            print("DEBUG: [BillboardHandler] Firing renewBillboardSuccessEvent to client for index:", requestData.billboardIndex)
                            if renewBillboardSuccessEvent then
                                print("DEBUG: [BillboardHandler] Event object details:")
                                print("DEBUG: [BillboardHandler] - Name:", renewBillboardSuccessEvent.Name)
                                print("DEBUG: [BillboardHandler] - Parent:", renewBillboardSuccessEvent.Parent and renewBillboardSuccessEvent.Parent.Name or "nil")
                                print("DEBUG: [BillboardHandler] - ClassName:", renewBillboardSuccessEvent.ClassName)
                                print("DEBUG: [BillboardHandler] - Player receiving event:", player.Name, "UserId:", player.UserId)
                                
                                renewBillboardSuccessEvent:FireClient(player, requestData.billboardIndex)
                                print("DEBUG: [BillboardHandler] renewBillboardSuccessEvent fired successfully")
                            else
                                warn("DEBUG: [BillboardHandler] renewBillboardSuccessEvent is nil!")
                            end
                            
                            -- Send notification
                            local notificationMessage = player.Name .. " renewed their billboard!"
                            for _, otherPlayer in pairs(Players:GetPlayers()) do
                                if notificationEvent then
                                    notificationEvent:FireClient(otherPlayer, notificationMessage, Color3.fromRGB(0, 255, 0))
                                end
                            end
                            
                            print("Billboard renewed by " .. player.Name)
                        else
                            print("DEBUG: [BillboardHandler] Firing renewBillboardFailedEvent to client for index:", requestData.billboardIndex)
                            if renewBillboardFailedEvent then
                                renewBillboardFailedEvent:FireClient(player, requestData.billboardIndex)
                                print("DEBUG: [BillboardHandler] renewBillboardFailedEvent fired successfully")
                            else
                                warn("DEBUG: [BillboardHandler] renewBillboardFailedEvent is nil!")
                            end
                        end
                    else
                        -- Handle new billboard purchase
                        local assetId = requestData.assetId
                        print("DEBUG: [BillboardHandler] Found pending request for asset ID:", assetId)
                        
                        -- Set billboard duration based on gamepass ownership
                        local hasLongerListings = hasVIPGamepass(player)
                        local billboardDuration = hasLongerListings and VIP_DURATION or NORMAL_DURATION
                        
                        print("DEBUG: [BillboardHandler] Saving billboard data...")
                        -- Save billboard data (adds to rotation)
                        local success = saveBillboardData(assetId, player.Name, player.UserId, billboardDuration)
                        if not success then
                            print("DEBUG: [BillboardHandler] Failed to save billboard data")
                            billboardResponseEvent:FireClient(player, false, "Failed to rent billboard. Please contact support.")
                            return
                        end
                        
                        print("DEBUG: [BillboardHandler] Billboard added to rotation")
                        
                        -- Send success response
                        local durationText = hasLongerListings and "7 days" or "3 days"
                        local successMessage = "Billboard added to rotation for " .. durationText .. "!"
                        
                        print("DEBUG: [BillboardHandler] Sending success response to client")
                        billboardResponseEvent:FireClient(player, true, successMessage, true) -- true indicates to close GUI
                        
                        -- Send notification to all players
                        local totalActive = #ProfileStoreData.GetAllActiveBillboards()
                        local notificationMessage = player.Name .. " added a billboard to the rotation! (" .. totalActive .. " active)"
                        
                        for _, otherPlayer in pairs(Players:GetPlayers()) do
                            if notificationEvent then
                                notificationEvent:FireClient(otherPlayer, notificationMessage, Color3.fromRGB(255, 215, 0))
                            end
                        end
                        
                        print("Billboard added to rotation by " .. player.Name .. " for " .. durationText .. " (Total active: " .. totalActive .. ")")
                    end
                else
                    print("DEBUG: [BillboardHandler] WARNING: No pending request found or player invalid!")
                end
            else
                print("DEBUG: [BillboardHandler] Player " .. playerName .. " cancelled purchase of billboard product")
                
                -- Clean up pending request
                if pendingBillboardRequests[userId] then
                    print("DEBUG: [BillboardHandler] Cleaning up pending billboard request due to cancellation")
                    pendingBillboardRequests[userId] = nil
                    if player and typeof(player) == "Instance" and player.Parent then
                        billboardResponseEvent:FireClient(player, false, "Purchase cancelled.")
                    end
                end
            end
        end
    end)
    
    print("DEBUG: [BillboardHandler] Successfully connected to PromptProductPurchaseFinished event")
end)

if not promptSuccess then
    warn("DEBUG: [BillboardHandler] Failed to connect to PromptProductPurchaseFinished event: " .. tostring(promptError))
end

-- Clean up old pending requests (older than 5 minutes)
task.spawn(function()
    while true do
        task.wait(60) -- Check every minute
        local currentTime = os.time()
        for playerId, requestData in pairs(pendingBillboardRequests) do
            if currentTime - requestData.timestamp > 300 then -- 5 minutes
                pendingBillboardRequests[playerId] = nil
                print("Cleaned up old billboard request for player " .. playerId)
            end
        end
    end
end)

-- Handle get billboard data requests
getBillboardDataEvent.OnServerInvoke = function(player)
    print("DEBUG: [BillboardHandler] getBillboardDataEvent called for player:", player.Name, "UserId:", player.UserId)
    
    -- TEMPORARY DEBUG: Check raw DataStore vs ProfileStore
    local DataStoreService = game:GetService("DataStoreService")
    local rawBillboardStore = DataStoreService:GetDataStore("Billboards")
    
    local rawDataSuccess, rawData = pcall(function()
        return rawBillboardStore:GetAsync("global_billboards")
    end)
    
    if rawDataSuccess and rawData then
        print("DEBUG: [BillboardHandler] Raw DataStore data found:")
        print("DEBUG: [BillboardHandler] Raw data type:", type(rawData))
        
        if type(rawData) == "table" then
            for key, value in pairs(rawData) do
                print("DEBUG: [BillboardHandler] Raw data key:", key, "type:", type(value))
                
                if key == "Data" and type(value) == "table" then
                    for dataKey, dataValue in pairs(value) do
                        print("DEBUG: [BillboardHandler] Raw Data." .. dataKey .. ":", type(dataValue))
                        
                        if dataKey == "active" and type(dataValue) == "table" then
                            print("DEBUG: [BillboardHandler] Raw active billboards count:", #dataValue)
                            for i, billboard in ipairs(dataValue) do
                                print("DEBUG: [BillboardHandler] Raw billboard", i, "PlayerId:", billboard.playerId, "AssetId:", billboard.assetId)
                            end
                        end
                    end
                end
            end
        end
    else
        print("DEBUG: [BillboardHandler] No raw DataStore data found or error:", tostring(rawData))
    end
    
    -- Check ProfileStore data
    print("DEBUG: [BillboardHandler] ProfileStore BillboardsProfile active:", ProfileStoreData.BillboardsProfile and ProfileStoreData.BillboardsProfile():IsActive())
    
    -- Return all billboards owned by this player (including expired ones for renewal)
    local playerBillboards = ProfileStoreData.GetPlayerBillboards(player.UserId, true)
    print("DEBUG: [BillboardHandler] ProfileStoreData.GetPlayerBillboards returned", #playerBillboards, "billboards for player", player.Name)
    
    -- Debug: Let's also check all billboards to see what's in the system
    local allActiveBillboards = ProfileStoreData.GetAllActiveBillboards()
    print("DEBUG: [BillboardHandler] Total active billboards in system:", #allActiveBillboards)
    for i, billboard in ipairs(allActiveBillboards) do
        print("DEBUG: [BillboardHandler] Billboard", i, "- PlayerId:", billboard.playerId, "PlayerName:", billboard.playerName, "AssetId:", billboard.assetId)
    end
    
    -- Add time remaining and format display for each billboard
    local currentTime = os.time()
    for i, billboard in ipairs(playerBillboards) do
        print("DEBUG: [BillboardHandler] Processing player billboard", i, "- AssetId:", billboard.assetId, "ExpiresAt:", billboard.expiresAt)
        local timeLeft = billboard.expiresAt - currentTime
        billboard.timeLeft = timeLeft
        billboard.isExpired = timeLeft <= 0
        
        -- Format time display
        if timeLeft > 0 then
            local hours = math.floor(timeLeft / 3600)
            local minutes = math.floor((timeLeft % 3600) / 60)
            billboard.timeDisplay = hours .. "h " .. minutes .. "m"
        else
            billboard.timeDisplay = "Expired"
        end
    end
    
    print("DEBUG: [BillboardHandler] Returning", #playerBillboards, "billboards to client")
    return playerBillboards
end

-- Handle remove billboard requests
removeBillboardEvent.OnServerEvent:Connect(function(player)
    print("Billboard removal request from " .. player.Name)
    
    -- Check if player has any active billboards
    local activeBillboards = ProfileStoreData.GetAllActiveBillboards()
    local playerHasBillboard = false
    
    for _, billboard in ipairs(activeBillboards) do
        if billboard.playerId == player.UserId then
            playerHasBillboard = true
            break
        end
    end
    
    if not playerHasBillboard then
        billboardResponseEvent:FireClient(player, false, "You don't have any active billboards to remove.")
        return
    end
    
    -- Remove billboard from ProfileStore
    local success = ProfileStoreData.RemoveBillboardByPlayer(player.UserId)
    
    if not success then
        warn("Failed to remove billboard data from ProfileStore")
        billboardResponseEvent:FireClient(player, false, "Failed to remove billboard. Please try again.")
        return
    end
    
    -- Send success response
    billboardResponseEvent:FireClient(player, true, "Your billboard has been removed from rotation!")
    
    -- Send notification to all players
    local totalActive = #ProfileStoreData.GetAllActiveBillboards()
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if notificationEvent then
            notificationEvent:FireClient(otherPlayer, player.Name .. " removed their billboard from rotation! (" .. totalActive .. " active)", Color3.fromRGB(255, 165, 0))
        end
    end
    
    print("Billboard removed from rotation by " .. player.Name .. " (Total active: " .. totalActive .. ")")
end)

-- Handle billboard renewal requests
renewBillboardEvent.OnServerEvent:Connect(function(player, billboardIndex)
    print("DEBUG: [BillboardHandler] Received renewal request from", player.Name, "for billboard index:", billboardIndex)
    
    -- Store pending renewal request
    pendingBillboardRequests[player.UserId] = {
        action = "renewal",
        billboardIndex = billboardIndex,
        timestamp = os.time()
    }
    
    -- Prompt dev product purchase for renewal
    print("DEBUG: [BillboardHandler] Prompting renewal purchase for player:", player.Name)
    
    local success, err = pcall(function()
        MarketplaceService:PromptProductPurchase(player, BILLBOARD_DEV_PRODUCT_ID)
    end)
    
    if not success then
        print("DEBUG: [BillboardHandler] Failed to prompt renewal purchase:", tostring(err))
        pendingBillboardRequests[player.UserId] = nil
        renewBillboardFailedEvent:FireClient(player, billboardIndex)
    else
        print("DEBUG: [BillboardHandler] Renewal purchase prompt sent successfully")
    end
end)

-- Billboard rotation system
local function startBillboardRotation()
    task.spawn(function()
        print("DEBUG: [BillboardHandler] Starting billboard rotation system...")
        
        while true do
            task.wait(ROTATION_INTERVAL)
            
            -- Get all active billboards
            local activeBillboards = ProfileStoreData.GetAllActiveBillboards()
            
            if #activeBillboards > 0 then
                -- Get next billboard in rotation
                local nextBillboard = ProfileStoreData.GetNextBillboard()
                
                if nextBillboard then
                    print("DEBUG: [BillboardHandler] Rotating to billboard:", nextBillboard.assetId, "by", nextBillboard.playerName)
                    updateBillboardInWorkspace(nextBillboard.assetId)
                else
                    print("DEBUG: [BillboardHandler] No valid billboard to rotate to")
                    clearBillboardInWorkspace()
                end
            else
                -- No active billboards, clear the display
                clearBillboardInWorkspace()
            end
        end
    end)
end

-- Function to check for expired billboards
local function checkExpiredBillboards()
    ProfileStoreData.CleanupExpiredBillboards()
    
    -- If no billboards remain, clear workspace
    local activeBillboards = ProfileStoreData.GetAllActiveBillboards()
    if #activeBillboards == 0 then
        clearBillboardInWorkspace()
    end
end

-- Check for expired billboards every 5 minutes
task.spawn(function()
    while true do
        task.wait(300) -- 5 minutes
        checkExpiredBillboards()
    end
end)

-- Initialize billboard system
task.spawn(function()
    task.wait(5) -- Wait for workspace to load
    
    -- Check if there are active billboards and start rotation
    local activeBillboards = ProfileStoreData.GetAllActiveBillboards()
    
    if #activeBillboards > 0 then
        print("Found", #activeBillboards, "active billboards, starting rotation system")
        
        -- Show the first billboard immediately
        local currentBillboard = ProfileStoreData.GetCurrentBillboard()
        if currentBillboard then
            updateBillboardInWorkspace(currentBillboard.assetId)
            print("Displaying initial billboard:", currentBillboard.assetId, "by", currentBillboard.playerName)
        end
    else
        clearBillboardInWorkspace()
        print("No active billboards found")
    end
    
    -- Start the rotation system
    startBillboardRotation()
end)

-- TEST: Handle test event to verify RemoteEvent communication
testEvent.OnServerEvent:Connect(function(player, message)
    print("DEBUG: [TEST SERVER] Received test event from", player.Name, "with message:", message)
    
    -- Fire back a test response
    task.wait(0.1) -- Small delay to simulate processing
    testResponseEvent:FireClient(player, "Test response from server - RemoteEvents are working!")
    print("DEBUG: [TEST SERVER] Fired test response back to", player.Name)
end)

wait(5)
warn(_G.ProfileStoreData)