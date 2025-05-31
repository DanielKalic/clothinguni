-- Crate Purchase Handler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Configuration
local USE_TEST_PURCHASE = true -- Set to false for real Robux purchases in production

-- Load ProfileStore Pet Handler
local ProfileStorePetHandler = require(ReplicatedStorage:WaitForChild("ProfileStorePetHandler"))

print("CratePurchaseHandler starting")

-- Create or get the Remote Function
local purchaseDevProductEvent = ReplicatedStorage:FindFirstChild("PurchaseDevProductEvent")
if not purchaseDevProductEvent then
    purchaseDevProductEvent = Instance.new("RemoteFunction")
    purchaseDevProductEvent.Name = "PurchaseDevProductEvent"
    purchaseDevProductEvent.Parent = ReplicatedStorage
end

-- Create or get the notification event
local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
if not notificationEvent then
    notificationEvent = Instance.new("RemoteEvent")
    notificationEvent.Name = "NotificationEvent"
    notificationEvent.Parent = ReplicatedStorage
end

-- Create or get the crate opening event - ENSURE THIS EXISTS
local crateOpeningEvent = ReplicatedStorage:FindFirstChild("CrateOpeningEvent")
if not crateOpeningEvent then
    print("Creating CrateOpeningEvent in ReplicatedStorage")
    crateOpeningEvent = Instance.new("RemoteEvent")
    crateOpeningEvent.Name = "CrateOpeningEvent"
    crateOpeningEvent.Parent = ReplicatedStorage
else
    print("CrateOpeningEvent already exists in ReplicatedStorage")
end

-- Create the rewards config module if it doesn't exist
if not ReplicatedStorage:FindFirstChild("CrateRewardsConfig") then
    local crateRewardsConfig = Instance.new("ModuleScript")
    crateRewardsConfig.Name = "CrateRewardsConfig"
    crateRewardsConfig.Source = [[
-- Crate Rewards Configuration
-- This module stores all crate rewards and can be easily updated

return {
    ["Common"] = {
        devProductId = 3286468900,
        petFolder = "Pets/Common", -- Path to the pet models in ReplicatedStorage
        chances = {
            -- Define the chances (0-100%) for each pet
            -- The actual pets will be loaded dynamically from the folder
            -- Format: [petName] = chancePercentage
            -- Sum of all chances should be 100
            -- You can add more pets by just placing them in the folder
        }
    },
    ["Rare"] = {
        devProductId = 3286469077,
        petFolder = "Pets/Rare",
        chances = {
            -- Chances will be automatically distributed if not specified
        }
    },
    ["Legendary"] = {
        devProductId = 3286469322,
        petFolder = "Pets/Legendary",
        chances = {
            -- Chances will be automatically distributed if not specified
        }
    },
    ["VIP"] = {
        petFolder = "Pets/VIP",
        chances = {
            -- Chances will be automatically distributed if not specified
        }
    }
}
    ]]
    crateRewardsConfig.Parent = ReplicatedStorage
end

-- Load the crate configs from the ModuleScript
local crateConfigs = require(ReplicatedStorage:WaitForChild("CrateRewardsConfig"))

-- Data store to track owned pets
local ownedPetsStore = DataStoreService:GetDataStore("OwnedPets")

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

-- Function to get all pets from a folder
local function getPetsFromFolder(folderPath)
    print("DEBUG: getPetsFromFolder called with path: " .. folderPath)
    local folder = ReplicatedStorage
    for _, pathPart in ipairs(string.split(folderPath, "/")) do
        print("DEBUG: Looking for path part: " .. pathPart)
        folder = folder:FindFirstChild(pathPart)
        if not folder then
            print("DEBUG: Path part not found: " .. pathPart)
            return {}
        end
    end
    
    print("DEBUG: Found folder: " .. folder:GetFullName())
    local pets = {}
    for _, pet in ipairs(folder:GetChildren()) do
        print("DEBUG: Found child in folder: " .. pet.Name .. " (Class: " .. pet.ClassName .. ")")
        if pet:IsA("Model") or pet:IsA("MeshPart") or pet:IsA("Folder") then
            print("DEBUG: Adding pet: " .. pet.Name)
            table.insert(pets, {
                name = pet.Name,
                instance = pet,
                folder = folderPath -- Store the folder path for rarity determination
            })
        end
    end
    
    print("DEBUG: Returning " .. #pets .. " pets")
    return pets
end

-- Function to select a random pet based on rarity and chances
local function selectRandomPet(crateType)
    print("DEBUG: selectRandomPet called for crate type: " .. crateType)
    local config = crateConfigs[crateType]
    if not config then
        print("DEBUG: Config not found for crate type: " .. crateType)
        return nil
    end
    
    print("DEBUG: Using pet folder: " .. config.petFolder)
    local pets = getPetsFromFolder(config.petFolder)
    print("DEBUG: Found " .. #pets .. " pets in folder")
    
    if #pets == 0 then
        print("DEBUG: No pets found in folder: " .. config.petFolder)
        return nil
    end
    
    -- Print the pet names for debugging
    for i, pet in ipairs(pets) do
        print("DEBUG: Pet " .. i .. ": " .. pet.name)
    end
    
    -- If chances are defined, use them; otherwise distribute evenly
    local chanceMap = {}
    local totalChance = 0
    
    if next(config.chances) then
        print("DEBUG: Using defined chances for pets")
        -- Use defined chances
        for _, pet in ipairs(pets) do
            local chance = config.chances[pet.name] or 1 -- Default to 1% if not specified
            print("DEBUG: Pet " .. pet.name .. " has chance: " .. chance)
            chanceMap[pet.name] = chance
            totalChance = totalChance + chance
        end
    else
        print("DEBUG: Using even distribution of chances for all pets")
        -- Distribute chances evenly
        local evenChance = 100 / #pets
        for _, pet in ipairs(pets) do
            chanceMap[pet.name] = evenChance
            totalChance = totalChance + evenChance
        end
    end
    
    print("DEBUG: Total chance: " .. totalChance)
    
    -- Select a random pet based on chances
    local randomValue = math.random(1, totalChance)
    print("DEBUG: Random value: " .. randomValue)
    local currentChance = 0
    
    for _, pet in ipairs(pets) do
        currentChance = currentChance + chanceMap[pet.name]
        print("DEBUG: Pet " .. pet.name .. " current cumulative chance: " .. currentChance)
        if randomValue <= currentChance then
            print("DEBUG: Selected pet: " .. pet.name)
            return pet
        end
    end
    
    -- Fallback to first pet if something goes wrong
    print("DEBUG: Falling back to first pet: " .. pets[1].name)
    return pets[1]
end

-- Function to give a pet to a player
local function givePetToPlayer(player, pet)
    local success, errorMessage = pcall(function()
        local userId = player.UserId
        
        -- Get current owned pets
        local ownedPets = ProfileStorePetHandler:GetPlayerPets(userId)
        
        -- Add new pet if not at maximum
        local MAX_PETS = 50 -- Maximum number of pets a player can own
        
        if #ownedPets >= MAX_PETS then
            -- Player has too many pets, give coins instead
            local leaderstats = player:FindFirstChild("leaderstats")
            if leaderstats then
                local coins = leaderstats:FindFirstChild("Coins")
                if coins and coins:IsA("IntValue") then
                    -- Check if player has VIP gamepass for 2x coins
                    local isVIP = hasVIPGamepass(player)
                    local compensationCoins = isVIP and 500 or 250  -- VIP gets 500, regular gets 250
                    
                    coins.Value = coins.Value + compensationCoins
                    
                    -- Fire notification for coins compensation
                    local message = "You have too many pets! Received " .. compensationCoins .. " coins instead."
                    if isVIP then
                        message = message .. " (VIP 2x)"
                    end
                    notificationEvent:FireClient(player, message, Color3.fromRGB(255, 215, 0))
                end
            end
            return false, "Too many pets"
        end
        
        -- Get rarity from attribute, or from the folder name (the folder structure determines rarity)
        local petRarity = pet.instance:GetAttribute("Rarity")
        if not petRarity or petRarity == "" then
            -- Extract rarity from folder path if attribute not set
            local pathParts = string.split(pet.folder, "/")
            for _, part in ipairs(pathParts) do
                if part == "Common" or part == "Rare" or part == "Legendary" or part == "VIP" then
                    petRarity = part
                    break
                end
            end
        end
        
        -- Create the pet data
        local petData = {
            name = pet.name,
            rarity = petRarity or "Common", -- Use extracted rarity, fallback to Common
            level = 1,
            xp = 0,
            acquiredAt = os.time()
        }
        
        -- Save to ProfileStore
        local savePetSuccess, petId = ProfileStorePetHandler:SavePet(userId, petData)
        
        if not savePetSuccess then
            warn("Failed to save pet to ProfileStore")
            return false, "Failed to save pet"
        end
        
        -- Add XP for getting a new pet
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local xp = leaderstats:FindFirstChild("XP")
            if xp and xp:IsA("IntValue") then
                xp.Value = xp.Value + 50 -- Give 50 XP for a new pet
                
                -- Fire notification for XP gained
                notificationEvent:FireClient(player, "You earned 50 XP for getting a new pet!", Color3.fromRGB(0, 200, 255))
            end
        end
        
        return true, petId
    end)
    
    if not success then
        warn("Failed to give pet: " .. tostring(errorMessage))
        return false, nil
    end
    
    return true, nil
end

-- Function to check if player owns VIP gamepass
local function hasVIPGamepass(player)
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
    end)
    return success and ownsGamepass
end

-- Expose functions globally for PurchaseRouter to use (early setup)
print("DEBUG: [CratePurchaseHandler] Setting up global CrateHandler functions")
_G.CrateHandler = {
    selectRandomPet = selectRandomPet,
    givePetToPlayer = givePetToPlayer,
    hasVIPGamepass = hasVIPGamepass,
    crateConfigs = crateConfigs,
    notificationEvent = notificationEvent,
    crateOpeningEvent = crateOpeningEvent
}
print("DEBUG: [CratePurchaseHandler] Global CrateHandler functions ready")

-- Global setup moved to end of file to ensure all functions are defined

-- Define coin purchase dev product IDs
local coinDevProducts = {
    [3293171503] = 500,   -- 500 Coins
    [3293172244] = 1000,  -- 1000 Coins  
    [3293172868] = 10000, -- 10000 Coins
    [3293173356] = 50000  -- 50000 Coins
}

-- Handle remote function calls
purchaseDevProductEvent.OnServerInvoke = function(player, devProductId, crateName)
    print("Purchase request from " .. player.Name .. " for " .. crateName)
    
    -- Add more detailed logging
    print("DEBUG: ProcessPurchase - DevProductID: " .. devProductId)
    print("DEBUG: ProcessPurchase - Item: " .. crateName)
    
    -- Check if this is a coin purchase - let PurchaseRouter handle it
    if coinDevProducts[devProductId] then
        print("DEBUG: This is a coin purchase - letting PurchaseRouter handle it")
            return false
    end
    
    -- Handle as crate purchase
    print("DEBUG: ProcessPurchase - Crate config exists: " .. tostring(crateConfigs[crateName] ~= nil))
    
    -- Verify the dev product ID matches the crate
    local crateConfig = crateConfigs[crateName]
    if not crateConfig or crateConfig.devProductId ~= devProductId then
        warn("Invalid dev product ID or crate name")
        return false
    end
    
    -- Prompt the purchase
    local success, errorMessage = pcall(function()
        MarketplaceService:PromptProductPurchase(player, devProductId)
    end)
    
    if not success then
        warn("Failed to prompt purchase: " .. tostring(errorMessage))
        return false
    end
    
    print("DEBUG: Purchase prompt sent successfully for DevProductID: " .. devProductId)
    -- The actual processing will happen in the ProcessReceipt callback
    -- Return true to indicate the prompt was successful
    return true
end

-- Function to process crate and coin purchases
local function processCrateAndCoinReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Player is not in the game, save for later processing
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Check if this is a coin purchase
    if coinDevProducts[receiptInfo.ProductId] then
        local coinAmount = coinDevProducts[receiptInfo.ProductId]
        
        print("DEBUG: Processing coin purchase - giving " .. coinAmount .. " coins to " .. player.Name)
        
        -- Give coins to player
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local coins = leaderstats:FindFirstChild("Coins")
            if coins and coins:IsA("IntValue") then
                coins.Value = coins.Value + coinAmount
                print("DEBUG: Successfully gave " .. coinAmount .. " coins to " .. player.Name .. ". New balance: " .. coins.Value)
                
                -- Notify player
                local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
                if notificationEvent then
                    local message = "Purchase successful! You received " .. coinAmount .. " coins!"
                    notificationEvent:FireClient(player, message, Color3.fromRGB(60, 200, 60))
                end
                
                return Enum.ProductPurchaseDecision.PurchaseGranted
            else
                warn("DEBUG: Could not find Coins value for " .. player.Name)
                return Enum.ProductPurchaseDecision.NotProcessedYet
            end
        else
            warn("DEBUG: Could not find leaderstats for " .. player.Name)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
    end
    
    -- Find which crate was purchased
    local purchasedCrate = nil
    for crateName, config in pairs(crateConfigs) do
        if config.devProductId == receiptInfo.ProductId then
            purchasedCrate = crateName
            break
        end
    end
    
    if not purchasedCrate then
        -- Not a coin purchase or crate purchase, let other handlers deal with it
        return nil
    end
    
    -- Select a random pet
    print("DEBUG: Attempting to select a random pet from " .. purchasedCrate .. " crate")
    local pet = selectRandomPet(purchasedCrate)
    if not pet then
        print("DEBUG: No pets available in " .. purchasedCrate .. " crate - refunding coins")
        -- Refund coins if no pets available
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local coins = leaderstats:FindFirstChild("Coins")
            if coins and coins:IsA("IntValue") then
                coins.Value = coins.Value + 5000 -- Refund coins for no pets available
            end
        end
        return Enum.ProductPurchaseDecision.PurchaseDenied
    end
    
    print("DEBUG: Selected pet: " .. pet.name)
    
    -- Give the pet to the player
    print("DEBUG: Attempting to give pet to player")
    local success, petId = givePetToPlayer(player, pet)
    
    -- Notify player of the reward
    if success then
        local rarity = pet.instance:GetAttribute("Rarity") or purchasedCrate
        print("Successfully gave pet to player - Rarity: " .. rarity)
        
        -- First send purchase confirmation
        notificationEvent:FireClient(player, "Purchase successful! Opening " .. purchasedCrate .. " Crate...", Color3.fromRGB(60, 200, 60))
        
        -- Wait a moment before showing the reward
        task.wait(1.5)
        
        -- Verify the event exists before firing
        if not crateOpeningEvent then
            warn("CrateOpeningEvent is nil! Recreating it...")
            crateOpeningEvent = Instance.new("RemoteEvent")
            crateOpeningEvent.Name = "CrateOpeningEvent"
            crateOpeningEvent.Parent = ReplicatedStorage
        end
        
        -- Then send the pet received notification
        local message = "You received: " .. pet.name .. " (" .. rarity .. ") from your " .. purchasedCrate .. " Crate!"
        print("Sending notification: " .. message)
        notificationEvent:FireClient(player, message, Color3.fromRGB(60, 200, 60))
        
        -- Fire event to show crate opening animation
        print("Firing crate opening animation event to " .. player.Name)
        local petData = {
            name = pet.name,
            rarity = rarity,
            id = petId
        }
        print("Pet data for animation: " .. HttpService:JSONEncode(petData))
        
        -- Fire with error handling
        local fireSuccess, fireError = pcall(function()
            crateOpeningEvent:FireClient(player, purchasedCrate, petData)
        end)
        
        if not fireSuccess then
            warn("Failed to fire crate opening event: " .. tostring(fireError))
        else
            print("Successfully fired crate opening event")
        end
        
        -- Update daily objectives for crate opening
        if _G.UpdateDailyObjective then
            _G.UpdateDailyObjective(player, "openCrate", 1)
            print("DEBUG: Updated daily objective for crate opening (Robux purchase) for " .. player.Name)
        else
            warn("DEBUG: _G.UpdateDailyObjective not found for Robux purchase!")
        end
        
        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        print("DEBUG: Failed to give pet to player - refunding coins")
        -- Refund coins if failed to give pet
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local coins = leaderstats:FindFirstChild("Coins")
            if coins and coins:IsA("IntValue") then
                coins.Value = coins.Value + 5000 -- Refund coins for failed to give pet
            end
        end
        return Enum.ProductPurchaseDecision.PurchaseDenied
    end
end

-- Set up ProcessReceipt hook to work with other handlers
local function setupCrateProcessReceiptHook()
    -- ProcessReceipt disabled - now handled by PurchaseRouter
    print("DEBUG: [CratePurchaseHandler] ProcessReceipt disabled - using centralized PurchaseRouter")
    return
end

-- Set up the hook
setupCrateProcessReceiptHook()

-- Create or get coin purchase handler for VIP crate
local coinPurchaseEvent = ReplicatedStorage:FindFirstChild("CoinPurchaseCrateEvent")
if not coinPurchaseEvent then
    coinPurchaseEvent = Instance.new("RemoteFunction")
    coinPurchaseEvent.Name = "CoinPurchaseCrateEvent"
    coinPurchaseEvent.Parent = ReplicatedStorage
end

-- Handle coin purchases (for VIP crate which has no dev product)
coinPurchaseEvent.OnServerInvoke = function(player, crateName)
    print("Coin purchase request from " .. player.Name .. " for " .. crateName .. " crate")
    
    -- Check VIP access for VIP crate
    if crateName == "VIP" then
        if not hasVIPGamepass(player) then
            print("DEBUG: " .. player.Name .. " tried to purchase VIP crate without VIP gamepass")
            return false, "VIP gamepass required to purchase VIP crates"
        end
    end
    
    -- Define coin prices for each crate
    local coinPrices = {
        ["Common"] = 500,
        ["Rare"] = 1500,
        ["Legendary"] = 5000,
        ["VIP"] = 10000
    }
    
    -- Check if crate exists
    local crateConfig = crateConfigs[crateName]
    if not crateConfig then
        print("DEBUG: Invalid crate type: " .. crateName)
        return false, "Invalid crate type"
    end
    
    -- Check if player has enough coins
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        print("DEBUG: No leaderstats found for " .. player.Name)
        return false, "No leaderstats found"
    end
    
    local coins = leaderstats:FindFirstChild("Coins")
    if not coins or not coins:IsA("IntValue") then
        print("DEBUG: No coins value found for " .. player.Name)
        return false, "No coins value found"
    end
    
    print("DEBUG: " .. player.Name .. " has " .. coins.Value .. " coins")
    
    local price = coinPrices[crateName]
    if coins.Value < price then
        print("DEBUG: Not enough coins - " .. player.Name .. " has " .. coins.Value .. " coins, needs " .. price)
        return false, "Not enough coins"
    end
    
    -- Deduct coins
    print("DEBUG: Deducting " .. price .. " coins from " .. player.Name)
    coins.Value = coins.Value - price
    
    -- Select a random pet
    print("DEBUG: Attempting to select a random pet from " .. crateName .. " crate")
    local pet = selectRandomPet(crateName)
    if not pet then
        print("DEBUG: No pets available in " .. crateName .. " crate - refunding coins")
        -- Refund coins if no pets available
        coins.Value = coins.Value + price
        return false, "No pets available"
    end
    
    print("DEBUG: Selected pet: " .. pet.name)
    
    -- Give the pet to the player
    print("DEBUG: Attempting to give pet to player")
    local success, petId = givePetToPlayer(player, pet)
    
    -- Notify player of the reward
    if success then
        local rarity = pet.instance:GetAttribute("Rarity") or crateName
        print("Successfully gave pet to player - Rarity: " .. rarity)
        
        -- First send purchase confirmation
        notificationEvent:FireClient(player, "Purchase successful! Opening " .. crateName .. " Crate...", Color3.fromRGB(60, 200, 60))
        
        -- Wait a moment before showing the reward
        task.wait(1.5)
        
        -- Verify the event exists before firing
        if not crateOpeningEvent then
            warn("CrateOpeningEvent is nil! Recreating it...")
            crateOpeningEvent = Instance.new("RemoteEvent")
            crateOpeningEvent.Name = "CrateOpeningEvent"
            crateOpeningEvent.Parent = ReplicatedStorage
        end
        
        -- Then send the pet received notification
        local message = "You received: " .. pet.name .. " (" .. rarity .. ") from your " .. crateName .. " Crate!"
        print("Sending notification: " .. message)
        notificationEvent:FireClient(player, message, Color3.fromRGB(60, 200, 60))
        
        -- Fire event to show crate opening animation
        print("Firing crate opening animation event to " .. player.Name)
        local petData = {
            name = pet.name,
            rarity = rarity,
            id = petId
        }
        print("Pet data for animation: " .. HttpService:JSONEncode(petData))
        
        -- Fire with error handling
        local fireSuccess, fireError = pcall(function()
            crateOpeningEvent:FireClient(player, crateName, petData)
        end)
        
        if not fireSuccess then
            warn("Failed to fire crate opening event: " .. tostring(fireError))
        else
            print("Successfully fired crate opening event")
        end
        
        -- Update daily objectives for crate opening
        if _G.UpdateDailyObjective then
            _G.UpdateDailyObjective(player, "openCrate", 1)
            print("DEBUG: Updated daily objective for crate opening for " .. player.Name)
        else
            warn("DEBUG: _G.UpdateDailyObjective not found!")
        end
        
        return true, "Success"
    else
        print("DEBUG: Failed to give pet to player - refunding coins")
        -- Refund coins if failed to give pet
        coins.Value = coins.Value + price
        return false, "Failed to give pet"
    end
end

-- Ensure RemoteEvent exists for all players
Players.PlayerAdded:Connect(function(player)
    print("Player joined: " .. player.Name)
    
    -- Ensure RemoteEvent exists for this player
    if not crateOpeningEvent then
        warn("CrateOpeningEvent missing on player join! Recreating...")
        crateOpeningEvent = Instance.new("RemoteEvent")
        crateOpeningEvent.Name = "CrateOpeningEvent"
        crateOpeningEvent.Parent = ReplicatedStorage
    end
end)

print("Crate Purchase Handler initialized") 

-- Expose functions globally for PurchaseRouter to use (proper setup after all functions defined)
print("DEBUG: [CratePurchaseHandler] Setting up global CrateHandler functions (final)")
_G.CrateHandler = {
    selectRandomPet = selectRandomPet,
    givePetToPlayer = givePetToPlayer,
    hasVIPGamepass = hasVIPGamepass,
    crateConfigs = crateConfigs,
    notificationEvent = notificationEvent,
    crateOpeningEvent = crateOpeningEvent
}
print("DEBUG: [CratePurchaseHandler] Global CrateHandler functions ready (final)") 