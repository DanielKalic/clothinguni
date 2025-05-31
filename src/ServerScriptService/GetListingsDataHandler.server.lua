-- GetListingsDataHandler (ServerScriptService)
-- Handles the GetListingsData RemoteFunction for the ListingsGUI My Listings section

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Wait for ProfileStore data to be ready
repeat
	wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

-- Get or create the remote function
local getListingsData = ReplicatedStorage:FindFirstChild("GetListingsData")
if not getListingsData then
	print("DEBUG: [GetListingsDataHandler] Creating new GetListingsData RemoteFunction")
	getListingsData = Instance.new("RemoteFunction")
	getListingsData.Name = "GetListingsData"
	getListingsData.Parent = ReplicatedStorage
else
	print("DEBUG: [GetListingsDataHandler] Found existing GetListingsData RemoteFunction")
end

-- Function to get active listings for a player using ProfileStore
local function getPlayerListings(player)
	local userId = player.UserId
	print("DEBUG: [GetListingsDataHandler] Fetching listings for player:", player.Name, "userId:", userId)
	
	local ads = ProfileStoreData.GetAds()
	if not ads then
		print("DEBUG: [GetListingsDataHandler] No ads data found in ProfileStore")
		return {}
	end
	
	local playerListings = {}
	local currentTime = os.time()
	
	for listingId, listingData in pairs(ads) do
		-- Check if this listing belongs to the requesting player
		local adUserId = tonumber(listingData.userId) or listingData.userId
		if tostring(adUserId) == tostring(userId) then
			-- For player's own listings, include both active and expired (for renew functionality)
			local timestamp = tonumber(listingData.timestamp) or currentTime
			print("DEBUG: [GetListingsDataHandler] Found player listing:", listingId, "expires:", timestamp, "current:", currentTime)
			
			-- Add all player listings (expired ones can show renew button)
			playerListings[listingId] = listingData
			
			if currentTime < timestamp then
				print("DEBUG: [GetListingsDataHandler] Added active listing:", listingId)
			else
				print("DEBUG: [GetListingsDataHandler] Added expired listing for renewal:", listingId)
			end
		end
	end
	
	local count = 0
	for _ in pairs(playerListings) do
		count = count + 1
	end
	
	print("DEBUG: [GetListingsDataHandler] Found", count, "active listings for", player.Name)
	return playerListings
end

-- Handle remote function calls
getListingsData.OnServerInvoke = function(player, getMyListingsOnly)
	print("DEBUG: [GetListingsDataHandler] Request received from player:", player.Name, "getMyListingsOnly:", getMyListingsOnly)
	
	if getMyListingsOnly then
		-- Return only the player's listings (for My Listings tab)
		local listings = getPlayerListings(player)
		print("DEBUG: [GetListingsDataHandler] Returning player listings to", player.Name)
		return listings
	else
		-- Return all active listings (for Shop tab)
		print("DEBUG: [GetListingsDataHandler] Returning all listings to", player.Name)
		local ads = ProfileStoreData.GetAds()
		if not ads then
			print("DEBUG: [GetListingsDataHandler] No ads data found in ProfileStore")
			return {}
		end
		
		local activeListings = {}
		local currentTime = os.time()
		
		for listingId, listingData in pairs(ads) do
			-- Check if listing hasn't expired
			local timestamp = tonumber(listingData.timestamp) or currentTime
			if currentTime < timestamp then
				activeListings[listingId] = listingData
			end
		end
		
		local count = 0
		for _ in pairs(activeListings) do
			count = count + 1
		end
		
		print("DEBUG: [GetListingsDataHandler] Found", count, "active listings total")
		return activeListings
	end
end

print("GetListingsDataHandler initialized with ProfileStore") 