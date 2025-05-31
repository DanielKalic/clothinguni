-- LeaderstatsSetupWithLevel (ServerScriptService)
-- Updated to work with ProfileStore instead of Firebase
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Wait for ProfileStore data to be ready
repeat
	wait(0.1)
until _G.ProfileStoreData and _G.ProfileStoreData.IsReady

local ProfileStoreData = _G.ProfileStoreData

local function xpRequiredForLevel(level)
	return level * 100
end

local function updateLevel(player)
	local profile = ProfileStoreData.GetPlayerProfile(player)
	if not profile or not profile:IsActive() then return end
	
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	
	local xp = leaderstats:FindFirstChild("XP")
	local level = leaderstats:FindFirstChild("Level")
	
	if xp and level then
		local req = xpRequiredForLevel(level.Value)
		while xp.Value >= req do
			xp.Value = xp.Value - req
			level.Value = level.Value + 1
			req = xpRequiredForLevel(level.Value)
			
			-- Update ProfileStore data
			profile.Data.xp = xp.Value
			profile.Data.level = level.Value
		end
	end
end

local function setupLeaderstatsTracking(player)
	print("DEBUG: [LeaderstatsSetup] Setting up leaderstats tracking for", player.Name)
	
	-- Wait for leaderstats to be created by ProfileStore
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if not leaderstats then
		warn("Leaderstats not found for player:", player.Name)
		return
	end
	
	local profile = ProfileStoreData.GetPlayerProfile(player)
	if not profile then
		warn("Profile not found for player:", player.Name)
		return
	end
	
	-- Debug: Show what XP data we loaded from ProfileStore
	local storedXP = profile.Data.xp or 0
	local storedLevel = profile.Data.level or 1
	local storedCoins = profile.Data.coins or 0
	print("DEBUG: [LeaderstatsSetup] Loaded from ProfileStore for", player.Name, "- XP:", storedXP, "Level:", storedLevel, "Coins:", storedCoins)
	
	-- Add additional stats that ProfileStore doesn't create by default
	local bought = leaderstats:FindFirstChild("Bought")
	if not bought then
		bought = Instance.new("IntValue")
		bought.Name = "Bought"
		bought.Value = profile.Data.stats and profile.Data.stats.totalPurchases or 0
		bought.Parent = leaderstats
	end

	local sold = leaderstats:FindFirstChild("Sold")
	if not sold then
		sold = Instance.new("IntValue")
		sold.Name = "Sold"
		sold.Value = profile.Data.stats and profile.Data.stats.totalSold or 0
		sold.Parent = leaderstats
	end
	
	local shirtsSold = leaderstats:FindFirstChild("ShirtsSold")
	if not shirtsSold then
		shirtsSold = Instance.new("IntValue")
		shirtsSold.Name = "ShirtsSold"
		shirtsSold.Value = profile.Data.stats and profile.Data.stats.shirtsSold or 0
		shirtsSold.Parent = leaderstats
	end
	
	local pantsSold = leaderstats:FindFirstChild("PantsSold")
	if not pantsSold then
		pantsSold = Instance.new("IntValue")
		pantsSold.Name = "PantsSold"
		pantsSold.Value = profile.Data.stats and profile.Data.stats.pantsSold or 0
		pantsSold.Parent = leaderstats
	end
	
	local xp = leaderstats:FindFirstChild("XP")
	if not xp then
		xp = Instance.new("IntValue")
		xp.Name = "XP"
		xp.Value = profile.Data.xp or 0
		xp.Parent = leaderstats
	end

	local function onStatChanged()
		print("DEBUG: [LeaderstatsSetup] onStatChanged triggered for", player.Name)
		
		if not profile:IsActive() then 
			warn("DEBUG: [LeaderstatsSetup] Profile not active for", player.Name)
			return 
		end
		
		print("DEBUG: [LeaderstatsSetup] Profile is active for", player.Name)
		
		updateLevel(player)
		
		-- Debug: Log current values before saving
		local currentXP = xp.Value
		local currentCoins = leaderstats.Coins.Value
		local currentLevel = leaderstats.Level.Value
		
		print("DEBUG: [LeaderstatsSetup] Saving to ProfileStore for", player.Name, "- XP:", currentXP, "Coins:", currentCoins, "Level:", currentLevel)
		
		-- Update ProfileStore data
		if profile.Data.stats then
			profile.Data.stats.totalPurchases = bought.Value
			profile.Data.stats.totalSold = sold.Value
			profile.Data.stats.shirtsSold = shirtsSold.Value
			profile.Data.stats.pantsSold = pantsSold.Value
		else
			profile.Data.stats = {
				totalPurchases = bought.Value,
				totalSold = sold.Value,
				shirtsSold = shirtsSold.Value,
				pantsSold = pantsSold.Value,
				totalSpent = profile.Data.stats and profile.Data.stats.totalSpent or 0,
				favoriteItems = profile.Data.stats and profile.Data.stats.favoriteItems or {}
			}
		end
		
		profile.Data.xp = xp.Value
		profile.Data.level = leaderstats.Level.Value
		profile.Data.coins = leaderstats.Coins.Value
		
		print("DEBUG: [LeaderstatsSetup] Successfully saved to ProfileStore for", player.Name, "- XP:", profile.Data.xp, "Level:", profile.Data.level, "Coins:", profile.Data.coins)
	end

	-- Connect to stat changes
	leaderstats.Level.Changed:Connect(onStatChanged)
	leaderstats.Coins.Changed:Connect(onStatChanged)
	xp.Changed:Connect(function()
		print("DEBUG: [LeaderstatsSetup] XP Changed detected for", player.Name, "- New value:", xp.Value)
		onStatChanged()
	end)
	bought.Changed:Connect(onStatChanged)
	sold.Changed:Connect(onStatChanged)
	shirtsSold.Changed:Connect(onStatChanged)
	pantsSold.Changed:Connect(onStatChanged)
	
	print("Leaderstats tracking setup complete for:", player.Name)
	print("DEBUG: [LeaderstatsSetup] Connected XP change listener for", player.Name)
end

Players.PlayerAdded:Connect(function(player)
	print("DEBUG: [LeaderstatsSetup] Player", player.Name, "joined, waiting for ProfileStore data...")
	
	-- Wait for ProfileStore to fully load the player's data
	local maxWait = 30 -- Maximum 30 seconds
	local waitTime = 0
	local stepTime = 0.1
	
	while waitTime < maxWait do
		-- Check if player has the PlayerDataLoaded attribute (set by ProfileStore)
		if player:GetAttribute("PlayerDataLoaded") then
			print("DEBUG: [LeaderstatsSetup] PlayerDataLoaded attribute found for", player.Name)
			break
		end
		
		-- Also check if ProfileStore has a profile for this player
		local profile = ProfileStoreData.GetPlayerProfile(player)
		if profile and profile:IsActive() then
			print("DEBUG: [LeaderstatsSetup] Active profile found for", player.Name)
			break
		end
		
		wait(stepTime)
		waitTime = waitTime + stepTime
	end
	
	if waitTime >= maxWait then
		warn("DEBUG: [LeaderstatsSetup] Timeout waiting for ProfileStore data for", player.Name)
		return
	end
	
	-- Add additional delay to ensure leaderstats are fully created
	wait(1)
	
	print("DEBUG: [LeaderstatsSetup] Starting leaderstats tracking setup for", player.Name)
	setupLeaderstatsTracking(player)
end)

-- Handle players that are already in the game when this script loads
print("DEBUG: [LeaderstatsSetup] Checking for existing players...")
for _, player in pairs(Players:GetPlayers()) do
	print("DEBUG: [LeaderstatsSetup] Found existing player:", player.Name)
	spawn(function()
		print("DEBUG: [LeaderstatsSetup] Setting up existing player", player.Name, "waiting for ProfileStore data...")
		
		-- Wait for ProfileStore to fully load the player's data
		local maxWait = 30 -- Maximum 30 seconds
		local waitTime = 0
		local stepTime = 0.1
		
		while waitTime < maxWait do
			-- Check if player has the PlayerDataLoaded attribute (set by ProfileStore)
			if player:GetAttribute("PlayerDataLoaded") then
				print("DEBUG: [LeaderstatsSetup] PlayerDataLoaded attribute found for existing player", player.Name)
				break
			end
			
			-- Also check if ProfileStore has a profile for this player
			local profile = ProfileStoreData.GetPlayerProfile(player)
			if profile and profile:IsActive() then
				print("DEBUG: [LeaderstatsSetup] Active profile found for existing player", player.Name)
				break
			end
			
			wait(stepTime)
			waitTime = waitTime + stepTime
		end
		
		if waitTime >= maxWait then
			warn("DEBUG: [LeaderstatsSetup] Timeout waiting for ProfileStore data for existing player", player.Name)
			return
		end
		
		-- Add additional delay to ensure leaderstats are fully created
		wait(1)
		
		print("DEBUG: [LeaderstatsSetup] Starting leaderstats tracking setup for existing player", player.Name)
		setupLeaderstatsTracking(player)
	end)
end

print("LeaderstatsSetupWithLevel: Updated for ProfileStore")
