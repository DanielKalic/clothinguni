-- DailyBonusXP (ServerScriptService)
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

print("DailyBonusXP: System starting, waiting 10 seconds for ProfileStore initialization...")

-- Delay initialization to reduce server load during startup
wait(10)

print("DailyBonusXP: Starting after ProfileStore initialization delay...")

-- Settings
local DAILY_BONUS_XP = 20
local TIME_BETWEEN_BONUSES = 86400 -- 24 hours in seconds

-- Wait for ProfileStore data to be ready
repeat
    wait(0.1)
until _G.ProfileStoreData and _G.ProfileStoreData.IsReady

local ProfileStoreData = _G.ProfileStoreData

-- Create/get the remote events and functions
local updateBonusTimerEvent = ReplicatedStorage:FindFirstChild("UpdateBonusTimerEvent")
if not updateBonusTimerEvent then
    updateBonusTimerEvent = Instance.new("RemoteEvent")
    updateBonusTimerEvent.Name = "UpdateBonusTimerEvent"
    updateBonusTimerEvent.Parent = ReplicatedStorage
end

-- Create remote function for immediate data requests
local requestTimerDataFunc = ReplicatedStorage:FindFirstChild("RequestTimerDataFunc")
if not requestTimerDataFunc then
    requestTimerDataFunc = Instance.new("RemoteFunction")
    requestTimerDataFunc.Name = "RequestTimerDataFunc"
    requestTimerDataFunc.Parent = ReplicatedStorage
end

-- Create a memory cache to track when bonuses were awarded in the current session
local lastBonusCache = {}
-- Track which players already received a notification this session
local bonusNotificationSent = {}

-- Function to award XP to a player
local function awardXP(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local xp = leaderstats:FindFirstChild("XP")
		if xp then
			xp.Value = xp.Value + amount
			
			-- Also update ProfileStore XP
			ProfileStoreData.UpdateXP(player, xp.Value)
			
			print("Awarded daily bonus of " .. amount .. " XP to " .. player.Name)
			
			-- Send notification to player only if not already sent
			local userId = player.UserId
			if not bonusNotificationSent[userId] then
				local message = "Daily Bonus: +" .. amount .. " XP"
				local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
				if notificationEvent then
					notificationEvent:FireClient(player, message, Color3.fromRGB(0, 255, 0))
					bonusNotificationSent[userId] = true
				end
			end
			
			return true
		else
			warn("DailyBonus: No XP value found in leaderstats for " .. player.Name)
		end
	else
		warn("DailyBonus: No leaderstats found for " .. player.Name)
	end
	return false
end

-- Get the time of the last bonus for a player using ProfileStore
local function getLastBonusTime(player)
    if not player or not player.Parent then
        warn("DailyBonus: Invalid player in getLastBonusTime")
        return 0
    end
    
    local success, result = pcall(function()
        return ProfileStoreData.GetLastDailyBonus(player)
    end)
    
    if success then
        return result or 0
    else
        warn("DailyBonus: Failed to get last bonus time for " .. player.Name .. ": " .. tostring(result))
        return 0
    end
end

-- Set the time of the last bonus for a player using ProfileStore
local function setLastBonusTime(player, timestamp)
    if not player or not player.Parent then
        warn("DailyBonus: Invalid player in setLastBonusTime")
        return false
    end
    
    local success, result = pcall(function()
        return ProfileStoreData.SetLastDailyBonus(player, timestamp)
    end)
    
    if success and result then
        -- Also update memory cache
        lastBonusCache[player.UserId] = timestamp
        return true
    else
        warn("Failed to update last bonus time for user " .. player.UserId .. ": " .. tostring(result))
        return false
    end
end

-- Calculate time left for a player's next bonus
local function getTimeLeftForPlayer(player)
    local currentTime = os.time()
    local userId = player.UserId
    
    -- Check memory cache first (faster)
    local cachedTime = lastBonusCache[userId]
    if cachedTime then
        local timeElapsed = currentTime - cachedTime
        local timeLeft = math.max(0, TIME_BETWEEN_BONUSES - timeElapsed)
        return timeLeft
    end
    
    -- If not in cache, check ProfileStore
    local lastBonusTime = getLastBonusTime(player)
    local timeElapsed = currentTime - lastBonusTime
    
    -- Store in cache for future quick access
    lastBonusCache[userId] = lastBonusTime
    
    local timeLeft = math.max(0, TIME_BETWEEN_BONUSES - timeElapsed)
    return timeLeft
end

-- Check if a player should receive a daily bonus and update their timer
local function checkDailyBonus(player)
	local userId = player.UserId
	local currentTime = os.time()
	
	-- First check memory cache
	local cachedTime = lastBonusCache[userId]
	if cachedTime then
		local timeElapsed = currentTime - cachedTime
		local timeLeft = math.max(0, TIME_BETWEEN_BONUSES - timeElapsed)
		
		-- Update client timer
		updateBonusTimerEvent:FireClient(player, timeLeft)
		
		-- If they already got a bonus in this session, return early
		if timeElapsed < TIME_BETWEEN_BONUSES then
			return false
		end
	end
	
	-- If not in cache or enough time has passed, check ProfileStore
	local lastBonusTime = getLastBonusTime(player)
	
	-- Handle new players (lastBonusTime = 0 means never claimed)
	if lastBonusTime == 0 then
		print("New player detected - awarding first daily bonus to " .. player.Name)
		-- Award bonus immediately for new players
		if awardXP(player, DAILY_BONUS_XP) then
			-- Update the last bonus time
			local success = setLastBonusTime(player, currentTime)
			if success then
				-- Update client with new timer (full 24 hours)
				updateBonusTimerEvent:FireClient(player, TIME_BETWEEN_BONUSES)
				return true
			else
				warn("Failed to save last bonus time for new player " .. player.Name)
			end
		else
			warn("Failed to award XP to new player " .. player.Name)
		end
		return false
	end
	
	-- Calculate time left until next bonus
	local timeElapsed = currentTime - lastBonusTime
	local timeLeft = math.max(0, TIME_BETWEEN_BONUSES - timeElapsed)
	
	-- Update the client with the time left
	updateBonusTimerEvent:FireClient(player, timeLeft)
	
	-- If enough time has passed since the last bonus
	if timeElapsed >= TIME_BETWEEN_BONUSES then
		print("Awarding daily bonus to " .. player.Name .. " (24+ hours elapsed)")
		-- Award the bonus
		if awardXP(player, DAILY_BONUS_XP) then
			-- Update the last bonus time
			local success = setLastBonusTime(player, currentTime)
			if success then
				-- Update client with new timer (full 24 hours)
				updateBonusTimerEvent:FireClient(player, TIME_BETWEEN_BONUSES)
				return true
			else
				warn("Failed to save last bonus time for " .. player.Name)
			end
		else
			warn("Failed to award XP to " .. player.Name)
		end
	end
	
	return false
end

-- Handle immediate timer data requests from client
requestTimerDataFunc.OnServerInvoke = function(player)
    local timeLeft = getTimeLeftForPlayer(player)
    return timeLeft
end

-- Check daily bonus for newly joined players
Players.PlayerAdded:Connect(function(player)
	-- Wait for ProfileStore to load player data with reduced wait time
	repeat
		wait(0.1)
	until player:GetAttribute("PlayerDataLoaded")
	
	-- Add a small delay to ensure profile is fully ready
	wait(0.5)
	
	print("Checking daily bonus for newly joined player: " .. player.Name)
	checkDailyBonus(player)
end)

-- Clear notification status when player leaves
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	if bonusNotificationSent[userId] then
		bonusNotificationSent[userId] = nil
	end
end)

-- Create a loop to update client timers periodically
spawn(function()
	while true do
		wait(60) -- Update every minute
		for _, player in ipairs(Players:GetPlayers()) do
			local userId = player.UserId
			local currentTime = os.time()
			
			-- Check memory cache first
			local cachedTime = lastBonusCache[userId]
			if cachedTime then
				local timeElapsed = currentTime - cachedTime
				local timeLeft = math.max(0, TIME_BETWEEN_BONUSES - timeElapsed)
				
				-- Update client timer
				updateBonusTimerEvent:FireClient(player, timeLeft)
			else
				-- If not in cache, get from ProfileStore
				local lastBonusTime = getLastBonusTime(player)
				
				-- Calculate time left until next bonus
				local timeElapsed = currentTime - lastBonusTime
				local timeLeft = math.max(0, TIME_BETWEEN_BONUSES - timeElapsed)
				
				-- Update the client with the time left
				updateBonusTimerEvent:FireClient(player, timeLeft)
				
				-- Store in cache
				lastBonusCache[userId] = lastBonusTime
			end
		end
	end
end)

print("DailyBonusXP system initialized")

-- Handle players who joined before this script loaded
for _, player in pairs(Players:GetPlayers()) do
	-- Check if player data is already loaded
	if player:GetAttribute("PlayerDataLoaded") then
		spawn(function()
			wait(0.5) -- Small delay to ensure everything is ready
			checkDailyBonus(player)
		end)
	end
end
