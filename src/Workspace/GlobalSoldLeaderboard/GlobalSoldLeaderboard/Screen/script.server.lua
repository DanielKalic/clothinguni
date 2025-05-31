local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local TempPart = script.Parent
local SurfaceGui = TempPart:WaitForChild("SurfaceGui")
local MainFrame = SurfaceGui:WaitForChild("Frame")
local Template = script:WaitForChild("Template")

-- SETTINGS for Sold leaderboard:
local CurrencyName = "Sold"     -- stat key to sort by
local ListSize = 100            -- maximum number of entries to display
local UpdateEvery = 30          -- seconds between updates (increased for performance)
local MinimumRequirement = 1    -- minimum value to appear on leaderboard

-- Create OrderedDataStore for global leaderboard
local SoldLeaderboardStore = DataStoreService:GetOrderedDataStore("GlobalSoldLeaderboard")

-- Create DataStore to track all players who have ever joined
local PlayerRegistryStore = DataStoreService:GetDataStore("PlayerRegistry")

-- Create DataStore to track migration cooldowns
local MigrationCooldownStore = DataStoreService:GetDataStore("MigrationCooldown")

-- Wait for ProfileStore data to be ready
repeat
	wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

local function abbreviate(value, idp)
	if value < 1000 then
		return math.floor(value + 0.5)
	else
		local abbreviations = {"", "K", "M", "B", "T"}
		local ex = math.floor(math.log(math.max(1, math.abs(value)), 1000))
		local abbrev = abbreviations[1 + ex] or ("e+" .. ex)
		local normal = math.floor(value * (10 ^ idp) / (1000 ^ ex)) / (10 ^ idp)
		return string.format("%." .. idp .. "f%s", normal, abbrev)
	end
end

local function clear()
	for _, v in ipairs(MainFrame:GetChildren()) do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end
end

-- Function to register a player in the registry
local function registerPlayer(player)
	local success, err = pcall(function()
		PlayerRegistryStore:SetAsync(tostring(player.UserId), {
			username = player.Name,
			lastSeen = os.time()
		})
	end)
	
	if success then
		print("GlobalSoldLeaderboard: Registered player " .. player.Name)
	else
		warn("GlobalSoldLeaderboard: Failed to register player " .. player.Name .. ": " .. tostring(err))
	end
end

-- Function to check if migration should run (once per hour globally)
local function shouldRunMigration()
	local success, lastMigration = pcall(function()
		return MigrationCooldownStore:GetAsync("GlobalSoldLastMigration")
	end)
	
	if not success then
		warn("GlobalSoldLeaderboard: Failed to check migration cooldown, allowing migration")
		return true
	end
	
	local currentTime = os.time()
	local oneHour = 3600 -- 1 hour in seconds
	
	-- If no previous migration or more than 1 hour has passed
	if not lastMigration or (currentTime - lastMigration) >= oneHour then
		-- Update the migration timestamp
		local updateSuccess = pcall(function()
			MigrationCooldownStore:SetAsync("GlobalSoldLastMigration", currentTime)
		end)
		
		if updateSuccess then
			print("GlobalSoldLeaderboard: Migration cooldown updated, proceeding with migration")
			return true
		else
			warn("GlobalSoldLeaderboard: Failed to update migration cooldown")
			return false
		end
	else
		local timeRemaining = oneHour - (currentTime - lastMigration)
		print("GlobalSoldLeaderboard: Migration skipped, cooldown active for " .. math.floor(timeRemaining/60) .. " more minutes")
		return false
	end
end

-- Function to migrate all registered players
local function migrateRegisteredPlayers()
	-- Check cooldown first
	if not shouldRunMigration() then
		return
	end
	
	print("GlobalSoldLeaderboard: Starting migration of all registered players...")
	
	-- Get the PlayerStore instance
	local playerStore = ProfileStoreData.PlayerStore
	if not playerStore then
		warn("GlobalSoldLeaderboard: Could not access PlayerStore for migration")
		return
	end
	
	local success, pages = pcall(function()
		return PlayerRegistryStore:ListKeysAsync()
	end)
	
	if not success or not pages then
		warn("GlobalSoldLeaderboard: Failed to get player registry")
		return
	end
	
	local migratedCount = 0
	local maxMigrations = 20 -- Reduced from 50 to 20 to prevent rate limiting
	local batchSize = 5 -- Process only 5 players at a time
	local batchDelay = 2 -- Wait 2 seconds between batches
	
	repeat
		local items = pages:GetCurrentPage()
		local batchCount = 0
		
		for _, item in ipairs(items) do
			if migratedCount >= maxMigrations then break end
			
			local userId = item.KeyName
			
			-- Try to load this player's profile in view mode
			local profileSuccess, profile = pcall(function()
				return playerStore:GetAsync(userId)
			end)
			
			if profileSuccess and profile and profile.Data then
				local sold = (profile.Data.stats and profile.Data.stats.totalSold) or 0
				
				if sold >= MinimumRequirement then
					-- Update OrderedDataStore with this player's data
					local storeSuccess, storeErr = pcall(function()
						SoldLeaderboardStore:SetAsync(userId, sold)
					end)
					
					if storeSuccess then
						migratedCount = migratedCount + 1
						print("GlobalSoldLeaderboard: Migrated user " .. userId .. " with " .. sold .. " sales")
					else
						warn("GlobalSoldLeaderboard: Failed to migrate user " .. userId .. ": " .. tostring(storeErr))
					end
				end
			end
			
			batchCount = batchCount + 1
			
			-- Batch processing with longer delays
			if batchCount >= batchSize then
				print("GlobalSoldLeaderboard: Processed batch of " .. batchCount .. " players, waiting " .. batchDelay .. " seconds...")
				wait(batchDelay)
				batchCount = 0
			else
				wait(0.2) -- Longer delay between individual requests
			end
			
			if migratedCount >= maxMigrations then break end
		end
		
		if pages.IsFinished then
			break
		else
			local pageSuccess, nextPage = pcall(function()
				return pages:AdvanceToNextPageAsync()
			end)
			if pageSuccess then
				pages = nextPage
				wait(1) -- Wait before processing next page
			else
				break
			end
		end
		
	until migratedCount >= maxMigrations
	
	print("GlobalSoldLeaderboard: Migration completed. Migrated " .. migratedCount .. " players")
end

-- Function to update currently online players' data in the OrderedDataStore
local function updateOnlinePlayersData()
	for _, player in pairs(Players:GetPlayers()) do
		-- Register this player for future migrations
		registerPlayer(player)
		
		local profile = ProfileStoreData.GetPlayerProfile(player)
		if profile and profile:IsActive() then
			local sold = (profile.Data.stats and profile.Data.stats.totalSold) or 0
			
			-- Update this player's data in the OrderedDataStore
			local success, err = pcall(function()
				SoldLeaderboardStore:SetAsync(tostring(player.UserId), sold)
			end)
			
			if not success then
				warn("Failed to update leaderboard data for player " .. player.Name .. ": " .. tostring(err))
			end
		end
	end
end

-- Function to get hybrid leaderboard data (OrderedDataStore + current players)
local function getHybridLeaderboardData()
	local statList = {}
	local playerMap = {} -- To avoid duplicates
	
	-- First, get data from OrderedDataStore (historical global data)
	local success, pages = pcall(function()
		return SoldLeaderboardStore:GetSortedAsync(false, ListSize)
	end)
	
	if success and pages then
		local data = pages:GetCurrentPage()
		
		for rank, entry in ipairs(data) do
			local userId = entry.key
			local sold = entry.value
			
			if sold >= MinimumRequirement then
				-- Try to get username
				local username = "Player_" .. userId
				local nameSuccess, nameResult = pcall(function()
					return Players:GetNameFromUserIdAsync(tonumber(userId))
				end)
				
				if nameSuccess and nameResult then
					username = nameResult
				end
				
				table.insert(statList, {
					key = userId,
					value = sold,
					username = username,
					source = "OrderedDataStore"
				})
				
				playerMap[userId] = true
			end
		end
	end
	
	-- Then, add currently online players (if not already in OrderedDataStore with higher value)
	for _, player in pairs(Players:GetPlayers()) do
		local profile = ProfileStoreData.GetPlayerProfile(player)
		if profile and profile:IsActive() then
			local sold = (profile.Data.stats and profile.Data.stats.totalSold) or 0
			local userId = tostring(player.UserId)
			
			if sold >= MinimumRequirement then
				-- Check if this player is already in the list
				local existingEntry = nil
				for i, entry in ipairs(statList) do
					if entry.key == userId then
						existingEntry = entry
						break
					end
				end
				
				if existingEntry then
					-- Update with the current value (more recent)
					existingEntry.value = sold
					existingEntry.username = player.Name
					existingEntry.source = "Current"
				else
					-- Add new entry
					table.insert(statList, {
						key = userId,
						value = sold,
						username = player.Name,
						source = "Current"
					})
				end
			end
		end
	end
	
	-- Sort by sold (highest first)
	table.sort(statList, function(a, b) return a.value > b.value end)
	
	-- Limit to ListSize
	local finalList = {}
	for i = 1, math.min(#statList, ListSize) do
		table.insert(finalList, statList[i])
	end
	
	print("Global Sold Leaderboard: Found", #finalList, "entries with sold >= ", MinimumRequirement)
	return finalList
end

-- Register players when they join
Players.PlayerAdded:Connect(function(player)
	registerPlayer(player)
end)

-- Run migration once when server starts  
spawn(function()
	wait(10) -- Wait for everything to initialize
	migrateRegisteredPlayers()
end)

while true do
	clear()
	
	-- First, update currently online players' data in OrderedDataStore
	updateOnlinePlayersData()
	
	-- Then get the hybrid leaderboard (combines OrderedDataStore + current players)
	local statList = getHybridLeaderboardData()
	
	-- If there are no entries, add a placeholder entry
	if #statList == 0 then
		print("No players found in leaderboard data, adding placeholder.")
		table.insert(statList, { 
			key = "DefaultEntry", 
			value = 0, 
			username = "Waiting for data...",
			isPlaceholder = true 
		})
	end

	for rank, entry in ipairs(statList) do
		if rank > ListSize then break end
		local templateClone = Template:Clone()
		templateClone.Parent = MainFrame
		templateClone.LayoutOrder = rank
		templateClone.Score.Text = tostring(abbreviate(entry.value, 1))
		
		if rank == 1 then
			templateClone.Rank.Text = "🥇"
		elseif rank == 2 then
			templateClone.Rank.Text = "🥈"
		elseif rank == 3 then
			templateClone.Rank.Text = "🥉"
		else
			templateClone.Rank.Text = "#" .. rank
		end
		
		templateClone.Username.Text = entry.username or "Unknown"
		templateClone.Name = entry.username or "Unknown"
	end
	
	wait(UpdateEvery)
end
