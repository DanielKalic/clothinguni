-- Centralized Purchase Router
-- Handles all dev product purchases and routes them to appropriate systems

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Wait for ProfileStore to be ready
repeat wait(0.1) until _G.ProfileStoreData and _G.ProfileStoreData.IsReady

print("DEBUG: [PurchaseRouter] Starting centralized purchase router...")

-- Product ID used by multiple systems
local SHARED_PRODUCT_ID = 1910484649

-- Coin dev product IDs
local coinDevProducts = {
    [3293171503] = 500,   -- 500 Coins
    [3293172244] = 1000,  -- 1000 Coins  
    [3293172868] = 10000, -- 10000 Coins
    [3293173356] = 50000  -- 50000 Coins
}

-- Crate dev product IDs
local crateDevProducts = {
    [3286468900] = "Common",     -- Common Crate
    [3286469077] = "Rare",       -- Rare Crate  
    [3286469322] = "Legendary",  -- Legendary Crate
    [3286470000] = "VIP"         -- VIP Crate
}

-- Player context tracking - stores what system initiated the purchase
local playerPurchaseContext = {}

-- System handlers
local systemHandlers = {}

-- Register a system handler
function registerSystemHandler(systemName, handler)
    systemHandlers[systemName] = handler
    print("DEBUG: [PurchaseRouter] Registered system handler:", systemName)
end

-- Set player purchase context
function setPurchaseContext(player, systemName, contextData)
    playerPurchaseContext[player.UserId] = {
        system = systemName,
        data = contextData,
        timestamp = os.time()
    }
    print("DEBUG: [PurchaseRouter] Set purchase context for", player.Name, "- System:", systemName)
end

-- Clear player purchase context
function clearPurchaseContext(player)
    playerPurchaseContext[player.UserId] = nil
    print("DEBUG: [PurchaseRouter] Cleared purchase context for", player.Name)
end

-- Get player purchase context
function getPurchaseContext(player)
    local context = playerPurchaseContext[player.UserId]
    if context then
        -- Check if context is not too old (5 minutes)
        if os.time() - context.timestamp < 300 then
            return context
        else
            -- Clean up old context
            playerPurchaseContext[player.UserId] = nil
            print("DEBUG: [PurchaseRouter] Cleaned up expired context for", player.Name)
        end
    end
    return nil
end

-- Handle coin purchases directly
local function handleCoinPurchase(player, coinAmount)
    print("DEBUG: [PurchaseRouter] Processing coin purchase - giving " .. coinAmount .. " coins to " .. player.Name)
    
    -- Give coins to player
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local coins = leaderstats:FindFirstChild("Coins")
        if coins and coins:IsA("IntValue") then
            coins.Value = coins.Value + coinAmount
            print("DEBUG: [PurchaseRouter] Successfully gave " .. coinAmount .. " coins to " .. player.Name .. ". New balance: " .. coins.Value)
            
            -- Notify player
            local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
            if notificationEvent then
                local message = "Purchase successful! You received " .. coinAmount .. " coins!"
                notificationEvent:FireClient(player, message, Color3.fromRGB(60, 200, 60))
            end
            
            return Enum.ProductPurchaseDecision.PurchaseGranted
        else
            warn("DEBUG: [PurchaseRouter] Could not find Coins value for " .. player.Name)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    else
        warn("DEBUG: [PurchaseRouter] Could not find leaderstats for " .. player.Name)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

-- Wait for crate handler functions to be available
local function waitForCrateHandler()
    local maxWaitTime = 10 -- Maximum wait time in seconds
    local startTime = tick()
    
    -- Wait for the CratePurchaseHandler to set up its functions
    while not (_G.CrateHandler and _G.CrateHandler.selectRandomPet and _G.CrateHandler.givePetToPlayer) do
        if tick() - startTime > maxWaitTime then
            warn("DEBUG: [PurchaseRouter] Timeout waiting for CrateHandler - CrateHandler not available after " .. maxWaitTime .. " seconds")
            -- Try to get basic functions from CratePurchaseHandler if available
            if _G.CrateHandler then
                print("DEBUG: [PurchaseRouter] Partial CrateHandler found, attempting to use it")
                return _G.CrateHandler
            end
            return nil
        end
        wait(0.1)
    end
    
    print("DEBUG: [PurchaseRouter] CrateHandler found and ready")
    return _G.CrateHandler
end

-- Handle crate purchases
local function handleCratePurchase(player, crateType)
    print("DEBUG: [PurchaseRouter] Processing crate purchase - " .. crateType .. " crate for " .. player.Name)
    
    -- Check VIP access for VIP crate
    if crateType == "VIP" then
        -- Wait for crate handler to be available to access hasVIPGamepass function
        local crateHandler = waitForCrateHandler()
        if not crateHandler then
            warn("DEBUG: [PurchaseRouter] CrateHandler not available for VIP check - deferring purchase")
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        
        local hasVIP = false
        local vipCheckSuccess = pcall(function()
            hasVIP = crateHandler.hasVIPGamepass(player)
        end)
        
        if not vipCheckSuccess or not hasVIP then
            print("DEBUG: [PurchaseRouter] " .. player.Name .. " tried to purchase VIP crate without VIP gamepass - denying purchase")
            
            -- Send notification to player
            local notifySuccess = pcall(function()
                crateHandler.notificationEvent:FireClient(player, "VIP gamepass required to purchase VIP crates!", Color3.fromRGB(200, 60, 60))
            end)
            
            if not notifySuccess then
                warn("DEBUG: [PurchaseRouter] Failed to send VIP access denied notification")
            end
            
            return Enum.ProductPurchaseDecision.PurchaseDenied
        end
        
        print("DEBUG: [PurchaseRouter] VIP access confirmed for " .. player.Name)
    end
    
    -- Wait for crate handler to be available
    local crateHandler = waitForCrateHandler()
    if not crateHandler then
        warn("DEBUG: [PurchaseRouter] CrateHandler not available - deferring purchase")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    print("DEBUG: [PurchaseRouter] CrateHandler available, proceeding with crate purchase")
    
    -- Select a random pet
    print("DEBUG: [PurchaseRouter] Attempting to select a random pet from " .. crateType .. " crate")
    local success, pet = pcall(function()
        return crateHandler.selectRandomPet(crateType)
    end)
    
    if not success then
        warn("DEBUG: [PurchaseRouter] Error selecting random pet: " .. tostring(pet))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    if not pet then
        print("DEBUG: [PurchaseRouter] No pets available in " .. crateType .. " crate")
        return Enum.ProductPurchaseDecision.PurchaseDenied
    end
    
    print("DEBUG: [PurchaseRouter] Selected pet: " .. pet.name)
    
    -- Give the pet to the player
    print("DEBUG: [PurchaseRouter] Attempting to give pet to player")
    local giveSuccess, petId = pcall(function()
        return crateHandler.givePetToPlayer(player, pet)
    end)
    
    if not giveSuccess then
        warn("DEBUG: [PurchaseRouter] Error giving pet to player: " .. tostring(petId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Notify player of the reward
    if petId then
        local rarity = pet.instance:GetAttribute("Rarity") or crateType
        print("DEBUG: [PurchaseRouter] Successfully gave pet to player - Rarity: " .. rarity)
        
        -- First send purchase confirmation
        local notifySuccess = pcall(function()
            crateHandler.notificationEvent:FireClient(player, "Purchase successful! Opening " .. crateType .. " Crate...", Color3.fromRGB(60, 200, 60))
        end)
        
        if not notifySuccess then
            warn("DEBUG: [PurchaseRouter] Failed to send purchase confirmation notification")
        end
        
        -- Wait a moment before showing the reward
        task.wait(1.5)
        
        -- Then send the pet received notification
        local message = "You received: " .. pet.name .. " (" .. rarity .. ") from your " .. crateType .. " Crate!"
        print("DEBUG: [PurchaseRouter] Sending notification: " .. message)
        
        local rewardNotifySuccess = pcall(function()
            crateHandler.notificationEvent:FireClient(player, message, Color3.fromRGB(60, 200, 60))
        end)
        
        if not rewardNotifySuccess then
            warn("DEBUG: [PurchaseRouter] Failed to send reward notification")
        end
        
        -- Fire event to show crate opening animation
        print("DEBUG: [PurchaseRouter] Firing crate opening animation event to " .. player.Name)
        local petData = {
            name = pet.name,
            rarity = rarity,
            id = petId
        }
        
        -- Fire with error handling
        local fireSuccess, fireError = pcall(function()
            crateHandler.crateOpeningEvent:FireClient(player, crateType, petData)
        end)
        
        if not fireSuccess then
            warn("DEBUG: [PurchaseRouter] Failed to fire crate opening event: " .. tostring(fireError))
        else
            print("DEBUG: [PurchaseRouter] Successfully fired crate opening event")
        end
        
        -- Update daily objectives for crate opening
        if _G.UpdateDailyObjective then
            local objSuccess = pcall(function()
                _G.UpdateDailyObjective(player, "openCrate", 1)
            end)
            if objSuccess then
                print("DEBUG: [PurchaseRouter] Updated daily objective for crate opening (Robux purchase) for " .. player.Name)
            else
                warn("DEBUG: [PurchaseRouter] Failed to update daily objective")
            end
        else
            warn("DEBUG: [PurchaseRouter] _G.UpdateDailyObjective not found for Robux purchase!")
        end
        
        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        print("DEBUG: [PurchaseRouter] Failed to give pet to player")
        return Enum.ProductPurchaseDecision.PurchaseDenied
    end
end

-- Main ProcessReceipt handler
local function processReceipt(receiptInfo)
    local userId = receiptInfo.PlayerId
    local productId = receiptInfo.ProductId
    local player = Players:GetPlayerByUserId(userId)
    
    print("DEBUG: [PurchaseRouter] Processing receipt - ProductId:", productId, "PlayerId:", userId)
    
    if not player then
        print("DEBUG: [PurchaseRouter] Player not found for userId:", userId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Check if this is a coin purchase
    if coinDevProducts[productId] then
        local coinAmount = coinDevProducts[productId]
        print("DEBUG: [PurchaseRouter] This is a coin purchase for " .. coinAmount .. " coins")
        return handleCoinPurchase(player, coinAmount)
    end
    
    -- Check if this is a crate purchase
    if crateDevProducts[productId] then
        local crateType = crateDevProducts[productId]
        print("DEBUG: [PurchaseRouter] This is a crate purchase for " .. crateType .. " crate")
        return handleCratePurchase(player, crateType)
    end
    
    -- Handle shared product ID
    if productId == SHARED_PRODUCT_ID then
        -- Get the purchase context to determine which system should handle this
        local context = getPurchaseContext(player)
        if not context then
            print("DEBUG: [PurchaseRouter] No purchase context found for", player.Name, "- Cannot route purchase")
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        
        print("DEBUG: [PurchaseRouter] Routing purchase to system:", context.system, "for player:", player.Name)
        
        -- Route to the appropriate system handler
        local handler = systemHandlers[context.system]
        if handler then
            local success, result = pcall(handler, player, context.data, receiptInfo)
            if success then
                -- Clear the context after successful processing
                clearPurchaseContext(player)
                print("DEBUG: [PurchaseRouter] Successfully processed purchase for", player.Name, "via", context.system)
                return result or Enum.ProductPurchaseDecision.PurchaseGranted
            else
                warn("DEBUG: [PurchaseRouter] Handler error for", context.system, ":", result)
                clearPurchaseContext(player)
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
        else
            warn("DEBUG: [PurchaseRouter] No handler found for system:", context.system)
            clearPurchaseContext(player)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    end
    
    -- Not our product, let other handlers deal with it
    print("DEBUG: [PurchaseRouter] Unknown product ID, ignoring")
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Set up the ProcessReceipt callback
MarketplaceService.ProcessReceipt = processReceipt

-- Clean up disconnected players
Players.PlayerRemoving:Connect(function(player)
    playerPurchaseContext[player.UserId] = nil
    print("DEBUG: [PurchaseRouter] Cleaned up context for disconnected player:", player.Name)
end)

-- Expose functions globally for other scripts to use
_G.PurchaseRouter = {
    setPurchaseContext = setPurchaseContext,
    clearPurchaseContext = clearPurchaseContext,
    getPurchaseContext = getPurchaseContext,
    registerSystemHandler = registerSystemHandler
}

-- Create or get the purchase dev product event
local purchaseDevProductEvent = ReplicatedStorage:FindFirstChild("PurchaseDevProductEvent")
if not purchaseDevProductEvent then
    purchaseDevProductEvent = Instance.new("RemoteFunction")
    purchaseDevProductEvent.Name = "PurchaseDevProductEvent"
    purchaseDevProductEvent.Parent = ReplicatedStorage
end

-- Handle coin purchase requests from client
purchaseDevProductEvent.OnServerInvoke = function(player, devProductId, itemName)
    print("DEBUG: [PurchaseRouter] Purchase request from " .. player.Name .. " for " .. itemName)
    print("DEBUG: [PurchaseRouter] DevProductID: " .. devProductId)
    
    -- Check if this is a coin purchase
    if coinDevProducts[devProductId] then
        local coinAmount = coinDevProducts[devProductId]
        print("DEBUG: [PurchaseRouter] This is a coin purchase for " .. coinAmount .. " coins")
        
        -- Prompt the purchase
        local success, errorMessage = pcall(function()
            MarketplaceService:PromptProductPurchase(player, devProductId)
        end)
        
        if not success then
            warn("DEBUG: [PurchaseRouter] Failed to prompt coin purchase: " .. tostring(errorMessage))
            return false
        end
        
        print("DEBUG: [PurchaseRouter] Coin purchase prompt sent successfully for DevProductID: " .. devProductId)
        return true
    end
    
    -- Check if this is a crate purchase
    if crateDevProducts[devProductId] then
        local crateType = crateDevProducts[devProductId]
        print("DEBUG: [PurchaseRouter] This is a crate purchase for " .. crateType .. " crate")
        
        -- Prompt the purchase
        local success, errorMessage = pcall(function()
            MarketplaceService:PromptProductPurchase(player, devProductId)
        end)
        
        if not success then
            warn("DEBUG: [PurchaseRouter] Failed to prompt crate purchase: " .. tostring(errorMessage))
            return false
        end
        
        print("DEBUG: [PurchaseRouter] Crate purchase prompt sent successfully for DevProductID: " .. devProductId)
        return true
    end
    
    -- If not a coin purchase or crate purchase, let other handlers deal with it
    warn("DEBUG: [PurchaseRouter] Unknown dev product ID: " .. devProductId)
    return false
end

print("DEBUG: [PurchaseRouter] Centralized purchase router initialized!") 