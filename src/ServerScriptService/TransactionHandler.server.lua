local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

-- Wait for ProfileStore data to be ready
repeat
	wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TransactionEvent = ReplicatedStorage:WaitForChild("TransactionEvent")

-- Function to check if player owns VIP gamepass
local function hasVIPGamepass(userId)
	local success, ownsGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, VIP_GAMEPASS_ID)
	end)
	return success and ownsGamepass
end

-- Helper function: Updates the stats for a given userId using ProfileStore
local function updateStatsForUser(userId, coinsToAdd, boughtIncrement, soldIncrement)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		-- Player is online, update through ProfileStore
		local profile = ProfileStoreData.GetPlayerProfile(player)
		if profile and profile:IsActive() then
			-- Update coins
			profile.Data.coins = (profile.Data.coins or 0) + coinsToAdd
			
			-- Update stats
			if not profile.Data.stats then
				profile.Data.stats = {
					totalPurchases = 0,
					totalSold = 0,
					totalSpent = 0,
					favoriteItems = {}
				}
			end
			
			if boughtIncrement > 0 then
				profile.Data.stats.totalPurchases = (profile.Data.stats.totalPurchases or 0) + boughtIncrement
			end
			
			if soldIncrement > 0 then
				profile.Data.stats.totalSold = (profile.Data.stats.totalSold or 0) + soldIncrement
			end
			
			-- Update leaderstats
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				if leaderstats:FindFirstChild("Coins") then
					leaderstats.Coins.Value = profile.Data.coins
				end
				if leaderstats:FindFirstChild("Bought") and boughtIncrement > 0 then
					leaderstats.Bought.Value = (leaderstats.Bought.Value or 0) + boughtIncrement
				end
				if leaderstats:FindFirstChild("Sold") and soldIncrement > 0 then
					leaderstats.Sold.Value = (leaderstats.Sold.Value or 0) + soldIncrement
				end
			end
			
			return true
		end
	end
	
	-- Player is offline - we can't update their ProfileStore data
	-- ProfileStore only works for online players
	warn("Cannot update stats for offline player " .. userId .. " - ProfileStore requires player to be online")
	return false
end

-- Adjust stats for both buyer and seller.
local function adjustStats(buyerId, sellerId)
	-- Check VIP status for both buyer and seller
	local buyerIsVIP = hasVIPGamepass(buyerId)
	local sellerIsVIP = hasVIPGamepass(sellerId)
	
	-- Calculate coin amounts with VIP multiplier
	local buyerCoins = buyerIsVIP and 10 or 5  -- VIP gets 10 coins, regular gets 5
	local sellerCoins = sellerIsVIP and 20 or 10  -- VIP gets 20 coins, regular gets 10
	
	-- Process buyer: +5/10 Coins (VIP 2x), +1 Bought
	local buyerSuccess = updateStatsForUser(buyerId, buyerCoins, 1, 0)
	if buyerSuccess then
		local buyer = Players:GetPlayerByUserId(buyerId)
		if buyer and buyerIsVIP then
			local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
			if notificationEvent then
				notificationEvent:FireClient(buyer, "+" .. buyerCoins .. " Coins! (VIP 2x)", Color3.fromRGB(255, 215, 0))
			end
		end
	end

	-- Process seller: +10/20 Coins (VIP 2x), +1 Sold
	local sellerSuccess = updateStatsForUser(sellerId, sellerCoins, 0, 1)
	if sellerSuccess then
		local seller = Players:GetPlayerByUserId(sellerId)
		if seller and sellerIsVIP then
			local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
			if notificationEvent then
				notificationEvent:FireClient(seller, "+" .. sellerCoins .. " Coins! (VIP 2x)", Color3.fromRGB(255, 215, 0))
			end
		end
	end
end

-- Listen for transaction events.
TransactionEvent.OnServerEvent:Connect(function(player, buyerId, sellerId)
	adjustStats(buyerId, sellerId)
end)
