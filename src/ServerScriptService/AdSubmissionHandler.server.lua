-- AdSubmissionHandler (ServerScriptService)
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

-- Gamepass constants
local LONGER_LISTINGS_GAMEPASS_ID = 1233852859 -- "Longer Listings" gamepass

-- Get the try-on tracking event
local trackTryOnEvent = ReplicatedStorage:WaitForChild("TrackTryOnEvent")

-- Wait for ProfileStore to be ready
repeat
    wait(0.1)
until _G.ProfileStoreData and _G.ProfileStoreData.IsReady

-- Wait for PurchaseRouter to be ready
repeat
    wait(0.1)
until _G.PurchaseRouter

local ProfileStoreData = _G.ProfileStoreData
local PurchaseRouter = _G.PurchaseRouter

print("DEBUG: [AdSubmissionHandler] Connected to ProfileStore and PurchaseRouter")

-- Function to get the actual clothing template from an asset ID
local function getClothingTemplate(assetId, clothingType)
    local success, result = pcall(function()
        -- Load the asset using InsertService
        local asset = InsertService:LoadAsset(tonumber(assetId))
        
        if asset then
            -- Find the clothing object in the asset
            local clothing = asset:FindFirstChildOfClass(clothingType)
            if clothing then
                local template
                if clothingType == "Shirt" then
                    template = clothing.ShirtTemplate
                elseif clothingType == "Pants" then
                    template = clothing.PantsTemplate
                end
                
                -- Clean up the asset
                asset:Destroy()
                
                return template
            end
            
            -- Clean up if no clothing found
            asset:Destroy()
        end
        
        return nil
    end)
    
    if success and result then
        print("DEBUG: [AdSubmissionHandler] Successfully got template for " .. clothingType .. " ID " .. assetId .. ": " .. result)
        return result
    else
        print("DEBUG: [AdSubmissionHandler] Failed to get template for " .. clothingType .. " ID " .. assetId .. ", using fallback")
        return "http://www.roblox.com/asset/?id=" .. assetId
    end
end

-- Function to increment try-on count using ProfileStore
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

local devProductId = 1910484649
local pendingAds = {}  -- key: player.UserId, value: adData

local submitAdEvent = ReplicatedStorage:WaitForChild("SubmitAdEvent")
local purchaseSuccessEvent = ReplicatedStorage:FindFirstChild("PurchaseSuccessEvent")
if not purchaseSuccessEvent then
	purchaseSuccessEvent = Instance.new("RemoteEvent")
	purchaseSuccessEvent.Name = "PurchaseSuccessEvent"
	purchaseSuccessEvent.Parent = ReplicatedStorage
end
local purchaseFailedEvent = ReplicatedStorage:FindFirstChild("PurchaseFailedEvent")
if not purchaseFailedEvent then
	purchaseFailedEvent = Instance.new("RemoteEvent")
	purchaseFailedEvent.Name = "PurchaseFailedEvent"
	purchaseFailedEvent.Parent = ReplicatedStorage
end
local npcTemplate = game.ServerStorage:WaitForChild("NPC_Template")
local npcMoverTemplate = game.ServerStorage:WaitForChild("NPCMoverTemplate")  -- our custom mover script
local waypointsFolder = workspace:WaitForChild("Waypoints")
-- Use the clothingOrders node for saving listings (now using ProfileStore)

-- Constants for XP awards
local XP_FOR_SINGLE_AD = 10
local XP_FOR_BOTH_AD = 30

-- Keep track of spawned NPCs and their positions
local spawnedNPCs = {}

-- Function to get the next available spawn position
local function getNextSpawnPosition()
	local wp0 = waypointsFolder:FindFirstChild("Waypoint0")
	if not wp0 then
		return CFrame.new(0, 10, 0) -- Fallback position
	end
	
	local baseCFrame = wp0.CFrame
	local npcSpacing = 5 -- Space between NPCs in studs
	
	-- If there are no spawned NPCs yet, use the base position
	if #spawnedNPCs == 0 then
		return baseCFrame
	end
	
	-- Try different positions in a grid pattern
	local maxNPCsInRow = 4
	local rowSpacing = 5
	
	-- Calculate grid position
	local npcCount = #spawnedNPCs
	local row = math.floor(npcCount / maxNPCsInRow)
	local col = npcCount % maxNPCsInRow
	
	-- Calculate new position
	local xOffset = col * npcSpacing
	local zOffset = row * rowSpacing
	
	return baseCFrame * CFrame.new(xOffset, 0, zOffset)
end

-- Function to award XP to a player
local function awardXP(player, amount)
	print("DEBUG: [AdSubmissionHandler] awardXP called for", player.Name, "amount:", amount)
	
	-- Check if ProfileStore is ready
	if not ProfileStoreData.IsReady then
		warn("DEBUG: [AdSubmissionHandler] ProfileStore not ready, cannot award XP to", player.Name)
		return
	end
	
	-- Check if player has a valid profile
	local profile = ProfileStoreData.GetPlayerProfile(player)
	if not profile or not profile:IsActive() then
		warn("DEBUG: [AdSubmissionHandler] Player", player.Name, "has no active profile, cannot award XP")
		return
	end
	
	print("DEBUG: [AdSubmissionHandler] ProfileStore ready and player has active profile")
	
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		print("DEBUG: [AdSubmissionHandler] Found leaderstats for", player.Name)
		
		local xp = leaderstats:FindFirstChild("XP")
		if xp then
			local oldXP = xp.Value
			xp.Value = xp.Value + amount
			local newXP = xp.Value
			
			print("DEBUG: [AdSubmissionHandler] XP updated for", player.Name, "- Old:", oldXP, "New:", newXP, "Diff:", newXP - oldXP)
			
			-- Note: XP is automatically saved to ProfileStore by LeaderstatsSetupWithLevel.server.lua
			print("Awarded " .. amount .. " XP to " .. player.Name .. " (auto-saved via leaderstats sync)")
		else
			warn("DEBUG: [AdSubmissionHandler] No XP stat found in leaderstats for", player.Name)
		end
	else
		warn("DEBUG: [AdSubmissionHandler] No leaderstats found for", player.Name)
	end
end

-- Listen for ad submission from the client.
submitAdEvent.OnServerEvent:Connect(function(player, adData)
	-- Store the pending ad for this player.
	pendingAds[player.UserId] = adData
	
	-- Set purchase context for the router
	PurchaseRouter.setPurchaseContext(player, "NPC_GENERATOR", {
		adData = adData
	})
	print("DEBUG: [AdSubmissionHandler] Set purchase context for", player.Name)
	
	local purchaseSuccess = false
	
	local connection
	connection = MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
		if userId == player.UserId and productId == devProductId then
			connection:Disconnect()
			
			if not wasPurchased then
				-- The purchase was cancelled or failed
				pendingAds[player.UserId] = nil
				PurchaseRouter.clearPurchaseContext(player)
				purchaseFailedEvent:FireClient(player)
			end
			-- If purchased, PurchaseRouter will handle it
		end
	end)
	
	-- Prompt the purchase
	MarketplaceService:PromptProductPurchase(player, devProductId)
	
	-- Set a timeout to clean up if no response is received
	delay(60, function()
		if connection.Connected then
			connection:Disconnect()
			
			-- If still pending, assume cancelled
			if pendingAds[player.UserId] == adData then
				pendingAds[player.UserId] = nil
				PurchaseRouter.clearPurchaseContext(player)
				purchaseFailedEvent:FireClient(player)
			end
		end
	end)
end)

-- Function to temporarily "try on" the clothing for the player.
local function tryOnClothing(player, adData)
	local character = player.Character
	if not character then return end

	local originalShirt, originalPants
	local shirt = character:FindFirstChildOfClass("Shirt")
	if shirt then
		originalShirt = shirt.ShirtTemplate
		-- Only destroy the shirt if we're trying on a new one
		if adData.shirt then
			shirt:Destroy()
			shirt = nil
		end
	end
	local pants = character:FindFirstChildOfClass("Pants")
	if pants then
		originalPants = pants.PantsTemplate
		-- Only destroy the pants if we're trying on new ones
		if adData.pants then
			pants:Destroy()
			pants = nil
		end
	end

	if adData.shirt then
		local shirtTemplate = getClothingTemplate(adData.shirt, "Shirt")
		local newShirt = shirt or Instance.new("Shirt", character)
		newShirt.ShirtTemplate = shirtTemplate
		
		-- Track the shirt try-on
		print("Player " .. player.Name .. " tried on shirt #" .. adData.shirt .. " via AdSubmissionHandler")
		incrementTryOnCount(tonumber(adData.shirt), "Shirt")
		
		-- Update daily objectives for clothing try-on
		local objectivesFolder = ReplicatedStorage:FindFirstChild("DailyObjectives")
		if objectivesFolder then
			local updateObjectiveEvent = objectivesFolder:FindFirstChild("UpdateObjectiveEvent")
			if updateObjectiveEvent then
				-- Fire the event directly since we're on the server
				updateObjectiveEvent:Fire(player, "tryOnClothes", 1)
			end
		end
	end
	if adData.pants then
		local pantsTemplate = getClothingTemplate(adData.pants, "Pants")
		local newPants = pants or Instance.new("Pants", character)
		newPants.PantsTemplate = pantsTemplate
		
		-- Track the pants try-on
		print("Player " .. player.Name .. " tried on pants #" .. adData.pants .. " via AdSubmissionHandler")
		incrementTryOnCount(tonumber(adData.pants), "Pants")
		
		-- Update daily objectives for clothing try-on
		local objectivesFolder = ReplicatedStorage:FindFirstChild("DailyObjectives")
		if objectivesFolder then
			local updateObjectiveEvent = objectivesFolder:FindFirstChild("UpdateObjectiveEvent")
			if updateObjectiveEvent then
				-- Fire the event directly since we're on the server
				updateObjectiveEvent:Fire(player, "tryOnClothes", 1)
			end
		end
	end

	-- Clothing now stays on the player until manually changed
	-- No automatic revert after 10 seconds
end

-- (Optional) Function to spawn an NPC dressed with the submitted ad data.
local function spawnNPC(adData)
	local npc = npcTemplate:Clone()
	npc.Parent = workspace
	
	-- Set the NPC's position with proper spacing
	local spawnPosition = getNextSpawnPosition()
	local primaryPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if primaryPart then
		npc:SetPrimaryPartCFrame(spawnPosition)
		
		-- Add the NPC to our tracking list for future spawn positioning
		table.insert(spawnedNPCs, {
			instance = npc,
			position = spawnPosition.Position
		})
		
		-- Remove from tracking list if destroyed
		npc.AncestryChanged:Connect(function(_, newParent)
			if not newParent then
				for i, tracked in ipairs(spawnedNPCs) do
					if tracked.instance == npc then
						table.remove(spawnedNPCs, i)
						break
					end
				end
			end
		end)
	end

	-- First, remove any existing clothing if not submitted
	local existingShirt = npc:FindFirstChildOfClass("Shirt")
	local existingPants = npc:FindFirstChildOfClass("Pants")
	
	-- Only remove existing shirt if no shirt was submitted
	if existingShirt and not adData.shirt then
		existingShirt:Destroy()
	end
	
	-- Only remove existing pants if no pants was submitted
	if existingPants and not adData.pants then
		existingPants:Destroy()
	end

	-- Update or add clothing to the NPC using real templates.
	if adData.shirt then
		local shirtTemplate = getClothingTemplate(adData.shirt, "Shirt")
		local shirt = npc:FindFirstChildOfClass("Shirt")
		if shirt then
			shirt.ShirtTemplate = shirtTemplate
		else
			shirt = Instance.new("Shirt")
			shirt.Name = "Shirt"
			shirt.ShirtTemplate = shirtTemplate
			shirt.Parent = npc
		end
		print("DEBUG: [AdSubmissionHandler] Applied shirt template: " .. shirtTemplate)
	end
	if adData.pants then
		local pantsTemplate = getClothingTemplate(adData.pants, "Pants")
		local pants = npc:FindFirstChildOfClass("Pants")
		if pants then
			pants.PantsTemplate = pantsTemplate
		else
			pants = Instance.new("Pants")
			pants.Name = "Pants"
			pants.PantsTemplate = pantsTemplate
			pants.Parent = npc
		end
		print("DEBUG: [AdSubmissionHandler] Applied pants template: " .. pantsTemplate)
	end
	
	-- Apply the skin tone if provided
	if adData.skinTone then
		-- Find or create the Body Colors instance
		local bodyColors = npc:FindFirstChild("Body Colors")
		if not bodyColors then
			bodyColors = Instance.new("BodyColors")
			bodyColors.Parent = npc
		end
		
		-- Apply the color to all body parts
		local brickColor = BrickColor.new(adData.skinTone)
		bodyColors.HeadColor = brickColor
		bodyColors.TorsoColor = brickColor
		bodyColors.LeftArmColor = brickColor
		bodyColors.RightArmColor = brickColor
		bodyColors.LeftLegColor = brickColor
		bodyColors.RightLegColor = brickColor
	end

	-- Clone and insert the NPC mover script.
	local npcMover = npcMoverTemplate:Clone()
	npcMover.Parent = npc
	npcMover.Disabled = false

	if primaryPart then
		-- Add a ProximityPrompt for trying on the clothing.
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Try On"
		prompt.ObjectText = "Clothing"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.Parent = primaryPart

		prompt.Triggered:Connect(function(triggeringPlayer)
			tryOnClothing(triggeringPlayer, adData)
		end)
	end
	
	return npc
end

-- Handler function for NPC system purchases
local function handleNPCPurchase(player, contextData, receiptInfo)
    print("DEBUG: [AdSubmissionHandler] Processing NPC purchase for", player.Name)
    
    local adData = contextData.adData
    if not adData then
        warn("DEBUG: [AdSubmissionHandler] No ad data in context")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- Process the NPC listing submission
    local success = processAdSubmission(player, adData)
    
    if success then
        print("DEBUG: [AdSubmissionHandler] NPC purchase processed successfully")
        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        warn("DEBUG: [AdSubmissionHandler] Failed to process NPC purchase")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

-- Function to process the actual ad submission
function processAdSubmission(player, adData)
    if not player or not adData then
        return false
    end
    
    -- Clean up pending ads for this player
    pendingAds[player.UserId] = nil

    -- Convert client keys to standardized keys and remove old ones.
    if adData.shirt then
        adData.shirtID = tostring(adData.shirt)
    elseif not adData.shirtID then
        adData.shirtID = ""
    end
    if adData.pants then
        adData.pantsID = tostring(adData.pants)
    elseif not adData.pantsID then
        adData.pantsID = ""
    end
    
    -- Store skin tone data if provided
    if adData.skinTone then
        adData.skinToneData = {
            R = adData.skinTone.R,
            G = adData.skinTone.G,
            B = adData.skinTone.B
        }
    end
    
    -- Store the custom name if provided
    if adData.customName then
        adData.customName = tostring(adData.customName)
    end
    
    -- Store creation date (or set if not provided)
    if not adData.creationDate then
        adData.creationDate = os.time()
    end
    
    adData.shirt = nil
    adData.pants = nil
    adData.skinTone = nil  -- Remove the direct Color3 object as it can't be encoded to JSON

    -- Check if player has "Longer Listings" gamepass
    local hasLongerListings = false
    local success, result = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, LONGER_LISTINGS_GAMEPASS_ID)
    end)
    
    if success then
        hasLongerListings = result
    else
        warn("Failed to check Longer Listings gamepass for player " .. player.Name .. ": " .. tostring(result))
    end
    
    -- Set listing duration based on gamepass ownership
    local listingDuration = hasLongerListings and 604800 or 259200 -- 1 week (604800) or 3 days (259200)
    local newTimestamp = os.time() + listingDuration
    adData.timestamp = newTimestamp
    adData.userId = player.UserId

    print("New listing timestamp for " .. player.Name .. " set to: " .. newTimestamp .. " (os.time() = " .. os.time() .. ")")

    -- Save to ProfileStore instead of Firebase
    local adId = HttpService:GenerateGUID(false) -- Generate unique ID for the ad
    local success = ProfileStoreData.AddAd(adId, adData)
    
    if success then
        print("Successfully saved listing to ProfileStore - ShirtID: " .. (adData.shirtID or "none") .. ", PantsID: " .. (adData.pantsID or "none"))
    else
        warn("Failed to save listing to ProfileStore")
        return false
    end
    
    print("NPCs will be spawned by the NPCSpawnerLoop in order")
    
    -- Award XP for the ad submission
    local hasShirt = adData.shirtID ~= ""
    local hasPants = adData.pantsID ~= ""
    
    if hasShirt and hasPants then
        awardXP(player, XP_FOR_BOTH_AD)
    elseif hasShirt or hasPants then
        awardXP(player, XP_FOR_SINGLE_AD)
    end
    
    -- Notify the client that the purchase was successful
    print("DEBUG: Sending purchase success event to " .. player.Name)
    purchaseSuccessEvent:FireClient(player)
    print("DEBUG: Purchase success event sent to " .. player.Name)
    
    -- Update daily objectives for clothing listing
    print("DEBUG: [AdSubmissionHandler] Attempting to update daily objectives...")
    local objectivesFolder = ReplicatedStorage:FindFirstChild("DailyObjectives")
    print("DEBUG: [AdSubmissionHandler] DailyObjectives folder found:", objectivesFolder ~= nil)
    
    if objectivesFolder then
        local updateObjectiveEvent = objectivesFolder:FindFirstChild("UpdateObjectiveEvent")
        print("DEBUG: [AdSubmissionHandler] UpdateObjectiveEvent found:", updateObjectiveEvent ~= nil)
        print("DEBUG: [AdSubmissionHandler] UpdateObjectiveEvent type:", typeof(updateObjectiveEvent))
        
        if updateObjectiveEvent and updateObjectiveEvent:IsA("RemoteEvent") then
            -- Since we're on the server, we can't use :Fire() on a RemoteEvent
            -- Instead, we'll directly call the global function which is more reliable
            print("DEBUG: [AdSubmissionHandler] Using direct global function call instead of RemoteEvent")
            if _G.UpdateDailyObjective then
                local success, err = pcall(function()
                    _G.UpdateDailyObjective(player, "listClothing", 1)
                end)
                print("DEBUG: [AdSubmissionHandler] Direct global function success:", success)
                if not success then
                    warn("DEBUG: [AdSubmissionHandler] Direct global function error:", err)
                end
            else
                warn("DEBUG: [AdSubmissionHandler] Global UpdateDailyObjective function not available")
            end
        else
            warn("DEBUG: [AdSubmissionHandler] UpdateObjectiveEvent not found or wrong type")
        end
    else
        warn("DEBUG: [AdSubmissionHandler] DailyObjectives folder not found in ReplicatedStorage")
    end
    
    return true
end

-- Register with the centralized purchase router
PurchaseRouter.registerSystemHandler("NPC_GENERATOR", handleNPCPurchase)
print("DEBUG: [AdSubmissionHandler] Registered NPC_GENERATOR handler with PurchaseRouter")

print("DEBUG: [AdSubmissionHandler] AdSubmissionHandler initialized with ProfileStore and centralized routing")
