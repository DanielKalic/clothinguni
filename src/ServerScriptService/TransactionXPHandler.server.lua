-- TransactionXPHandler (ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for ProfileStore data to be ready
repeat
	wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

local AdSaleEvent = ReplicatedStorage:WaitForChild("AdSaleEvent")
local ItemSoldEvent = ReplicatedStorage:WaitForChild("ItemSoldEvent")

-- XP rewards constants:
local XP_FOR_SINGLE_AD = 10
local XP_FOR_BOTH_AD = 30
local XP_FOR_SALE = 10

local function awardXP(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local xp = leaderstats:FindFirstChild("XP")
		if xp then
			xp.Value = xp.Value + amount
			-- Note: XP is automatically saved to ProfileStore by LeaderstatsSetupWithLevel.server.lua
			print("Awarded " .. amount .. " XP to " .. player.Name .. " (auto-saved via leaderstats sync)")
		end
	end
end

-- When a player puts an ad on sale.
AdSaleEvent.OnServerEvent:Connect(function(player, hasShirt, hasPants)
	if hasShirt and hasPants then
		awardXP(player, XP_FOR_BOTH_AD)
	elseif hasShirt or hasPants then
		awardXP(player, XP_FOR_SINGLE_AD)
	end
end)

-- When an item is sold.
ItemSoldEvent.OnServerEvent:Connect(function(player)
	-- 'player' here is assumed to be the seller.
	awardXP(player, XP_FOR_SALE)
end)
