-- RenewListingHandler (ServerScriptService)
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

-- Gamepass constants
local LONGER_LISTINGS_GAMEPASS_ID = 1233852859 -- "Longer Listings" gamepass

-- Change this to your actual developer product ID
local RENEW_PRODUCT_ID = 1910484649 -- Using temporary dev product ID

-- Wait for ProfileStore data to be ready
repeat
	wait(1)
until _G.ProfileStoreData

-- Wait for PurchaseRouter to be ready
repeat
    wait(0.1)
until _G.PurchaseRouter

local ProfileStoreData = _G.ProfileStoreData
local PurchaseRouter = _G.PurchaseRouter

print("DEBUG: [RenewListingHandler] Connected to ProfileStore and PurchaseRouter")

-- Validate dev product ID on startup
local function validateDevProduct()
	-- First check if it's a game pass (which would return a number)
	local success, result = pcall(function()
		return MarketplaceService:GetProductInfo(RENEW_PRODUCT_ID)
	end)
	
	if success then
		if type(result) == "table" and result.Name then
			print("DEBUG: [Server] Dev Product ID " .. RENEW_PRODUCT_ID .. " validated successfully: " .. result.Name)
		else
			print("DEBUG: [Server] Dev Product ID " .. RENEW_PRODUCT_ID .. " exists but returned unexpected format: " .. tostring(result))
			print("DEBUG: [Server] Will attempt to use this product ID anyway")
		end
		return true
	else
		warn("DEBUG: [Server] ERROR - Failed to validate Dev Product ID " .. RENEW_PRODUCT_ID .. ": " .. tostring(result))
		warn("DEBUG: [Server] Listing renewals will NOT work until this is fixed!")
		return false
	end
end

-- Validate the dev product on startup
spawn(function()
	wait(2) -- Wait for services to initialize
	validateDevProduct()
end)

local renewListingEvent = ReplicatedStorage:FindFirstChild("RenewListingEvent")
if not renewListingEvent then
	renewListingEvent = Instance.new("RemoteEvent")
	renewListingEvent.Name = "RenewListingEvent"
	renewListingEvent.Parent = ReplicatedStorage
	print("DEBUG: [RenewListingHandler] Created RenewListingEvent RemoteEvent")
else
	print("DEBUG: [RenewListingHandler] Found existing RenewListingEvent RemoteEvent")
end

-- Create renew success event
local renewSuccessEvent = ReplicatedStorage:FindFirstChild("RenewSuccessEvent")
if not renewSuccessEvent then
	renewSuccessEvent = Instance.new("RemoteEvent")
	renewSuccessEvent.Name = "RenewSuccessEvent"
	renewSuccessEvent.Parent = ReplicatedStorage
	print("DEBUG: [RenewListingHandler] Created RenewSuccessEvent RemoteEvent")
else
	print("DEBUG: [RenewListingHandler] Found existing RenewSuccessEvent RemoteEvent")
end

-- Create renew failure event
local renewFailedEvent = ReplicatedStorage:FindFirstChild("RenewFailedEvent")
if not renewFailedEvent then
	renewFailedEvent = Instance.new("RemoteEvent")
	renewFailedEvent.Name = "RenewFailedEvent"
	renewFailedEvent.Parent = ReplicatedStorage
	print("DEBUG: [RenewListingHandler] Created RenewFailedEvent RemoteEvent")
else
	print("DEBUG: [RenewListingHandler] Found existing RenewFailedEvent RemoteEvent")
end

-- Create save name event handler
local saveNameEvent = ReplicatedStorage:FindFirstChild("SaveListingNameEvent")
if not saveNameEvent then
	saveNameEvent = Instance.new("RemoteEvent")
	saveNameEvent.Name = "SaveListingNameEvent"
	saveNameEvent.Parent = ReplicatedStorage
end

-- Function to process the renewal using ProfileStore
local function processRenewal(player, listingKey)
	-- Check if player has "Longer Listings" gamepass
	local hasLongerListings = false
	local success, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, LONGER_LISTINGS_GAMEPASS_ID)
	end)
	
	if success then
		hasLongerListings = result
	else
		warn("Failed to check Longer Listings gamepass for player " .. player.Name .. ": " .. tostring(result))
	end
	
	-- Set the renewal duration based on gamepass ownership
	local renewalDuration = hasLongerListings and 604800 or 259200 -- 1 week (604800) or 3 days (259200)
	local newExpiration = os.time() + renewalDuration

	print("DEBUG: [Server] Updating listing expiration. Player:", player.Name, "Listing:", listingKey, "New expiration:", newExpiration)

	-- Get current ads data
	local ads = ProfileStoreData.GetAds()
	if not ads or not ads[listingKey] then
		warn("Listing " .. listingKey .. " not found in ProfileStore")
		if player and player.Parent then
			renewFailedEvent:FireClient(player, listingKey)
		end
		return false
	end
	
	-- Update the listing's timestamp
	local listingData = ads[listingKey]
	listingData.timestamp = newExpiration
	
	-- Save back to ProfileStore
	local updateSuccess = ProfileStoreData.UpdateAd(listingKey, listingData)
	
	if updateSuccess then
		print("DEBUG: [Server] ProfileStore update successful!")
		print("Listing " .. listingKey .. " renewed for " .. player.Name .. " with new expiration: " .. newExpiration)
		-- Check if player is still connected before firing client event
		if player and player.Parent then
			renewSuccessEvent:FireClient(player, listingKey)
		end
		return true
	else
		print("DEBUG: [Server] ProfileStore update failed")
		warn("Failed to renew listing " .. listingKey .. " in ProfileStore")
		-- Check if player is still connected before firing client event
		if player and player.Parent then
			renewFailedEvent:FireClient(player, listingKey)
		end
		return false
	end
end

-- Handler function for renewal system purchases
local function handleRenewalPurchase(player, contextData, receiptInfo)
    print("DEBUG: [RenewListingHandler] Processing renewal purchase for", player.Name)
    
    local listingKey = contextData.listingKey
    if not listingKey then
        warn("DEBUG: [RenewListingHandler] No listing key in context")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    print("DEBUG: [RenewListingHandler] Found listing key in context:", listingKey)
    
    -- Process the renewal
    local success = processRenewal(player, listingKey)
    
    if success then
        print("DEBUG: [RenewListingHandler] Renewal processed successfully")
        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        warn("DEBUG: [RenewListingHandler] Failed to process renewal")
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

-- Marketplace purchase processing callback (legacy - replaced by PurchaseRouter)

-- Create a command to directly renew a listing (for admin use or backup)
local directRenewCommand = ReplicatedStorage:FindFirstChild("DirectRenewCommand")
if not directRenewCommand then
	directRenewCommand = Instance.new("RemoteFunction")
	directRenewCommand.Name = "DirectRenewCommand"
	directRenewCommand.Parent = ReplicatedStorage
end

-- Alternative way to handle the collision of receipt handlers
local function setupProcessReceiptHook()
	-- DISABLED: Using centralized PurchaseRouter instead
	print("DEBUG: [RenewListingHandler] ProcessReceipt disabled - using centralized PurchaseRouter")
	
	-- Store the original function if any
	local originalProcessReceipt = nil
	
	-- Try to get the original function using pcall to avoid errors
	pcall(function()
		originalProcessReceipt = MarketplaceService.ProcessReceipt
	end)
end

-- Use our safer approach to register the ProcessReceipt handler
setupProcessReceiptHook()

-- Handle direct renewal command (for admin use)
directRenewCommand.OnServerInvoke = function(player, listingKey)
	-- You can add admin check here
	if not player:GetAttribute("IsAdmin") and player.UserId ~= 52452243 then -- Allow the game creator to use this
		return false, "You don't have permission to use direct renewal"
	end
	
	print("DEBUG: [Server] Direct renewal requested by admin:", player.Name, "for listing:", listingKey)
	
	-- Check if listing exists in ProfileStore
	local ads = ProfileStoreData.GetAds()
	if not ads or not ads[listingKey] then
		print("DEBUG: [Server] Listing validation failed in direct renewal:", listingKey)
		return false, "Listing not found"
	end
	
	-- Process renewal directly
	local renewalSuccess = processRenewal(player, listingKey)
	
	-- Return result to caller
	if renewalSuccess then
		return true, "Listing renewed successfully"
	else
		return false, "Failed to renew listing"
	end
end

-- Handle renewal requests
renewListingEvent.OnServerEvent:Connect(function(player, listingKey)
	-- Make sure player is valid before accessing properties
	if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then
		warn("DEBUG: [Server] Invalid player in renewal request")
		return
	end
	
	print("DEBUG: [Server] Received renewal request from", player.Name, "for listing key:", listingKey)
	
	-- Validate the listing exists in ProfileStore
	local ads = ProfileStoreData.GetAds()
	if not ads or not ads[listingKey] then
		print("DEBUG: [Server] Listing validation failed:", listingKey, "- not found in ProfileStore")
		if player and player.Parent then
			renewFailedEvent:FireClient(player, listingKey)
		end
		return
	end
	
	local listingData = ads[listingKey]
	print("DEBUG: [Server] Listing exists:", listingKey, "Current timestamp:", listingData.timestamp)
	
	-- Set purchase context for the router
	PurchaseRouter.setPurchaseContext(player, "RENEWAL_SYSTEM", {
		listingKey = listingKey
	})
	print("DEBUG: [RenewListingHandler] Set purchase context for", player.Name, "with listing:", listingKey)
	
	-- Prompt the player to purchase the dev product
	print("DEBUG: [Server] Prompting product purchase via PurchaseRouter. Player:", player.Name, "Product ID:", RENEW_PRODUCT_ID)
	
	local promptSuccess, promptError = pcall(function()
		MarketplaceService:PromptProductPurchase(player, RENEW_PRODUCT_ID)
	end)
	
	if not promptSuccess then
		print("DEBUG: [Server] PromptProductPurchase failed:", tostring(promptError))
		PurchaseRouter.clearPurchaseContext(player)
		if player and player.Parent then
			renewFailedEvent:FireClient(player, listingKey)
		end
	else
		print("DEBUG: [Server] Purchase prompt sent successfully via PurchaseRouter")
	end
end)

print("DEBUG: [RenewListingHandler] renewListingEvent.OnServerEvent handler connected successfully")

-- Handle save name events
saveNameEvent.OnServerEvent:Connect(function(player, listingKey, newName)
	if not listingKey or not newName or newName == "" then return end
	
	-- Sanitize the name
	newName = tostring(newName)
	
	-- Get current ads data
	local ads = ProfileStoreData.GetAds()
	if not ads or not ads[listingKey] then
		warn("Failed to update listing name " .. listingKey .. ": Listing not found in ProfileStore")
		return
	end
	
	-- Update the listing's custom name
	local listingData = ads[listingKey]
	listingData.customName = newName
	
	-- Save back to ProfileStore
	local success = ProfileStoreData.UpdateAd(listingKey, listingData)
	
	if success then
		print("Listing " .. listingKey .. " name updated to: " .. newName)
	else
		warn("Failed to update listing name " .. listingKey .. " in ProfileStore")
	end
end)

-- Register with the centralized purchase router
PurchaseRouter.registerSystemHandler("RENEWAL_SYSTEM", handleRenewalPurchase)
print("DEBUG: [RenewListingHandler] Registered RENEWAL_SYSTEM handler with PurchaseRouter")

print("DEBUG: [RenewListingHandler] RenewListingHandler initialized with ProfileStore and PurchaseRouter")
