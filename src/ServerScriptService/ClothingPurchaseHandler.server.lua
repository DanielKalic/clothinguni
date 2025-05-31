-- ClothingPurchaseHandler (ServerScriptService)
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- XP rewards constants
local XP_FOR_CLOTHING_PURCHASE = 10

-- Wait for ProfileStore data to be ready
repeat
	wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

local ItemSoldEvent = ReplicatedStorage:WaitForChild("ItemSoldEvent")

-- Function to award XP to a player
local function awardXP(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local xp = leaderstats:FindFirstChild("XP")
		if xp then
			xp.Value = xp.Value + amount
			-- Note: XP is automatically saved to ProfileStore by LeaderstatsSetupWithLevel.server.lua
			print("Awarded " .. amount .. " XP to " .. player.Name .. " for clothing purchase (auto-saved via leaderstats sync)")
		end
	end
end

-- Function to update sales count using ProfileStore
local function updateSalesCount(assetId, assetType)
	-- Use the new sales tracking system instead of try-ons
	local success = ProfileStoreData.IncrementSales(assetId, assetType)
	
	if success then
		local newCount = ProfileStoreData.GetSalesCount(assetId, assetType)
		print("Updated sales count for asset " .. assetId .. " to " .. newCount)
	else
		warn("Failed to update sales count for asset " .. assetId)
	end
end

-- Function to try to find the seller of the clothing item using ProfileStore
local function findSeller(assetId)
	local ads = ProfileStoreData.GetAds()
	if not ads then return nil end
	
	for _, listing in pairs(ads) do
		if (listing.shirtID and listing.shirtID == tostring(assetId)) or 
		   (listing.pantsID and listing.pantsID == tostring(assetId)) then
			return listing.userId
		end
	end
	
	return nil
end

-- Function to update seller's stats using ProfileStore
local function updateSellerStats(seller, assetType)
	if not seller then return end
	
	local profile = ProfileStoreData.GetPlayerProfile(seller)
	if not profile or not profile:IsActive() then return end
	
	-- Initialize stats if they don't exist
	if not profile.Data.stats then
		profile.Data.stats = {
			totalPurchases = 0,
			totalSold = 0,
			totalSpent = 0,
			favoriteItems = {},
			shirtsSold = 0,
			pantsSold = 0
		}
	end
	
	-- Update general sold count
	profile.Data.stats.totalSold = (profile.Data.stats.totalSold or 0) + 1
	
	local leaderstats = seller:FindFirstChild("leaderstats")
	if leaderstats then
		-- Update general sold count in leaderstats
		local sold = leaderstats:FindFirstChild("Sold")
		if sold then
			sold.Value = sold.Value + 1
		end
		
		-- Update specific clothing type count
		if assetType == Enum.AssetType.Shirt then
			profile.Data.stats.shirtsSold = (profile.Data.stats.shirtsSold or 0) + 1
			
			local shirtsSold = leaderstats:FindFirstChild("ShirtsSold")
			if shirtsSold then
				shirtsSold.Value = shirtsSold.Value + 1
				
				-- Notify seller
				local message = "Shirt sold! Total: " .. shirtsSold.Value
				game.ReplicatedStorage:FindFirstChild("NotificationEvent"):FireClient(seller, message, Color3.fromRGB(0, 200, 255))
			end
		elseif assetType == Enum.AssetType.Pants then
			profile.Data.stats.pantsSold = (profile.Data.stats.pantsSold or 0) + 1
			
			local pantsSold = leaderstats:FindFirstChild("PantsSold")
			if pantsSold then
				pantsSold.Value = pantsSold.Value + 1
				
				-- Notify seller
				local message = "Pants sold! Total: " .. pantsSold.Value
				game.ReplicatedStorage:FindFirstChild("NotificationEvent"):FireClient(seller, message, Color3.fromRGB(200, 100, 255))
			end
		end
	end
end

-- Function to update buyer's stats using ProfileStore
local function updateBuyerStats(player)
	local profile = ProfileStoreData.GetPlayerProfile(player)
	if not profile or not profile:IsActive() then return end
	
	-- Initialize stats if they don't exist
	if not profile.Data.stats then
		profile.Data.stats = {
			totalPurchases = 0,
			totalSold = 0,
			totalSpent = 0,
			favoriteItems = {},
			shirtsSold = 0,
			pantsSold = 0
		}
	end
	
	-- Update purchase count
	profile.Data.stats.totalPurchases = (profile.Data.stats.totalPurchases or 0) + 1
	
	-- Update bought count in leaderstats
	local buyerLeaderstats = player:FindFirstChild("leaderstats")
	if buyerLeaderstats then
		local bought = buyerLeaderstats:FindFirstChild("Bought")
		if bought then
			bought.Value = bought.Value + 1
		end
	end
end

-- Process clothing purchases through the MarketplaceService.PromptPurchaseFinished event
-- PromptPurchaseFinished is for catalog asset purchases (clothing with Robux)
-- PromptProductPurchaseFinished is for developer product purchases (coins, crates, etc.)
MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
	if not isPurchased then return end  -- Purchase was cancelled or failed
	
	-- Check if the product is a shirt or pants
	local success, assetInfo = pcall(function()
		return MarketplaceService:GetProductInfo(assetId)
	end)
	
	if success and assetInfo and (assetInfo.AssetTypeId == Enum.AssetType.Shirt.Value or assetInfo.AssetTypeId == Enum.AssetType.Pants.Value) then
		-- Determine asset type manually since fromValue doesn't exist
		local assetType
		if assetInfo.AssetTypeId == Enum.AssetType.Shirt.Value then
			assetType = Enum.AssetType.Shirt
		elseif assetInfo.AssetTypeId == Enum.AssetType.Pants.Value then
			assetType = Enum.AssetType.Pants
		end
		
		-- Award XP to the buyer
		awardXP(player, XP_FOR_CLOTHING_PURCHASE)
		
		-- Update bought count for buyer
		updateBuyerStats(player)
		
		-- Notify buyer
		local itemTypeName = (assetType == Enum.AssetType.Shirt) and "Shirt" or "Pants"
		local message = "You purchased a " .. itemTypeName .. "!"
		game.ReplicatedStorage:FindFirstChild("NotificationEvent"):FireClient(player, message, Color3.fromRGB(255, 215, 0))
		
		-- Update daily objectives for asset purchase
		if _G.UpdateDailyObjective then
			local success, err = pcall(function()
				_G.UpdateDailyObjective(player, "buyAsset", 1)
			end)
			if not success then
				warn("DEBUG: [ClothingPurchaseHandler] Daily objective update failed:", err)
			end
		end
		
		-- Update sales count
		updateSalesCount(assetId, itemTypeName)
		
		-- Try to find the seller and award them XP
		local sellerId = findSeller(assetId)
		if sellerId then
			-- Award XP and update stats for seller if they're online
			local seller = Players:GetPlayerByUserId(sellerId)
			if seller then
				-- Award XP directly to the seller if they're online
				awardXP(seller, XP_FOR_CLOTHING_PURCHASE)
				print("Awarded XP to seller " .. seller.Name .. " for clothing sale")
				
				-- Update seller's stats
				updateSellerStats(seller, assetType)
			end
		end
	end
end)

print("ClothingPurchaseHandler initialized with ProfileStore") 