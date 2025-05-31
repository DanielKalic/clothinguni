-- ListingsDataHandler (ServerScriptService)
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for ProfileStore data to be ready
repeat
	wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

-- Create the remote event for fetching listings
local fetchListingsEvent = ReplicatedStorage:FindFirstChild("FetchListingsEvent")
if not fetchListingsEvent then
	fetchListingsEvent = Instance.new("RemoteEvent")
	fetchListingsEvent.Name = "FetchListingsEvent"
	fetchListingsEvent.Parent = ReplicatedStorage
end

-- Function to fetch listings from ProfileStore
local function fetchListings()
	local ads = ProfileStoreData.GetAds()
	if ads then
		print("Successfully fetched listings from ProfileStore")
		return ads
	else
		warn("Failed to fetch listings from ProfileStore")
		return {}
	end
end

-- Handle client requests for listings data
fetchListingsEvent.OnServerEvent:Connect(function(player)
	local listings = fetchListings()
	fetchListingsEvent:FireClient(player, listings)
end)

print("ListingsDataHandler initialized with ProfileStore")
