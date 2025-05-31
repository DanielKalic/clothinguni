-- PodiumNPCs (ServerScriptService)
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local PhysicsService = game:GetService("PhysicsService")
local InsertService = game:GetService("InsertService")
local npcTemplate = game.ServerStorage:WaitForChild("NPC_Template")

-- Wait for ProfileStore data to be ready
repeat
	wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

-- Add a longer delay to ensure ProfileStore is fully loaded with any existing data
wait(3)
print("DEBUG: [PodiumNPCs] Starting podium setup after ProfileStore delay")

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
		print("DEBUG: [PodiumNPCs] Successfully got template for " .. clothingType .. " ID " .. assetId .. ": " .. result)
		return result
	else
		print("DEBUG: [PodiumNPCs] Failed to get template for " .. clothingType .. " ID " .. assetId .. ", using fallback")
		return "http://www.roblox.com/asset/?id=" .. assetId
	end
end

-- Helper function: Get top try-on data from ProfileStore try-on counts (more realistic than sales)
local function getTopTryOns(clothingType)
	local tryOnData = ProfileStoreData.GetAllTryOns()
	local tryOnList = {}
	
	if tryOnData and tryOnData[clothingType:lower() .. "s"] then
		for assetId, count in pairs(tryOnData[clothingType:lower() .. "s"]) do
			table.insert(tryOnList, { assetId = assetId, count = count })
		end
		table.sort(tryOnList, function(a, b)
			return a.count > b.count
		end)
	end
	
	return tryOnList
end

-- Helper function: Get top sales data from ProfileStore sales counts
local function getTopSales(clothingType)
	local salesData = ProfileStoreData.GetAllSales()
	local salesList = {}
	
	if salesData and salesData[clothingType] then
		for assetId, count in pairs(salesData[clothingType]) do
			table.insert(salesList, { assetId = assetId, count = count })
		end
		table.sort(salesList, function(a, b)
			return a.count > b.count
		end)
	end
	
	return salesList
end

-- Helper function: Get clothing from ProfileStore ads as fallback
local function getFallbackClothing()
	local shirts = {}
	local pants = {}
	
	local ads = ProfileStoreData.GetAds()
	local currentTime = os.time()
	
	if ads then
		for key, clothing in pairs(ads) do
			-- Check if listing is not expired (timestamp > current time)
			local timestamp = tonumber(clothing.timestamp) or 0
			local isExpired = timestamp <= currentTime
			
			-- Only use non-expired listings
			if not isExpired then
				if clothing.shirtID and clothing.shirtID ~= "" then
					table.insert(shirts, {assetId = clothing.shirtID})
				end
				if clothing.pantsID and clothing.pantsID ~= "" then
					table.insert(pants, {assetId = clothing.pantsID})
				end
			end
		end
	end
	
	-- If we have no valid non-expired shirts or pants, log a warning
	if #shirts == 0 then
		warn("No non-expired shirts found in listings")
	end
	
	if #pants == 0 then
		warn("No non-expired pants found in listings")
	end
	
	return shirts, pants
end

----------------------------------------------------------------
-- Retrieve the podium parts from Workspace.
local Podiums = workspace:WaitForChild("Podiums", 10)
if not Podiums then
    warn("DEBUG: [PodiumNPCs] Podiums folder not found in workspace!")
    return
end

print("DEBUG: [PodiumNPCs] Found Podiums folder, checking for podium models...")

-- Function to safely get podium part from model
local function getPodiumPart(podiumModel, placeName)
    if not podiumModel then
        warn("DEBUG: [PodiumNPCs] " .. placeName .. " model not found")
        return nil
    end
    
    local podiumPart = podiumModel:FindFirstChild("Podium")
    if not podiumPart then
        warn("DEBUG: [PodiumNPCs] Podium part not found in " .. placeName .. " model")
        -- Try to find any Part as fallback
        local part = podiumModel:FindFirstChild("Part")
        if part then
            warn("DEBUG: [PodiumNPCs] Using 'Part' as fallback for " .. placeName)
            return part
        end
        return nil
    end
    
    print("DEBUG: [PodiumNPCs] Found " .. placeName .. " podium part")
    return podiumPart
end

-- Get the podium models first
local firstPlaceModel = Podiums:FindFirstChild("FirstPlace")
local secondPlaceModel = Podiums:FindFirstChild("SecondPlace") 
local thirdPlaceModel = Podiums:FindFirstChild("ThirdPlace")

-- Then get the podium parts from each model
local firstPodium = getPodiumPart(firstPlaceModel, "FirstPlace")
local secondPodium = getPodiumPart(secondPlaceModel, "SecondPlace")
local thirdPodium = getPodiumPart(thirdPlaceModel, "ThirdPlace")

-- Debug: Check if podiums were found
print("DEBUG: [PodiumNPCs] Podium part availability:")
print("  FirstPlace model found:", firstPlaceModel ~= nil)
print("  FirstPlace/Podium part found:", firstPodium ~= nil)
print("  SecondPlace model found:", secondPlaceModel ~= nil) 
print("  SecondPlace/Podium part found:", secondPodium ~= nil)
print("  ThirdPlace model found:", thirdPlaceModel ~= nil)
print("  ThirdPlace/Podium part found:", thirdPodium ~= nil)

----------------------------------------------------------------
-- Helper function: Compute a world-space bounding box for a list of parts.
local function getBoundingBox(parts)
	local minVec = Vector3.new(math.huge, math.huge, math.huge)
	local maxVec = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(parts) do
		if part and part:IsA("BasePart") then
			local cf = part.CFrame
			local size = part.Size
			local corners = {
				cf * Vector3.new( size.X/2,  size.Y/2,  size.Z/2),
				cf * Vector3.new( size.X/2,  size.Y/2, -size.Z/2),
				cf * Vector3.new( size.X/2, -size.Y/2,  size.Z/2),
				cf * Vector3.new( size.X/2, -size.Y/2, -size.Z/2),
				cf * Vector3.new(-size.X/2,  size.Y/2,  size.Z/2),
				cf * Vector3.new(-size.X/2,  size.Y/2, -size.Z/2),
				cf * Vector3.new(-size.X/2, -size.Y/2,  size.Z/2),
				cf * Vector3.new(-size.X/2, -size.Y/2, -size.Z/2)
			}
			for _, corner in ipairs(corners) do
				minVec = Vector3.new(math.min(minVec.X, corner.X),
					math.min(minVec.Y, corner.Y),
					math.min(minVec.Z, corner.Z))
				maxVec = Vector3.new(math.max(maxVec.X, corner.X),
					math.max(maxVec.Y, corner.Y),
					math.max(maxVec.Z, corner.Z))
			end
		end
	end
	local center = (minVec + maxVec) / 2
	local size = maxVec - minVec
	return CFrame.new(center), size
end

-- Store current podium NPCs for cleanup
local currentPodiumNPCs = {}

-- Function to clean up existing podium NPCs
local function cleanupPodiumNPCs()
	for _, npc in pairs(currentPodiumNPCs) do
		if npc and npc.Parent then
			npc:Destroy()
		end
	end
	currentPodiumNPCs = {}
	print("DEBUG: [PodiumNPCs] Cleaned up old podium NPCs")
end

-- Function to spawn a podium NPC with try-on and purchase functions.
local function spawnPodiumNPC(podiumPart, shirtAssetId, pantsAssetId, podiumName)
	if not podiumPart then return end
	
	print("DEBUG: [PodiumNPCs] Creating podium NPC for " .. podiumName .. " with shirt:", shirtAssetId or "none", "pants:", pantsAssetId or "none")
	
	local npc = npcTemplate:Clone()
	-- Set name to empty so it doesn't show any name
	npc.Name = ""
	npc.Parent = workspace
	npc:SetPrimaryPartCFrame(podiumPart.CFrame)

	-- Store reference for cleanup
	table.insert(currentPodiumNPCs, npc)

	-- First, remove any existing clothing if not submitted
	local existingShirt = npc:FindFirstChildOfClass("Shirt")
	local existingPants = npc:FindFirstChildOfClass("Pants")
	
	-- Only remove existing shirt if no shirt was submitted
	if existingShirt and not shirtAssetId then
		existingShirt:Destroy()
		print("DEBUG: [PodiumNPCs] Removed existing shirt (no new shirt provided)")
	end
	
	-- Only remove existing pants if no pants was submitted
	if existingPants and not pantsAssetId then
		existingPants:Destroy()
		print("DEBUG: [PodiumNPCs] Removed existing pants (no new pants provided)")
	end

	-- Apply clothing based on provided asset IDs using real templates.
	if shirtAssetId then
		local shirtTemplate = getClothingTemplate(shirtAssetId, "Shirt")
		local shirt = npc:FindFirstChildOfClass("Shirt") or Instance.new("Shirt")
		shirt.Name = "Shirt"
		shirt.ShirtTemplate = shirtTemplate
		shirt.Parent = npc
		print("DEBUG: [PodiumNPCs] Applied shirt template: " .. shirtTemplate)
	else
		print("DEBUG: [PodiumNPCs] No shirt asset ID provided")
	end
	if pantsAssetId then
		local pantsTemplate = getClothingTemplate(pantsAssetId, "Pants")
		local pants = npc:FindFirstChildOfClass("Pants") or Instance.new("Pants")
		pants.Name = "Pants"
		pants.PantsTemplate = pantsTemplate
		pants.Parent = npc
		print("DEBUG: [PodiumNPCs] Applied pants template: " .. pantsTemplate)
	else
		print("DEBUG: [PodiumNPCs] No pants asset ID provided")
	end

	-- Set all NPC parts to the "NPC" collision group.
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Using the new API: set the property directly.
			part.CollisionGroup = "NPC"
		end
	end

	-- Add a "try on" ProximityPrompt (attached to the Head if available).
	local headPart = npc:FindFirstChild("Head")
	local promptParent = headPart or (npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart"))
	if promptParent then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Try On"
		prompt.ObjectText = "Clothing"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = true
		prompt.Parent = promptParent
		prompt.UIOffset = Vector2.new(0, 0)
		prompt.Triggered:Connect(function(triggeringPlayer)
			local character = triggeringPlayer.Character
			if not character then return end
			local originalShirt, originalPants
			local currentShirt = character:FindFirstChildOfClass("Shirt")
			if currentShirt then
				originalShirt = currentShirt.ShirtTemplate
				-- Only remove the current shirt if we're trying on a new shirt
				if shirtAssetId then
					currentShirt:Destroy()
				end
			end
			local currentPants = character:FindFirstChildOfClass("Pants")
			if currentPants then
				originalPants = currentPants.PantsTemplate
				-- Only remove the current pants if we're trying on new pants
				if pantsAssetId then
					currentPants:Destroy()
				end
			end
			if shirtAssetId then
				local shirtTemplate = getClothingTemplate(shirtAssetId, "Shirt")
				local newShirt = Instance.new("Shirt")
				newShirt.ShirtTemplate = shirtTemplate
				newShirt.Parent = character
			end
			if pantsAssetId then
				local pantsTemplate = getClothingTemplate(pantsAssetId, "Pants")
				local newPants = Instance.new("Pants")
				newPants.PantsTemplate = pantsTemplate
				newPants.Parent = character
			end
			
			-- Update daily objectives for clothing try-on (once per action, not per clothing piece)
			if (shirtAssetId or pantsAssetId) and _G.UpdateDailyObjective then
				local success, err = pcall(function()
					_G.UpdateDailyObjective(triggeringPlayer, "tryOnClothes", 1)
				end)
				if not success then
					warn("DEBUG: [PodiumNPCs] Daily objective update failed:", err)
				end
			end
			
			-- Clothing now stays on the player until manually changed
			-- No automatic revert after 10 seconds
		end)
	end

	-- Create purchase zones covering the upper and lower body.
	local primaryPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if primaryPart then
		local upperParts = {}
		local lowerParts = {}
		-- Determine if R6 or R15 by checking for "Torso" vs. "UpperTorso".
		if npc:FindFirstChild("Torso") then
			-- R6 rig
			if npc:FindFirstChild("Head") then table.insert(upperParts, npc.Head) end
			if npc:FindFirstChild("Torso") then table.insert(upperParts, npc.Torso) end
			if npc:FindFirstChild("Left Arm") then table.insert(upperParts, npc["Left Arm"]) end
			if npc:FindFirstChild("Right Arm") then table.insert(upperParts, npc["Right Arm"]) end
			if npc:FindFirstChild("Left Leg") then table.insert(lowerParts, npc["Left Leg"]) end
			if npc:FindFirstChild("Right Leg") then table.insert(lowerParts, npc["Right Leg"]) end
		elseif npc:FindFirstChild("UpperTorso") then
			-- R15 rig
			if npc:FindFirstChild("Head") then table.insert(upperParts, npc.Head) end
			if npc:FindFirstChild("UpperTorso") then table.insert(upperParts, npc.UpperTorso) end
			if npc:FindFirstChild("LeftUpperArm") then table.insert(upperParts, npc.LeftUpperArm) end
			if npc:FindFirstChild("RightUpperArm") then table.insert(upperParts, npc.RightUpperArm) end
			if npc:FindFirstChild("LeftLowerArm") then table.insert(upperParts, npc.LeftLowerArm) end
			if npc:FindFirstChild("RightLowerArm") then table.insert(upperParts, npc.RightLowerArm) end
			if npc:FindFirstChild("LowerTorso") then table.insert(lowerParts, npc.LowerTorso) end
			if npc:FindFirstChild("LeftUpperLeg") then table.insert(lowerParts, npc.LeftUpperLeg) end
			if npc:FindFirstChild("RightUpperLeg") then table.insert(lowerParts, npc.RightUpperLeg) end
			if npc:FindFirstChild("LeftLowerLeg") then table.insert(lowerParts, npc.LeftLowerLeg) end
			if npc:FindFirstChild("RightLowerLeg") then table.insert(lowerParts, npc.RightLowerLeg) end
		end

		local upperCFrame, upperSize = getBoundingBox(upperParts)
		local lowerCFrame, lowerSize = getBoundingBox(lowerParts)

		-- Create an invisible upper purchase zone (covers upper body).
		if shirtAssetId and upperSize.Magnitude > 0 then
			local upperZone = Instance.new("Part")
			upperZone.Name = "UpperPurchaseZone"
			upperZone.Size = upperSize + Vector3.new(1, 1, 1)
			upperZone.CFrame = upperCFrame
			upperZone.Transparency = 1
			upperZone.CanCollide = false
			upperZone.Parent = npc

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = upperZone
			weld.Part1 = primaryPart
			weld.Parent = upperZone

			local upperCD = Instance.new("ClickDetector")
			upperCD.MaxActivationDistance = 10
			upperCD.Parent = upperZone
			upperCD.MouseClick:Connect(function(player)
				MarketplaceService:PromptPurchase(player, tonumber(shirtAssetId))
			end)
		end

		-- Create an invisible lower purchase zone (covers lower body).
		if pantsAssetId and lowerSize.Magnitude > 0 then
			local lowerZone = Instance.new("Part")
			lowerZone.Name = "LowerPurchaseZone"
			lowerZone.Size = lowerSize + Vector3.new(1, 1, 1)
			lowerZone.CFrame = lowerCFrame
			lowerZone.Transparency = 1
			lowerZone.CanCollide = false
			lowerZone.Parent = npc

			local weld2 = Instance.new("WeldConstraint")
			weld2.Part0 = lowerZone
			weld2.Part1 = primaryPart
			weld2.Parent = lowerZone

			local lowerCD = Instance.new("ClickDetector")
			lowerCD.MaxActivationDistance = 10
			lowerCD.Parent = lowerZone
			lowerCD.MouseClick:Connect(function(player)
				MarketplaceService:PromptPurchase(player, tonumber(pantsAssetId))
			end)
		end
	end
end

-- Function to update podium NPCs with current data
local function updatePodiumNPCs()
	print("DEBUG: [PodiumNPCs] Updating podium NPCs with latest try-on data...")
	
	-- Clean up existing NPCs
	cleanupPodiumNPCs()
	
	-- Get fresh data
	local topShirts = getTopTryOns("Shirt")
	local topPants = getTopTryOns("Pants")

	print("DEBUG: [PodiumNPCs] Fresh try-on data - Shirts:", #topShirts, "Pants:", #topPants)

	-- If no try-on data, fall back to sales data
	if #topShirts == 0 then
		topShirts = getTopSales("Shirt")
		print("DEBUG: [PodiumNPCs] No try-on data for shirts, falling back to sales data - Count:", #topShirts)
	end

	if #topPants == 0 then
		topPants = getTopSales("Pants")
		print("DEBUG: [PodiumNPCs] No try-on data for pants, falling back to sales data - Count:", #topPants)
	end

	-- If still no data, get fallback data from clothing listings
	if #topShirts == 0 or #topPants == 0 then
		local fallbackShirts, fallbackPants = getFallbackClothing()
		
		print("DEBUG: [PodiumNPCs] Fallback data - Shirts:", #fallbackShirts, "Pants:", #fallbackPants)
		
		if #topShirts == 0 and #fallbackShirts > 0 then
			print("No shirt ranking data found, using fallback clothing data")
			topShirts = fallbackShirts
		end
		
		if #topPants == 0 and #fallbackPants > 0 then
			print("No pants ranking data found, using fallback clothing data")
			topPants = fallbackPants
		end
	end

	-- Add default clothing as ultimate fallback
	local defaultShirts = {
		{assetId = "122593977218180"}, -- Your existing shirt
		{assetId = "7526844438"},      -- Default gray shirt
		{assetId = "15695468293"}      -- Another default shirt
	}

	local defaultPants = {
		{assetId = "7526844691"},  -- Default gray pants
		{assetId = "15695471030"}, -- Another default pants
		{assetId = "15695469649"}  -- Yet another default pants
	}

	-- Use defaults if we still have no clothing
	if #topShirts == 0 then
		print("DEBUG: [PodiumNPCs] No shirts found anywhere, using default shirts")
		topShirts = defaultShirts
	end

	if #topPants == 0 then
		print("DEBUG: [PodiumNPCs] No pants found anywhere, using default pants")
		topPants = defaultPants
	end

	print("DEBUG: [PodiumNPCs] Final counts - Shirts:", #topShirts, "Pants:", #topPants)

	local top3Shirts = {}
	local top3Pants  = {}

	-- Ensure we have at least some items for all podiums by repeating items if needed
	for i = 1, 3 do
		-- For shirts: if we run out of unique items, reuse whatever we have
		if i <= #topShirts then
			top3Shirts[i] = topShirts[i].assetId
		elseif #topShirts > 0 then
			-- Reuse the first item if we don't have enough
			top3Shirts[i] = topShirts[1].assetId
		else
			top3Shirts[i] = nil
		end
		
		-- For pants: if we run out of unique items, reuse whatever we have
		if i <= #topPants then
			top3Pants[i] = topPants[i].assetId
		elseif #topPants > 0 then
			-- Reuse the first item if we don't have enough
			top3Pants[i] = topPants[1].assetId
		else
			top3Pants[i] = nil
		end
	end

	-- Make sure each podium has at least one item (shirt or pants)
	-- If a podium would have neither, give it the first available item
	for i = 1, 3 do
		if not top3Shirts[i] and not top3Pants[i] then
			if #topShirts > 0 then
				top3Shirts[i] = topShirts[1].assetId
			elseif #topPants > 0 then
				top3Pants[i] = topPants[1].assetId
			end
		end
	end

	-- Print what's being used for debugging
	for i = 1, 3 do
		print("Podium " .. i .. " - Shirt: " .. (top3Shirts[i] or "none") .. ", Pants: " .. (top3Pants[i] or "none"))
	end

	-- Debug: Print current rankings
	print("DEBUG: [PodiumNPCs] Current podium rankings:")
	if firstPodium then
		print("  🥇 1st Place (FirstPlace) | Shirt: " .. (top3Shirts[1] or "none") .. " | Pants: " .. (top3Pants[1] or "none"))
	end
	if secondPodium then
		print("  🥈 2nd Place (SecondPlace) | Shirt: " .. (top3Shirts[2] or "none") .. " | Pants: " .. (top3Pants[2] or "none"))
	end
	if thirdPodium then
		print("  🥉 3rd Place (ThirdPlace) | Shirt: " .. (top3Shirts[3] or "none") .. " | Pants: " .. (top3Pants[3] or "none"))
	end

	-- Spawn the podium NPCs with the current top combinations
	if firstPodium then
		spawnPodiumNPC(firstPodium, top3Shirts[1], top3Pants[1], "FirstPlace")
	else
		warn("Cannot spawn NPC on FirstPlace podium - podium not found")
	end

	if secondPodium then
		spawnPodiumNPC(secondPodium, top3Shirts[2], top3Pants[2], "SecondPlace")
	else
		warn("Cannot spawn NPC on SecondPlace podium - podium not found")
	end

	if thirdPodium then
		spawnPodiumNPC(thirdPodium, top3Shirts[3], top3Pants[3], "ThirdPlace")
	else
		warn("Cannot spawn NPC on ThirdPlace podium - podium not found")
	end

	print("DEBUG: [PodiumNPCs] Podium update completed at", os.date("%X"))
end

-- Initial podium setup
updatePodiumNPCs()

-- Set up real-time updates every 30 seconds
spawn(function()
	while true do
		wait(30) -- Update every 30 seconds
		updatePodiumNPCs()
	end
end)

print("DEBUG: [PodiumNPCs] Real-time podium update system initialized - updates every 30 seconds") 