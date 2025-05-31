-- NPCSpawnerLoop (ServerScriptService)
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")

-- Add timeouts and error handling for critical WaitForChild calls
local function waitForChildWithFallback(parent, childName, timeout)
    local child = parent:WaitForChild(childName, timeout)
    if not child then
        warn(string.format("DEBUG: [NPCSpawnerLoop] Failed to find %s in %s after %d seconds", childName, parent.Name, timeout))
        return nil
    end
    return child
end

local npcTemplate = waitForChildWithFallback(game.ServerStorage, "NPC_Template", 10)
if not npcTemplate then
    error("DEBUG: [NPCSpawnerLoop] Critical error: NPC_Template not found in ServerStorage")
    return
end

local waypointsFolder = waitForChildWithFallback(workspace, "Waypoints", 10)
if not waypointsFolder then
    error("DEBUG: [NPCSpawnerLoop] Critical error: Waypoints folder not found in workspace")
    return
end

-- Get the try-on tracking event with timeout
local trackTryOnEvent = waitForChildWithFallback(ReplicatedStorage, "TrackTryOnEvent", 10)
if not trackTryOnEvent then
    warn("DEBUG: [NPCSpawnerLoop] Warning: TrackTryOnEvent not found - try-on tracking may not work")
end

-- Create debug command event
local debugCommandEvent = Instance.new("RemoteEvent")
debugCommandEvent.Name = "NPCDebugCommand"
debugCommandEvent.Parent = ReplicatedStorage

-- Wait for ProfileStore data to be ready
repeat
    wait(0.1)
until _G.ProfileStoreData and _G.ProfileStoreData.IsReady

local ProfileStoreData = _G.ProfileStoreData

-- Table to track NPCs by their listing ID for cleanup
local spawnedNPCsByListing = {} -- {listingId = {npc1, npc2, ...}}

-- Listen for listing removal events to clean up NPCs
local removeListingEvent = ReplicatedStorage:WaitForChild("RemoveListingEvent")
removeListingEvent.OnServerEvent:Connect(function(player, listingKey)
    print("DEBUG: [NPCSpawnerLoop] Listing " .. listingKey .. " was deleted, cleaning up NPCs...")
    
    -- Clean up any NPCs associated with this listing
    if spawnedNPCsByListing[listingKey] then
        for _, npc in ipairs(spawnedNPCsByListing[listingKey]) do
            if npc and npc.Parent then
                print("DEBUG: [NPCSpawnerLoop] Destroying NPC for deleted listing " .. listingKey)
                npc:Destroy()
            end
        end
        spawnedNPCsByListing[listingKey] = nil
    end
end)

-- Function to add NPC to tracking
local function trackNPCForListing(npc, listingKey)
    if not spawnedNPCsByListing[listingKey] then
        spawnedNPCsByListing[listingKey] = {}
    end
    table.insert(spawnedNPCsByListing[listingKey], npc)
    
    -- Clean up tracking when NPC is destroyed
    npc.AncestryChanged:Connect(function(_, newParent)
        if not newParent and spawnedNPCsByListing[listingKey] then
            -- Remove this NPC from the tracking list
            for i, trackedNPC in ipairs(spawnedNPCsByListing[listingKey]) do
                if trackedNPC == npc then
                    table.remove(spawnedNPCsByListing[listingKey], i)
                    break
                end
            end
            -- Clean up empty tracking table
            if #spawnedNPCsByListing[listingKey] == 0 then
                spawnedNPCsByListing[listingKey] = nil
            end
        end
    end)
end

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
        print("DEBUG: [NPCSpawnerLoop] Successfully got template for " .. clothingType .. " ID " .. assetId .. ": " .. result)
        return result
    else
        print("DEBUG: [NPCSpawnerLoop] Failed to get template for " .. clothingType .. " ID " .. assetId .. ", using fallback")
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

local spawnInterval = 7  -- seconds between spawns

-- Helper function: Given an array of parts, compute the world-space bounding box.
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
				minVec = Vector3.new(math.min(minVec.X, corner.X), math.min(minVec.Y, corner.Y), math.min(minVec.Z, corner.Z))
				maxVec = Vector3.new(math.max(maxVec.X, corner.X), math.max(maxVec.Y, corner.Y), math.max(maxVec.Z, corner.Z))
			end
		end
	end
	local center = (minVec + maxVec) / 2
	local size = maxVec - minVec
	return CFrame.new(center), size
end

-- Custom function for moving the NPC using a BindableEvent.
local function actuallyMoveTo(npc, point)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local moveFinishedEvent = humanoid:FindFirstChild("MoveToActuallyFinished")
	if not moveFinishedEvent then
		moveFinishedEvent = Instance.new("BindableEvent")
		moveFinishedEvent.Name = "MoveToActuallyFinished"
		moveFinishedEvent.Parent = humanoid
	end

	local connection
	connection = humanoid.MoveToFinished:Connect(function(reached)
		connection:Disconnect()
		connection = nil
		if reached then
			moveFinishedEvent:Fire()
		else
			actuallyMoveTo(npc, point)
		end
	end)
	humanoid:MoveTo(point)
end

local function moveNPC(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local waypoints = {}
	for _, wp in ipairs(waypointsFolder:GetChildren()) do
		table.insert(waypoints, wp)
	end
	table.sort(waypoints, function(a, b)
		-- Extract numbers from waypoint names for proper numerical sorting
		local numA = tonumber(a.Name:match("%d+")) or 0
		local numB = tonumber(b.Name:match("%d+")) or 0
		return numA < numB
	end)

	for _, wp in ipairs(waypoints) do
		actuallyMoveTo(npc, wp.Position)
		humanoid:FindFirstChild("MoveToActuallyFinished").Event:Wait()
	end
	npc:Destroy()
end

-- Function to check if a player is an admin
local function isAdmin(player)
    return player:GetRankInGroup(YOUR_GROUP_ID) >= 255 -- Replace YOUR_GROUP_ID with your actual group ID
    -- For testing, you can temporarily return true for all players
    -- return true
end

-- Function to get current debug stats
local function getDebugStats()
    local stats = {
        activeNPCs = 0,
        totalListings = 0,
        validListings = 0,
        expiredListings = 0,
        currentTime = os.time()
    }
    
    -- Count active NPCs
    for _, npcs in pairs(spawnedNPCsByListing) do
        stats.activeNPCs = stats.activeNPCs + #npcs
    end
    
    -- Get listings data
    local success, ads = pcall(function()
        return _G.ProfileStoreData.GetAds()
    end)
    
    if success and ads then
        for key, ad in pairs(ads) do
            stats.totalListings = stats.totalListings + 1
            local timestamp = tonumber(ad.timestamp) or 0
            if timestamp > stats.currentTime then
                stats.validListings = stats.validListings + 1
            else
                stats.expiredListings = stats.expiredListings + 1
            end
        end
    end
    
    return stats
end

-- Handle debug commands
debugCommandEvent.OnServerEvent:Connect(function(player, command)
    if not isAdmin(player) then return end
    
    if command == "getStats" then
        local stats = getDebugStats()
        local message = string.format(
            "NPC System Stats:\n" ..
            "Active NPCs: %d\n" ..
            "Total Listings: %d\n" ..
            "Valid Listings: %d\n" ..
            "Expired Listings: %d\n" ..
            "Current Time: %d",
            stats.activeNPCs,
            stats.totalListings,
            stats.validListings,
            stats.expiredListings,
            stats.currentTime
        )
        debugCommandEvent:FireClient(player, "stats", message)
    elseif command == "forceCleanup" then
        -- Force cleanup of expired listings
        local stats = getDebugStats()
        local before = stats.activeNPCs
        
        -- Clean up expired NPCs
        for listingKey, npcs in pairs(spawnedNPCsByListing) do
            for _, npc in ipairs(npcs) do
                if npc and npc.Parent then
                    npc:Destroy()
                end
            end
            spawnedNPCsByListing[listingKey] = nil
        end
        
        local afterStats = getDebugStats()
        local message = string.format("Cleaned up %d NPCs", before - afterStats.activeNPCs)
        debugCommandEvent:FireClient(player, "cleanup", message)
    end
end)

while true do
	-- Small delay at start of each loop to prevent overwhelming system
	wait(0.5)
	
	-- Get ads data from ProfileStore instead of Firebase
	local success, ads = pcall(function()
		return _G.ProfileStoreData.GetAds()
	end)
	
	if not success then
		warn("DEBUG: [NPCSpawnerLoop] Failed to get ads data:", ads)
		wait(5) -- Wait longer before retrying on error
		continue
	end
	
	if not ads then
		warn("DEBUG: [NPCSpawnerLoop] Ads data is nil")
		wait(5)
		continue
	end
	
	if not next(ads) then
		warn("DEBUG: [NPCSpawnerLoop] Ads table is empty")
		wait(5)
		continue
	end

	local adsList = {}
	local currentTime = os.time()
	local expiredCount = 0
	local validCount = 0
	
	-- Only include non-expired listings (timestamp > current time)
	for key, ad in pairs(ads) do
		local timestamp = tonumber(ad.timestamp) or 0
		if timestamp > currentTime then
			ad.key = key -- Store the key for reference
			table.insert(adsList, ad)
			validCount = validCount + 1
		else
			expiredCount = expiredCount + 1
		end
	end
	
	-- Log detailed stats about listings
	print(string.format("DEBUG: [NPCSpawnerLoop] Listings stats - Total: %d, Valid: %d, Expired: %d, Current time: %d", 
		#adsList + expiredCount, validCount, expiredCount, currentTime))
	
	if #adsList == 0 then
		warn("DEBUG: [NPCSpawnerLoop] No valid non-expired listings found")
		wait(5)
		continue
	end
	
	-- Randomize the ads list.
	for i = #adsList, 2, -1 do
		local j = math.random(i)
		adsList[i], adsList[j] = adsList[j], adsList[i]
	end
	
	for _, adData in ipairs(adsList) do
		-- Use standardized keys: prefer "shirtID" (fallback to "shirt") and "pantsID" (fallback to "pants")
		local shirtValue = adData.shirtID or adData.shirt or ""
		local pantsValue = adData.pantsID or adData.pants or ""
		
		-- Log the listing being processed
		print(string.format("DEBUG: [NPCSpawnerLoop] Processing listing - Key: %s, Shirt: %s, Pants: %s, Timestamp: %s", 
			adData.key or "nil", shirtValue, pantsValue, tostring(adData.timestamp)))
		
		-- Only spawn an NPC if at least one asset value is provided.
		if shirtValue ~= "" or pantsValue ~= "" then
			local npc = npcTemplate:Clone()
			-- Rename the NPC so that it no longer shows "NPC_Template"
			npc.Name = ""
			npc.Parent = workspace
			local wp0 = waypointsFolder:FindFirstChild("Waypoint0")
			if wp0 then
				npc:SetPrimaryPartCFrame(wp0.CFrame)
			end

			-- Track this NPC for the listing (for cleanup when deleted)
			if adData.key then
				trackNPCForListing(npc, adData.key)
			end

			-- First, remove any existing clothing
			local existingShirt = npc:FindFirstChildOfClass("Shirt")
			local existingPants = npc:FindFirstChildOfClass("Pants")
			
			-- Only remove existing shirt if no shirt was submitted
			if existingShirt and shirtValue == "" then
				existingShirt:Destroy()
			end
			
			-- Only remove existing pants if no pants was submitted
			if existingPants and pantsValue == "" then
				existingPants:Destroy()
			end

			-- Update or add clothing to the NPC using real templates.
			if shirtValue ~= "" then
				local shirtTemplate = getClothingTemplate(shirtValue, "Shirt")
				local shirt = npc:FindFirstChildOfClass("Shirt")
				if shirt then
					shirt.ShirtTemplate = shirtTemplate
				else
					shirt = Instance.new("Shirt")
					shirt.Name = "Shirt"
					shirt.ShirtTemplate = shirtTemplate
					shirt.Parent = npc
				end
				print("DEBUG: [NPCSpawnerLoop] Applied shirt template: " .. shirtTemplate)
			end
			if pantsValue ~= "" then
				local pantsTemplate = getClothingTemplate(pantsValue, "Pants")
				local pants = npc:FindFirstChildOfClass("Pants")
				if pants then
					pants.PantsTemplate = pantsTemplate
				else
					pants = Instance.new("Pants")
					pants.Name = "Pants"
					pants.PantsTemplate = pantsTemplate
					pants.Parent = npc
				end
				print("DEBUG: [NPCSpawnerLoop] Applied pants template: " .. pantsTemplate)
			end
			
			-- Apply skin tone if it was saved
			if adData.skinToneData then
				-- Find or create the Body Colors instance
				local bodyColors = npc:FindFirstChild("Body Colors")
				if not bodyColors then
					bodyColors = Instance.new("BodyColors")
					bodyColors.Parent = npc
				end
				
				-- Create Color3 from the saved RGB values
				local skinColor = Color3.new(
					adData.skinToneData.R, 
					adData.skinToneData.G, 
					adData.skinToneData.B
				)
				
				-- Apply the color to all body parts
				local brickColor = BrickColor.new(skinColor)
				bodyColors.HeadColor = brickColor
				bodyColors.TorsoColor = brickColor
				bodyColors.LeftArmColor = brickColor
				bodyColors.RightArmColor = brickColor
				bodyColors.LeftLegColor = brickColor
				bodyColors.RightLegColor = brickColor
			end

			-- Set all NPC parts to the "NPC" collision group.
			for _, part in ipairs(npc:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CollisionGroup = "NPC"
				end
			end

			-- Add a ProximityPrompt for "try on" (attached to Head if available).
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
				-- Adjust UIOffset as needed; here it is set to appear 100 pixels below.
				prompt.UIOffset = Vector2.new(0, 100)
				prompt.Triggered:Connect(function(triggeringPlayer)
					local character = triggeringPlayer.Character
					if not character then return end

					local originalShirt, originalPants
					local currentShirt = character:FindFirstChildOfClass("Shirt")
					if currentShirt then
						originalShirt = currentShirt.ShirtTemplate
						-- Only remove the current shirt if we're trying on a new shirt
						if shirtValue ~= "" then
							currentShirt:Destroy()
						end
					end
					local currentPants = character:FindFirstChildOfClass("Pants")
					if currentPants then
						originalPants = currentPants.PantsTemplate
						-- Only remove the current pants if we're trying on new pants
						if pantsValue ~= "" then
							currentPants:Destroy()
						end
					end

					-- Track try-ons when clothing is applied
					if shirtValue ~= "" then
						local shirtTemplate = getClothingTemplate(shirtValue, "Shirt")
						local newShirt = Instance.new("Shirt")
						newShirt.ShirtTemplate = shirtTemplate
						newShirt.Parent = character
						
						-- Track the shirt try-on
						print("Player " .. triggeringPlayer.Name .. " tried on shirt #" .. shirtValue .. " via ProximityPrompt")
						incrementTryOnCount(tonumber(shirtValue), "Shirt")
					end
					if pantsValue ~= "" then
						local pantsTemplate = getClothingTemplate(pantsValue, "Pants")
						local newPants = Instance.new("Pants")
						newPants.PantsTemplate = pantsTemplate
						newPants.Parent = character
						
						-- Track the pants try-on
						print("Player " .. triggeringPlayer.Name .. " tried on pants #" .. pantsValue .. " via ProximityPrompt")
						incrementTryOnCount(tonumber(pantsValue), "Pants")
					end
					
					-- Update daily objectives for clothing try-on (once per action, not per clothing piece)
					if (shirtValue ~= "" or pantsValue ~= "") and _G.UpdateDailyObjective then
						local success, err = pcall(function()
							_G.UpdateDailyObjective(triggeringPlayer, "tryOnClothes", 1)
						end)
						if not success then
							warn("DEBUG: [NPCSpawnerLoop] Daily objective update failed:", err)
						end
					end

					-- Clothing now stays on the player until manually changed
					-- No automatic revert after 10 seconds
				end)
			end

			-- Create purchase zones covering the upper and lower body.
			local upperParts = {}
			local lowerParts = {}
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

			if shirtValue ~= "" and upperSize.Magnitude > 0 then
				local upperZone = Instance.new("Part")
				upperZone.Name = "UpperPurchaseZone"
				upperZone.Size = upperSize + Vector3.new(1, 1, 1)
				upperZone.CFrame = upperCFrame
				upperZone.Transparency = 1
				upperZone.CanCollide = false
				upperZone.Parent = npc

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = upperZone
				weld.Part1 = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
				weld.Parent = upperZone

				local upperCD = Instance.new("ClickDetector")
				upperCD.MaxActivationDistance = 10
				upperCD.Parent = upperZone
				upperCD.MouseClick:Connect(function(player)
					MarketplaceService:PromptPurchase(player, tonumber(shirtValue))
				end)
			end

			if pantsValue ~= "" and lowerSize.Magnitude > 0 then
				local lowerZone = Instance.new("Part")
				lowerZone.Name = "LowerPurchaseZone"
				lowerZone.Size = lowerSize + Vector3.new(1, 1, 1)
				lowerZone.CFrame = lowerCFrame
				lowerZone.Transparency = 1
				lowerZone.CanCollide = false
				lowerZone.Parent = npc

				local weld2 = Instance.new("WeldConstraint")
				weld2.Part0 = lowerZone
				weld2.Part1 = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
				weld2.Parent = lowerZone

				local lowerCD = Instance.new("ClickDetector")
				lowerCD.MaxActivationDistance = 10
				lowerCD.Parent = lowerZone
				lowerCD.MouseClick:Connect(function(player)
					MarketplaceService:PromptPurchase(player, tonumber(pantsValue))
				end)
			end

			spawn(function()
				moveNPC(npc)
			end)
			wait(spawnInterval)
		end
	end
	-- Add a small delay before next iteration
	wait(1)
end
