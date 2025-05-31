local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getOrCreateRemoteEvent(name)
	local re = ReplicatedStorage:FindFirstChild(name)
	if not re then
		re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = ReplicatedStorage
	end
	return re
end

local AdSaleEvent = getOrCreateRemoteEvent("AdSaleEvent")
local TransactionEvent = getOrCreateRemoteEvent("TransactionEvent")
local ItemSoldEvent = getOrCreateRemoteEvent("ItemSoldEvent")
local NotificationEvent = getOrCreateRemoteEvent("NotificationEvent")
