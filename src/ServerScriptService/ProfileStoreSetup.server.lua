-- ProfileStore Data Handler
-- Replaces Firebase with Roblox DataStore using ProfileStore

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Pre-create essential RemoteEvents to prevent infinite yield warnings
local function createEssentialRemoteEvents()
	-- Create RemoteEvents that other scripts might wait for
	local function createIfNotExists(name, className)
		if not ReplicatedStorage:FindFirstChild(name) then
			local instance = Instance.new(className)
			instance.Name = name
			instance.Parent = ReplicatedStorage
		end
	end

	-- Core ProfileStore events
	createIfNotExists("ProfileDataEvent", "RemoteEvent")
	createIfNotExists("ListingsEvent", "RemoteEvent")
	createIfNotExists("ClothingOrderEvent", "RemoteEvent")
	createIfNotExists("TryOnEvent", "RemoteEvent")
	createIfNotExists("SalesEvent", "RemoteEvent")
	createIfNotExists("BillboardEvent", "RemoteEvent")
	createIfNotExists("PetEvent", "RemoteEvent")
	createIfNotExists("GetPlayerData", "RemoteFunction")
	createIfNotExists("UpdatePlayerData", "RemoteFunction")
	createIfNotExists("SaveMusicSetting", "RemoteFunction")

	-- Daily Bonus System events (needed immediately by client)
	createIfNotExists("UpdateBonusTimerEvent", "RemoteEvent")
	createIfNotExists("RequestTimerDataFunc", "RemoteFunction")

	-- Asset Stats events (needed immediately by client)
	createIfNotExists("GetAssetStatsFunc", "RemoteFunction")
	createIfNotExists("OpenAssetStatsEvent", "RemoteEvent")

	-- Listings system events
	createIfNotExists("RenewListingEvent", "RemoteEvent")
	createIfNotExists("RenewListingSuccessEvent", "RemoteEvent")
	createIfNotExists("RenewListingFailedEvent", "RemoteEvent")

	-- Daily Objectives folder and events
	local dailyObjectivesFolder = ReplicatedStorage:FindFirstChild("DailyObjectives")
	if not dailyObjectivesFolder then
		dailyObjectivesFolder = Instance.new("Folder")
		dailyObjectivesFolder.Name = "DailyObjectives"
		dailyObjectivesFolder.Parent = ReplicatedStorage

		-- Create events inside the folder
		local updateObjectiveEvent = Instance.new("RemoteEvent")
		updateObjectiveEvent.Name = "UpdateObjectiveEvent"
		updateObjectiveEvent.Parent = dailyObjectivesFolder

		local getObjectivesFunc = Instance.new("RemoteFunction")
		getObjectivesFunc.Name = "GetObjectivesFunc"
		getObjectivesFunc.Parent = dailyObjectivesFolder
	end

	-- Notification system
	createIfNotExists("NotificationEvent", "RemoteEvent")
end

-- Create RemoteEvents immediately to prevent waiting issues
createEssentialRemoteEvents()

-- Get ProfileStore module
local ProfileStore = require(ReplicatedStorage:WaitForChild("ProfileStore"))

-- Profile templates for different data types
local PLAYER_TEMPLATE = {
	coins = 0,
	xp = 0,
	level = 1,
	joinDate = os.time(),
	lastLogin = os.time(),
	purchases = {},
	settings = {
		musicEnabled = true,
		notifications = true,
	},
	stats = {
		totalPurchases = 0,
		totalSpent = 0,
		totalSold = 0,
		favoriteItems = {},
	},
	dailyObjectives = {
		objectives = {},
		lastReset = 0,
		completed = {},
	},
	lastDailyBonus = 0,
}

local LISTINGS_TEMPLATE = {
	-- Structure: [listingId] = {userId, assetId, price, timestamp, etc.}
}

local ADS_TEMPLATE = {
	-- Structure: [adId] = {userId, shirtId, pantsId, timestamp, skinToneData, etc.}
}

local TRYONS_TEMPLATE = {
	shirts = {},
	pants = {},
	-- Structure: shirts[assetId] = count, pants[assetId] = count
}

local SALES_TEMPLATE = {
	shirts = {},
	pants = {},
	-- Structure: shirts[assetId] = {count = number, timestamps = {timestamp1, timestamp2, ...}}
	--            pants[assetId] = {count = number, timestamps = {timestamp1, timestamp2, ...}}
}

local BILLBOARDS_TEMPLATE = {
	active = {},
	history = {},
	currentIndex = 1,
	-- Structure:
	-- active[n] = {assetId, playerName, playerId, rentedAt, expiresAt, duration}
	-- history[timestamp] = billboard data
	-- currentIndex = which billboard in active array is currently showing
}

local PETS_TEMPLATE = {
	-- Structure: [petId] = {id, name, rarity, level, experience, etc.}
}

local EQUIPPED_PETS_TEMPLATE = {
	slot1 = nil,
	slot2 = nil,
	slot3 = nil,
	-- Structure: slotX = petId or nil
}

-- Create ProfileStore instances
local PlayerStore = ProfileStore.New("PlayerData", PLAYER_TEMPLATE)
local ListingsStore = ProfileStore.New("Listings", LISTINGS_TEMPLATE)
local AdsStore = ProfileStore.New("ClothingOrders", ADS_TEMPLATE) -- Changed from "Ads" to match Firebase node
local TryOnsStore = ProfileStore.New("TryOns", TRYONS_TEMPLATE)
local SalesStore = ProfileStore.New("Sales", SALES_TEMPLATE)
local BillboardsStore = ProfileStore.New("Billboards", BILLBOARDS_TEMPLATE)
local PetsStore = ProfileStore.New("Pets", PETS_TEMPLATE)
local EquippedPetsStore = ProfileStore.New("EquippedPets", EQUIPPED_PETS_TEMPLATE)

-- Active profiles storage
local Profiles = {}
local ListingsProfile = nil
local AdsProfile = nil
local TryOnsProfile = nil
local SalesProfile = nil
local BillboardsProfile = nil
local PetsProfiles = {} -- {userId = profile}
local EquippedPetsProfiles = {} -- {userId = profile}

-- Load pet profiles for a player
local function loadPetProfiles(player)
	local userId = tostring(player.UserId)

	-- Load pets profile
	local petsProfile = PetsStore:StartSessionAsync(userId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if petsProfile then
		petsProfile:AddUserId(player.UserId)
		petsProfile:Reconcile()

		petsProfile.OnSessionEnd:Connect(function()
			PetsProfiles[userId] = nil
		end)

		if player.Parent ~= Players then
			petsProfile:EndSession()
		else
			PetsProfiles[userId] = petsProfile
		end
	end

	-- Load equipped pets profile
	local equippedPetsProfile = EquippedPetsStore:StartSessionAsync(userId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if equippedPetsProfile then
		equippedPetsProfile:AddUserId(player.UserId)
		equippedPetsProfile:Reconcile()

		equippedPetsProfile.OnSessionEnd:Connect(function()
			EquippedPetsProfiles[userId] = nil
		end)

		if player.Parent ~= Players then
			equippedPetsProfile:EndSession()
		else
			EquippedPetsProfiles[userId] = equippedPetsProfile
		end
	end
end

-- Initialize shared data profiles with staggered loading
local function initializeSharedProfiles()
	-- PRIORITY 1: Essential systems (load immediately)
	local function tryLoadProfile(store, key, maxAttempts)
		local attempts = 0
		local profile
		
		repeat
			attempts = attempts + 1
			print(string.format("DEBUG: [ProfileStore] Attempting to load %s profile (attempt %d/%d)", key, attempts, maxAttempts))
			
			profile = store:StartSessionAsync(key, {
				Cancel = function()
					return false -- Never cancel
				end,
			})
			
			if profile then
				print(string.format("DEBUG: [ProfileStore] Successfully loaded %s profile", key))
				profile:Reconcile()
			else
				warn(string.format("DEBUG: [ProfileStore] Failed to load %s profile on attempt %d", key, attempts))
				if attempts < maxAttempts then
					wait(5) -- Wait 5 seconds before retrying
				end
			end
		until profile or attempts >= maxAttempts
		
		return profile
	end

	-- Start session for listings data (essential for marketplace)
	ListingsProfile = tryLoadProfile(ListingsStore, "global_listings", 3)
	if not ListingsProfile then
		warn("ProfileStore: Failed to load listings profile after 3 attempts")
	end

	-- Wait before loading next profile
	wait(3)

	-- Start session for ads data (essential for NPCs)
	AdsProfile = tryLoadProfile(AdsStore, "global_ads", 3)
	if not AdsProfile then
		warn("ProfileStore: Failed to load ads profile after 3 attempts")
	end

	-- PRIORITY 2: Semi-essential systems (delay 10 seconds)
	spawn(function()
		wait(10)

		-- Start session for try-ons data
		TryOnsProfile = tryLoadProfile(TryOnsStore, "global_tryons", 3)
		if not TryOnsProfile then
			warn("ProfileStore: Failed to load tryons profile after 3 attempts")
		end

		wait(5)

		-- Start session for sales data
		SalesProfile = tryLoadProfile(SalesStore, "global_sales", 3)
		if not SalesProfile then
			warn("ProfileStore: Failed to load sales profile after 3 attempts")
		end

		wait(5)

		-- Start session for billboards data
		BillboardsProfile = tryLoadProfile(BillboardsStore, "global_billboards", 3)
		if not BillboardsProfile then
			warn("ProfileStore: Failed to load billboards profile after 3 attempts")
		end
	end)

	-- PRIORITY 3: Non-essential systems (delay 30 seconds) - now empty since billboards moved to PRIORITY 2
end

-- Load player data
local function loadPlayerData(player)
	-- Add safety check
	if not player or not player.Parent then
		warn("ProfileStore: Player invalid during loadPlayerData")
		return nil
	end

	local success, profile = pcall(function()
		return PlayerStore:StartSessionAsync(tostring(player.UserId), {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})
	end)

	if not success then
		warn("ProfileStore: Failed to start session for " .. player.Name .. ": " .. tostring(profile))
		return nil
	end

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from template

		profile.OnSessionEnd:Connect(function()
			Profiles[player] = nil
			player:Kick("Profile session end - Please rejoin")
		end)

		if player.Parent == Players then
			Profiles[player] = profile

			-- Update last login
			profile.Data.lastLogin = os.time()

			-- Load pet profiles with error handling
			local petLoadSuccess, petError = pcall(function()
				loadPetProfiles(player)
			end)

			if not petLoadSuccess then
				warn("ProfileStore: Failed to load pet profiles for " .. player.Name .. ": " .. tostring(petError))
			end

			return profile
		else
			-- Player left before profile loaded
			profile:EndSession()
		end
	else
		-- Profile load failed
		warn("ProfileStore: Profile load failed for " .. player.Name)
		player:Kick("Profile load fail - Please rejoin")
	end

	return nil
end

-- Save player data (called automatically by ProfileStore)
local function savePlayerData(player)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
		return true
	end
	return false
end

-- Handle player joining
Players.PlayerAdded:Connect(function(player)
	-- Reduce delay to prevent overwhelming the system
	task.wait(0.05)

	local profile = loadPlayerData(player)

	if profile then
		-- Create leaderstats
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = profile.Data.coins or 0
		coins.Parent = leaderstats

		local level = Instance.new("IntValue")
		level.Name = "Level"
		level.Value = profile.Data.level or 1
		level.Parent = leaderstats

		-- Add XP to leaderstats
		local xp = Instance.new("IntValue")
		xp.Name = "XP"
		xp.Value = profile.Data.xp or 0
		xp.Parent = leaderstats

		-- Set player data loaded attribute
		player:SetAttribute("PlayerDataLoaded", true)
	else
		warn("ProfileStore: Failed to load profile for:", player.Name)
	end
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile then
		-- Update data from leaderstats before saving
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			if leaderstats:FindFirstChild("Coins") then
				profile.Data.coins = leaderstats.Coins.Value
			end
			if leaderstats:FindFirstChild("Level") then
				profile.Data.level = leaderstats.Level.Value
			end
		end

		profile:EndSession()
	end

	-- Clean up pet profiles
	local userId = tostring(player.UserId)
	if PetsProfiles[userId] then
		PetsProfiles[userId]:EndSession()
		PetsProfiles[userId] = nil
	end
	if EquippedPetsProfiles[userId] then
		EquippedPetsProfiles[userId]:EndSession()
		EquippedPetsProfiles[userId] = nil
	end
end)

-- Initialize shared profiles
task.spawn(function()
	-- Reduce the initialization delay
	task.wait(0.5)
	initializeSharedProfiles()

	-- Set readiness flag after everything is initialized
	_G.ProfileStoreData.IsReady = true
end)

-- Global functions for other scripts to use
_G.ProfileStoreData = {
	-- Readiness flag
	IsReady = false,

	-- Player data functions
	GetPlayerProfile = function(player)
		return Profiles[player]
	end,

	UpdateCoins = function(player, newCoins)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			profile.Data.coins = newCoins
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats and leaderstats:FindFirstChild("Coins") then
				leaderstats.Coins.Value = newCoins
			end
			return true
		end
		return false
	end,

	UpdateLevel = function(player, newLevel)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			profile.Data.level = newLevel
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats and leaderstats:FindFirstChild("Level") then
				leaderstats.Level.Value = newLevel
			end
			return true
		end
		return false
	end,

	UpdateXP = function(player, newXP)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			profile.Data.xp = newXP
			-- Also update leaderstats
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats and leaderstats:FindFirstChild("XP") then
				leaderstats.XP.Value = newXP
			end
			return true
		end
		return false
	end,

	AddXP = function(player, xpToAdd)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			profile.Data.xp = (profile.Data.xp or 0) + xpToAdd
			-- Also update leaderstats
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats and leaderstats:FindFirstChild("XP") then
				leaderstats.XP.Value = profile.Data.xp
			end
			return true
		end
		return false
	end,

	GetPlayerXP = function(player)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			return profile.Data.xp or 0
		end
		return 0
	end,

	-- Listings data functions
	GetListings = function()
		if ListingsProfile and ListingsProfile:IsActive() then
			return ListingsProfile.Data
		end
		return {}
	end,

	AddListing = function(listingId, listingData)
		if ListingsProfile and ListingsProfile:IsActive() then
			ListingsProfile.Data[listingId] = listingData
			return true
		end
		return false
	end,

	RemoveListing = function(listingId)
		if ListingsProfile and ListingsProfile:IsActive() then
			ListingsProfile.Data[listingId] = nil
			return true
		end
		return false
	end,

	UpdateListing = function(listingId, listingData)
		if ListingsProfile and ListingsProfile:IsActive() then
			if ListingsProfile.Data[listingId] then
				ListingsProfile.Data[listingId] = listingData
				return true
			end
		end
		return false
	end,

	-- Ads/Clothing Orders functions
	GetAds = function()
		if AdsProfile and AdsProfile:IsActive() then
			return AdsProfile.Data
		end
		return {}
	end,

	AddAd = function(adId, adData)
		if AdsProfile and AdsProfile:IsActive() then
			AdsProfile.Data[adId] = adData
			return true
		end
		return false
	end,

	RemoveAd = function(adId)
		if AdsProfile and AdsProfile:IsActive() then
			AdsProfile.Data[adId] = nil
			return true
		end
		return false
	end,

	UpdateAd = function(adId, adData)
		if AdsProfile and AdsProfile:IsActive() then
			if AdsProfile.Data[adId] then
				AdsProfile.Data[adId] = adData
				return true
			end
		end
		return false
	end,

	-- Try-ons tracking functions
	IncrementTryOn = function(assetId, assetType)
		if TryOnsProfile and TryOnsProfile:IsActive() then
			local category = assetType:lower() .. "s" -- "shirt" -> "shirts", "pants" -> "pants"
			if not TryOnsProfile.Data[category] then
				TryOnsProfile.Data[category] = {}
			end

			local currentCount = TryOnsProfile.Data[category][tostring(assetId)] or 0
			TryOnsProfile.Data[category][tostring(assetId)] = currentCount + 1
			return true
		end
		return false
	end,

	GetTryOnCount = function(assetId, assetType)
		if TryOnsProfile and TryOnsProfile:IsActive() then
			local category = assetType:lower() .. "s"
			if TryOnsProfile.Data[category] then
				return TryOnsProfile.Data[category][tostring(assetId)] or 0
			end
		end
		return 0
	end,

	GetAllTryOns = function()
		if TryOnsProfile and TryOnsProfile:IsActive() then
			return TryOnsProfile.Data
		end
		return {}
	end,

	-- Sales tracking functions
	IncrementSales = function(assetId, assetType)
		if SalesProfile and SalesProfile:IsActive() then
			local category = assetType:lower() .. "s" -- "shirt" -> "shirts", "pants" -> "pants"
			if not SalesProfile.Data[category] then
				SalesProfile.Data[category] = {}
			end

			local assetKey = tostring(assetId)
			if not SalesProfile.Data[category][assetKey] then
				SalesProfile.Data[category][assetKey] = {
					count = 0,
					timestamps = {},
				}
			end

			-- Add the current timestamp
			local currentTime = os.time()
			table.insert(SalesProfile.Data[category][assetKey].timestamps, currentTime)
			SalesProfile.Data[category][assetKey].count = SalesProfile.Data[category][assetKey].count + 1
			return true
		end
		return false
	end,

	GetSalesCount = function(assetId, assetType)
		if SalesProfile and SalesProfile:IsActive() then
			local category = assetType:lower() .. "s"
			local assetKey = tostring(assetId)
			if SalesProfile.Data[category] and SalesProfile.Data[category][assetKey] then
				return SalesProfile.Data[category][assetKey].count or 0
			end
		end
		return 0
	end,

	GetRecentSalesCount = function(assetId, assetType, hoursBack)
		if SalesProfile and SalesProfile:IsActive() then
			local category = assetType:lower() .. "s"
			local assetKey = tostring(assetId)
			if SalesProfile.Data[category] and SalesProfile.Data[category][assetKey] then
				local salesData = SalesProfile.Data[category][assetKey]
				if salesData.timestamps then
					local currentTime = os.time()
					local cutoffTime = currentTime - (hoursBack * 3600) -- Convert hours to seconds
					local recentCount = 0

					for _, timestamp in ipairs(salesData.timestamps) do
						if timestamp >= cutoffTime then
							recentCount = recentCount + 1
						end
					end

					return recentCount
				end
			end
		end
		return 0
	end,

	GetAllSales = function()
		if SalesProfile and SalesProfile:IsActive() then
			-- Convert new format to simple format for backward compatibility
			local salesData = SalesProfile.Data
			local simpleSales = {}

			for category, assets in pairs(salesData) do
				simpleSales[category] = {}
				for assetId, data in pairs(assets) do
					if type(data) == "table" and data.count then
						simpleSales[category][assetId] = data.count
					elseif type(data) == "number" then
						-- Handle old format if any exists
						simpleSales[category][assetId] = data
					end
				end
			end

			return simpleSales
		end
		return {}
	end,

	-- Billboard functions
	GetCurrentBillboard = function()
		if BillboardsProfile and BillboardsProfile:IsActive() then
			-- Get only active (non-expired) billboards for rotation
			local activeBillboards = _G.ProfileStoreData.GetAllActiveBillboards()

			if activeBillboards and #activeBillboards > 0 then
				local currentIndex = BillboardsProfile.Data.currentIndex or 1
				-- Make sure index is valid
				if currentIndex > #activeBillboards then
					currentIndex = 1
					BillboardsProfile.Data.currentIndex = currentIndex
				end

				return activeBillboards[currentIndex]
			end
		end
		return nil
	end,

	GetAllActiveBillboards = function()
		if BillboardsProfile and BillboardsProfile:IsActive() then
			local allBillboards = BillboardsProfile.Data.active or {}
			local activeBillboards = {}
			local currentTime = os.time()

			-- Filter out expired billboards for rotation purposes only
			for _, billboard in ipairs(allBillboards) do
				if billboard and billboard.expiresAt and currentTime < billboard.expiresAt then
					table.insert(activeBillboards, billboard)
				end
			end

			return activeBillboards
		end
		return {}
	end,

	-- Get all billboards for a specific player (including expired ones for renewal)
	GetPlayerBillboards = function(playerId, includeExpired)
		if BillboardsProfile and BillboardsProfile:IsActive() then
			local allBillboards = BillboardsProfile.Data.active or {}
			local playerBillboards = {}
			local currentTime = os.time()

			for i, billboard in ipairs(allBillboards) do
				-- Try both numeric and string comparison
				-- Assuming playerId stored and playerId argument should be comparable
				-- If type mismatches are an issue (e.g. number vs string), use tostring() for comparison:
				-- if tostring(billboard.playerId) == tostring(playerId) then

				if billboard.playerId == playerId then
					local isExpired = billboard.expiresAt and currentTime >= billboard.expiresAt

					-- Include if not expired, or if expired and includeExpired is true
					if not isExpired or includeExpired then
						table.insert(playerBillboards, billboard)
					end
				end
			end

			print("DEBUG: [ProfileStore] Returning", #playerBillboards, "billboards for player")
			return playerBillboards
		end
		return {}
	end,

	GetNextBillboard = function()
		if BillboardsProfile and BillboardsProfile:IsActive() then
			local activeBillboards = BillboardsProfile.Data.active
			if activeBillboards and #activeBillboards > 0 then
				local currentIndex = BillboardsProfile.Data.currentIndex or 1
				-- Move to next billboard
				currentIndex = currentIndex + 1
				if currentIndex > #activeBillboards then
					currentIndex = 1
				end
				BillboardsProfile.Data.currentIndex = currentIndex

				return _G.ProfileStoreData.GetCurrentBillboard()
			end
		end
		return nil
	end,

	CleanupExpiredBillboards = function()
		-- Note: This function is only for rotation management
		-- Expired billboards are kept in storage for player access and renewal
		-- They are just filtered out when getting active billboards for rotation
		if BillboardsProfile and BillboardsProfile:IsActive() then
			-- We don't actually remove expired billboards from storage anymore
			-- They are filtered out in GetAllActiveBillboards for rotation purposes
			-- but kept available for player management and renewal
		end
	end,

	SaveBillboardData = function(assetId, playerName, playerId, duration)
		if BillboardsProfile and BillboardsProfile:IsActive() then
			local currentTime = os.time()
			local expiresAt = currentTime + duration

			local data = {
				assetId = assetId,
				playerName = playerName,
				playerId = playerId,
				rentedAt = currentTime,
				expiresAt = expiresAt,
				duration = duration,
			}

			-- Initialize active array if it doesn't exist
			if not BillboardsProfile.Data.active then
				BillboardsProfile.Data.active = {}
			end

			-- Add to active billboards
			table.insert(BillboardsProfile.Data.active, data)

			-- Also save to history
			if not BillboardsProfile.Data.history then
				BillboardsProfile.Data.history = {}
			end
			BillboardsProfile.Data.history[tostring(currentTime)] = data
			return true
		end
		return false
	end,

	RemoveBillboardByPlayer = function(playerId)
		if BillboardsProfile and BillboardsProfile:IsActive() then
			local activeBillboards = BillboardsProfile.Data.active
			if activeBillboards then
				for i = #activeBillboards, 1, -1 do
					local billboard = activeBillboards[i]
					if billboard and billboard.playerId == playerId then
						table.remove(activeBillboards, i)
						-- Adjust current index if needed
						if BillboardsProfile.Data.currentIndex > #activeBillboards then
							BillboardsProfile.Data.currentIndex = 1
						end
						return true
					end
				end
			end
		end
		return false
	end,

	RenewBillboard = function(playerId, assetId, rentedAt, newExpiration)
		if BillboardsProfile and BillboardsProfile:IsActive() then
			local activeBillboards = BillboardsProfile.Data.active
			if activeBillboards then
				for i, billboard in ipairs(activeBillboards) do
					if
						billboard
						and billboard.playerId == playerId
						and billboard.assetId == assetId
						and billboard.rentedAt == rentedAt
					then
						-- Found the billboard, update its expiration
						billboard.expiresAt = newExpiration
						return true
					end
				end
			end
		end
		return false
	end,

	-- Daily Objectives functions
	GetPlayerDailyObjectives = function(player)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			return profile.Data.dailyObjectives or {}
		end
		return {}
	end,

	UpdatePlayerDailyObjectives = function(player, objectivesData)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			profile.Data.dailyObjectives = objectivesData
			return true
		end
		return false
	end,

	GetLastDailyBonus = function(player)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			local result = profile.Data.lastDailyBonus or 0
			return result
		end
		return 0
	end,

	SetLastDailyBonus = function(player, timestamp)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			profile.Data.lastDailyBonus = timestamp
			return true
		end
		return false
	end,

	-- Purchase tracking functions
	AddPurchase = function(player, purchaseData)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			if not profile.Data.purchases then
				profile.Data.purchases = {}
			end
			table.insert(profile.Data.purchases, purchaseData)

			-- Update stats
			if not profile.Data.stats then
				profile.Data.stats = {
					totalPurchases = 0,
					totalSpent = 0,
					totalSold = 0,
					favoriteItems = {},
				}
			end
			profile.Data.stats.totalPurchases = (profile.Data.stats.totalPurchases or 0) + 1
			if purchaseData.cost then
				profile.Data.stats.totalSpent = (profile.Data.stats.totalSpent or 0) + purchaseData.cost
			end

			return true
		end
		return false
	end,

	UpdatePlayerStats = function(player, statsData)
		local profile = Profiles[player]
		if profile and profile:IsActive() then
			if not profile.Data.stats then
				profile.Data.stats = {}
			end
			for key, value in pairs(statsData) do
				profile.Data.stats[key] = value
			end
			return true
		end
		return false
	end,

	-- Pet System Functions
	GetPlayerPets = function(userId)
		local userIdStr = tostring(userId)
		local profile = PetsProfiles[userIdStr]
		if profile and profile:IsActive() then
			local petsData = profile.Data

			-- Transform from ProfileStore object to array format (like Firebase did)
			local petsArray = {}
			for id, petData in pairs(petsData) do
				-- Make sure id is included with pet data
				petData.id = id
				table.insert(petsArray, petData)
			end

			-- Sort pets by rarity and then level (same as Firebase)
			table.sort(petsArray, function(a, b)
				local rarityOrder = {
					["Common"] = 1,
					["Rare"] = 2,
					["Legendary"] = 3,
					["VIP"] = 4,
				}

				local rarityA = rarityOrder[a.rarity] or 0
				local rarityB = rarityOrder[b.rarity] or 0

				if rarityA ~= rarityB then
					return rarityA > rarityB -- Higher rarity first
				end

				return a.level > b.level -- Higher level first
			end)

			return petsArray
		end
		return {}
	end,

	SavePet = function(userId, petData)
		local userIdStr = tostring(userId)
		local profile = PetsProfiles[userIdStr]
		if profile and profile:IsActive() then
			local petId = petData.id
			if not petId then
				petId = game:GetService("HttpService"):GenerateGUID(false)
				petData.id = petId
			end

			profile.Data[petId] = petData
			return true, petId
		end
		return false
	end,

	DeletePet = function(userId, petId)
		local userIdStr = tostring(userId)
		local profile = PetsProfiles[userIdStr]
		if profile and profile:IsActive() then
			profile.Data[petId] = nil
			return true
		end
		return false
	end,

	GetEquippedPets = function(userId)
		local userIdStr = tostring(userId)
		local profile = EquippedPetsProfiles[userIdStr]
		if profile and profile:IsActive() then
			return profile.Data
		end
		return { slot1 = nil, slot2 = nil, slot3 = nil }
	end,

	EquipPet = function(userId, petId, slot)
		-- Validate slot
		if slot ~= "slot1" and slot ~= "slot2" and slot ~= "slot3" then
			return false, "Invalid slot number"
		end

		local userIdStr = tostring(userId)
		local profile = EquippedPetsProfiles[userIdStr]
		if profile and profile:IsActive() then
			profile.Data[slot] = petId
			return true
		end
		return false, "Failed to save equipped pets"
	end,

	UnequipPet = function(userId, slot)
		-- Validate slot
		if slot ~= "slot1" and slot ~= "slot2" and slot ~= "slot3" then
			return false, "Invalid slot number"
		end

		local userIdStr = tostring(userId)
		local profile = EquippedPetsProfiles[userIdStr]
		if profile and profile:IsActive() then
			profile.Data[slot] = nil
			return true
		end
		return false, "Failed to save equipped pets"
	end,

	MigrateFromDataStore = function(ownedPetsStore, userId)
		local key = tostring(userId)

		-- Get pets from data store
		local success, ownedPets = pcall(function()
			return ownedPetsStore:GetAsync(key) or {}
		end)

		if not success or not ownedPets or #ownedPets == 0 then
			return false, "No pets found in DataStore"
		end

		-- Save each pet to ProfileStore
		local migratedCount = 0
		for _, pet in ipairs(ownedPets) do
			-- Make sure each pet has a unique ID
			if not pet.id or pet.id == "" then
				pet.id = game:GetService("HttpService"):GenerateGUID(false)
			end

			local saveSuccess = _G.ProfileStoreData.SavePet(userId, pet)
			if saveSuccess then
				migratedCount = migratedCount + 1
			end
		end

		return true, "Migrated " .. migratedCount .. " pets"
	end,

	-- Direct profile access (for advanced usage)
	PlayerStore = PlayerStore,
	ListingsStore = ListingsStore,
	AdsStore = AdsStore,
	TryOnsStore = TryOnsStore,
	SalesStore = SalesStore,
	BillboardsStore = BillboardsStore,
	PetsStore = PetsStore,
	EquippedPetsStore = EquippedPetsStore,

	-- Profile instances
	ListingsProfile = function()
		return ListingsProfile
	end,
	AdsProfile = function()
		return AdsProfile
	end,
	TryOnsProfile = function()
		return TryOnsProfile
	end,
	BillboardsProfile = function()
		return BillboardsProfile
	end,
	SalesProfile = function()
		return SalesProfile
	end,
}

-- Save or load music setting for a player
_G.ProfileStoreData.SetMusicEnabled = function(player, enabled)
	local profile = Profiles[player]
	if profile and profile:IsActive() then
		profile.Data.settings = profile.Data.settings or {}
		profile.Data.settings.musicEnabled = enabled
		ReplicatedStorage.MusicSetting:FireClient(enabled)
		return true
	end
	warn("Profile not loaded for", player)
	return false
end