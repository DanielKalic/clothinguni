-- RemoveListingHandler (ServerScriptService)
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for ProfileStore data to be ready
repeat
	wait(1)
until _G.ProfileStoreData

local ProfileStoreData = _G.ProfileStoreData

local removeListingEvent = ReplicatedStorage:FindFirstChild("RemoveListingEvent")
if not removeListingEvent then
	removeListingEvent = Instance.new("RemoteEvent")
	removeListingEvent.Name = "RemoveListingEvent"
	removeListingEvent.Parent = ReplicatedStorage
end

removeListingEvent.OnServerEvent:Connect(function(player, listingKey)
	local success = ProfileStoreData.RemoveAd(listingKey)
	
	if success then
		print("Listing " .. listingKey .. " removed from ProfileStore by " .. player.Name)
	else
		warn("Failed to remove listing " .. listingKey .. " from ProfileStore")
	end
end)
