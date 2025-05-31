-- Modern ListingsGUI
-- Wrap the entire script in error handling to prevent breaking the game
local success, errorMessage = pcall(function()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Make global service references to ensure availability everywhere in the script
_G.CachedServices = _G.CachedServices or {}
_G.CachedServices.Players = Players
_G.CachedServices.TweenService = TweenService
_G.CachedServices.ReplicatedStorage = ReplicatedStorage
_G.CachedServices.RunService = RunService

-- Safe service getter function to prevent nil errors
local function getService(serviceName)
    if _G.CachedServices and _G.CachedServices[serviceName] then
        return _G.CachedServices[serviceName]
    end
    
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    
    if success and service then
        -- Cache for future use
        _G.CachedServices = _G.CachedServices or {}
        _G.CachedServices[serviceName] = service
        return service
    end
    
    warn("Failed to get service: " .. serviceName)
    return nil
end

-- Add debug mode to track UI updates
local UI_DEBUG = false
local function debugPrint(...)
    if UI_DEBUG then
        print("[PetsUI]", ...)
    end
end

-- Function to show notifications
local function showNotification(message, color)
    -- If color is a string (like "success", "warning", "error"), convert it to Color3
    if type(color) == "string" then
        if color == "success" then
            color = Color3.fromRGB(60, 200, 60) -- Green
        elseif color == "warning" then
            color = Color3.fromRGB(240, 180, 60) -- Orange/Yellow
        elseif color == "error" then
            color = Color3.fromRGB(200, 60, 60) -- Red
        else
            color = Color3.fromRGB(60, 120, 200) -- Default blue for info
        end
    end
    
    -- Use a default color if none provided
    color = color or Color3.fromRGB(60, 200, 60)
    
    -- Create notification frame
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 300, 0, 60)
    notification.Position = UDim2.new(0.5, 0, 0, -70) -- Start off-screen, centered
    notification.AnchorPoint = Vector2.new(0.5, 0.5)
    notification.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    notification.BorderSizePixel = 0
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = notification
    
    -- Add message text
    local messageText = Instance.new("TextLabel")
    messageText.Name = "Message"
    messageText.Size = UDim2.new(1, -20, 1, 0)
    messageText.Position = UDim2.new(0, 10, 0, 0)
    messageText.BackgroundTransparency = 1
    messageText.Text = message
    messageText.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageText.TextSize = 16
    messageText.Font = Enum.Font.GothamSemibold
    messageText.TextWrapped = true
    messageText.Parent = notification
    
    -- Add colored bar on left side
    local colorBar = Instance.new("Frame")
    colorBar.Name = "ColorBar"
    colorBar.Size = UDim2.new(0, 5, 1, -10)
    colorBar.Position = UDim2.new(0, 0, 0, 5)
    colorBar.BackgroundColor3 = color
    colorBar.BorderSizePixel = 0
    colorBar.Parent = notification
    
    -- Add rounded corners to color bar
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 2)
    barCorner.Parent = colorBar
    
    -- Create temporary GUI for notification
    local notificationGui = Instance.new("ScreenGui")
    notificationGui.Name = "NotificationGui_" .. os.time() .. math.random(1000, 9999)
    notificationGui.ResetOnSpawn = false
    notificationGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    notification.Parent = notificationGui
    
    -- Animate notification in
    local tweenIn = TweenService:Create(
        notification,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0.1, 30)}
    )
    
    tweenIn:Play()
    
    -- Schedule removal after 4 seconds
    delay(3, function()
        local tweenOut = TweenService:Create(
            notification,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, 0, 0, -70)}
        )
        
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            notificationGui:Destroy()
        end)
    end)
end

-- Load the GUIManager module
local GUIManager = require(ReplicatedStorage:WaitForChild("GUIManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get the clothing template function
local getClothingTemplateFunc = ReplicatedStorage:WaitForChild("GetClothingTemplateFunc", 10)

-- Remove any existing GUI with same name
local existingGui = playerGui:FindFirstChild("ListingsGUI")
if existingGui and existingGui:IsA("ScreenGui") then
    existingGui:Destroy()
end

-- Create or get the required remote events
local getListingsData = ReplicatedStorage:WaitForChild("GetListingsData", 10)
if not getListingsData then
    warn("DEBUG: [ListingsGUI] GetListingsData RemoteFunction not found after 10 seconds - creating fallback")
    getListingsData = Instance.new("RemoteFunction")
    getListingsData.Name = "GetListingsData"
    getListingsData.Parent = ReplicatedStorage
else
    print("DEBUG: [ListingsGUI] Found GetListingsData RemoteFunction")
end

local openAssetStatsEvent = ReplicatedStorage:FindFirstChild("OpenAssetStatsEvent")
if not openAssetStatsEvent then
    print("DEBUG: [ListingsGUI] Waiting for OpenAssetStatsEvent from server...")
    openAssetStatsEvent = ReplicatedStorage:WaitForChild("OpenAssetStatsEvent", 10)
    if openAssetStatsEvent then
        print("DEBUG: [ListingsGUI] Found OpenAssetStatsEvent from server")
    else
        warn("DEBUG: [ListingsGUI] OpenAssetStatsEvent not found after 10 seconds - creating fallback")
        openAssetStatsEvent = Instance.new("RemoteEvent")
        openAssetStatsEvent.Name = "OpenAssetStatsEvent"
        openAssetStatsEvent.Parent = ReplicatedStorage
    end
else
    print("DEBUG: [ListingsGUI] Found existing OpenAssetStatsEvent")
end

local removeListingEvent = ReplicatedStorage:FindFirstChild("RemoveListingEvent")
if not removeListingEvent then
    removeListingEvent = Instance.new("RemoteEvent")
    removeListingEvent.Name = "RemoveListingEvent"
    removeListingEvent.Parent = ReplicatedStorage
end

local renewListingEvent = ReplicatedStorage:WaitForChild("RenewListingEvent")
print("DEBUG: [Client] Found RenewListingEvent from server")

local renewSuccessEvent = ReplicatedStorage:WaitForChild("RenewSuccessEvent")
local renewFailedEvent = ReplicatedStorage:WaitForChild("RenewFailedEvent")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ListingsGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Define allListings variable to store all listings data
local allListings = {}
local lastDataFetch = 0
local DATA_CACHE_DURATION = 30 -- Cache server data for 30 seconds

-- Forward declaration of GUI elements
local listingsFrame

-- Forward declaration of functions to prevent "attempt to call a nil value" errors
local updateListings
local createListing
local showCrateContents
local showCoinPurchaseDialog
local showConfirmationDialog

-- Function to format date for display
local function formatDate(timestamp)
    if not timestamp then return "Unknown" end
    
    local dateTime = os.date("*t", timestamp)
    return dateTime.month .. "/" .. dateTime.day .. "/" .. dateTime.year
end

-- Variable to track if GUI is fully initialized
local isGUIInitialized = false

-- Function to update listings (properly defined before it's called)
local function updateListings(searchQuery, forceRefresh)
    -- Clear existing listings
    for _, child in ipairs(listingsFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Smart caching: only fetch from server if cache is old or forced refresh
    local currentTime = tick()
    local needsRefresh = forceRefresh or 
                        (currentTime - lastDataFetch) > DATA_CACHE_DURATION or 
                        (#allListings == 0 and not searchQuery)
    
    if needsRefresh then
        print("DEBUG: [ListingsGUI] Fetching fresh data from server")
        local success, result = pcall(function()
            -- Pass parameter to indicate which type of listings we want
            local getMyListingsOnly = (selectedTab == "My Listings")
            print("DEBUG: [ListingsGUI] Calling server with getMyListingsOnly:", getMyListingsOnly, "for tab:", selectedTab)
            return getListingsData:InvokeServer(getMyListingsOnly)
        end)
        
        if success and result then
            local count = 0
            for _ in pairs(result) do count = count + 1 end
            print("DEBUG: [ListingsGUI] Server returned", count, "listings")
            allListings = result
            lastDataFetch = currentTime
        else
            print("DEBUG: [ListingsGUI] Failed to fetch data from server, using cached data")
            -- Keep using cached data if server call fails
        end
    else
        print("DEBUG: [ListingsGUI] Using cached data (age: " .. math.floor(currentTime - lastDataFetch) .. "s)")
    end
    
    local listings = {}
    
    -- If search query provided, filter listings
    if searchQuery and searchQuery ~= "" then
        print("DEBUG: [Search] Searching for:", searchQuery)
        print("DEBUG: [Search] Total allListings count:", #allListings == 0 and "0 (using pairs)" or #allListings)
        
        local totalCount = 0
        for _ in pairs(allListings) do totalCount = totalCount + 1 end
        print("DEBUG: [Search] Total allListings (pairs):", totalCount)
        
        for listingId, ad in pairs(allListings) do
            -- Check for custom name first (might be stored under various field names)
            local customName = ad.customName or ad.name or ad.title or ad.displayName or ""
            
            -- Debug: Show all available fields to see if custom name appears after editing
            print("DEBUG: [Search] All fields for listing", listingId, ":")
            for key, value in pairs(ad) do
                print("  ", key, "=", value)
            end
            
            -- Generate the display names that are actually shown in the UI
            local shirtID = ad.shirtID or ad.shirt or ""
            local pantsID = ad.pantsID or ad.pants or ""
            
            local searchableNames = {}
            
            -- If there's a custom name, use it as the primary search target
            if customName ~= "" then
                table.insert(searchableNames, customName)
            else
                -- Fall back to generated names if no custom name
                if shirtID ~= "" and shirtID ~= "None" then
                    table.insert(searchableNames, "Shirt #" .. shirtID)
                end
                
                if pantsID ~= "" and pantsID ~= "None" then
                    table.insert(searchableNames, "Pants #" .. pantsID)
                end
            end
            
            -- Also add generated names as additional search targets (for ID searches)
            if shirtID ~= "" and shirtID ~= "None" then
                table.insert(searchableNames, "Shirt #" .. shirtID)
                table.insert(searchableNames, shirtID) -- Just the ID
            end
            
            if pantsID ~= "" and pantsID ~= "None" then
                table.insert(searchableNames, "Pants #" .. pantsID)
                table.insert(searchableNames, pantsID) -- Just the ID
            end
            
            print("DEBUG: [Search] Checking listing", listingId, "customName:", customName, "searchable names:", table.concat(searchableNames, ", "))
            
            -- Search through all generated names
            local found = false
            for _, name in ipairs(searchableNames) do
                if string.find(string.lower(name), string.lower(searchQuery)) then
                    listings[listingId] = ad
                    found = true
                    print("DEBUG: [Search] MATCH found for:", name)
                    break
                end
            end
            
            if not found then
                print("DEBUG: [Search] No match for:", table.concat(searchableNames, ", "), "against:", searchQuery)
            end
        end
        
        local resultCount = 0
        for _ in pairs(listings) do resultCount = resultCount + 1 end
        print("DEBUG: [Search] Search results count:", resultCount)
    else
        listings = allListings
    end
    
    local yOffset = 10
    
    for listingId, ad in pairs(listings) do
        -- Normalize data to handle both old and new format
        local shirtID = ad.shirtID or ad.shirt or ""
        local pantsID = ad.pantsID or ad.pants or ""
        
        local timestamp = tonumber(ad.timestamp) or os.time()
        local currentTime = os.time()
        local timeLeft = timestamp - currentTime
        
        -- Get creation date (or use listing time as fallback)
        local creationDate = formatDate(tonumber(ad.creationDate) or timestamp)
        
        -- Create separate listings for each asset type when both are present
        if shirtID ~= "" and shirtID ~= "None" then
            local listingFrame = createListing(listingId, "Shirt", shirtID, timeLeft, creationDate, ad.customName)
            listingFrame.Position = UDim2.new(0, 10, 0, yOffset)
            yOffset = yOffset + 160 -- Spacing for larger listing cards with 10px margin
        end
        
        if pantsID ~= "" and pantsID ~= "None" then
            local listingFrame = createListing(listingId, "Pants", pantsID, timeLeft, creationDate, ad.customName)
            listingFrame.Position = UDim2.new(0, 10, 0, yOffset)
            yOffset = yOffset + 160 -- Spacing for larger listing cards with 10px margin
        end
        
        -- If both are empty (shouldn't happen but just in case)
        if (shirtID == "" or shirtID == "None") and (pantsID == "" or pantsID == "None") then
            local listingFrame = createListing(listingId, "Unknown", "None", timeLeft, creationDate, ad.customName)
            listingFrame.Position = UDim2.new(0, 10, 0, yOffset)
            yOffset = yOffset + 160 -- Spacing for larger listing cards with 10px margin
        end
    end
    
    -- Update scrolling frame canvas size
    listingsFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
    
    -- Show "No results found" message if no listings match the search
    local noResultsLabel = listingsFrame:FindFirstChild("NoResultsLabel")
    if noResultsLabel then
        noResultsLabel:Destroy()
    end
    
    if yOffset == 10 and searchQuery and searchQuery ~= "" then
        local noResults = Instance.new("TextLabel")
        noResults.Name = "NoResultsLabel"
        noResults.Size = UDim2.new(1, -20, 0, 50)
        noResults.Position = UDim2.new(0, 10, 0, 30)
        noResults.BackgroundTransparency = 1
        noResults.Text = "No listings found matching \"" .. searchQuery .. "\""
        noResults.TextColor3 = Color3.fromRGB(180, 180, 180)
        noResults.TextSize = 16
        noResults.Font = Enum.Font.GothamMedium
        noResults.Parent = listingsFrame
    end
end

-- Create background frame with modern styling
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 600, 0, 400)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

-- Add rounded corners
local roundCorner = Instance.new("UICorner")
roundCorner.CornerRadius = UDim.new(0, 12)
roundCorner.Parent = mainFrame

-- Add shadow effect
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.Position = UDim2.new(0, -15, 0, -15)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://6014261993"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.5
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(49, 49, 450, 450)
shadow.ZIndex = -1
shadow.Parent = mainFrame

-- Create title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

-- Add rounded corners to title bar
local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = titleBar

-- Fix the rounded corners for the title bar
local fixCorners = Instance.new("Frame")
fixCorners.Name = "FixCorners"
fixCorners.Size = UDim2.new(1, 0, 0, 15)
fixCorners.Position = UDim2.new(0, 0, 1, -15)
fixCorners.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
fixCorners.BorderSizePixel = 0
fixCorners.ZIndex = titleBar.ZIndex
fixCorners.Parent = titleBar

-- Add tab buttons container
local tabsContainer = Instance.new("Frame")
tabsContainer.Name = "TabsContainer"
tabsContainer.Size = UDim2.new(0.7, 0, 1, 0)
tabsContainer.Position = UDim2.new(0, 20, 0, 0)
tabsContainer.BackgroundTransparency = 1
tabsContainer.Parent = titleBar

-- Create tab buttons
local function createTabButton(name, posX)
    local tabButton = Instance.new("TextButton")
    tabButton.Name = name .. "Tab"
    tabButton.Size = UDim2.new(0, 100, 0, 40)
    tabButton.Position = UDim2.new(0, posX, 0.5, -20)
    tabButton.BackgroundTransparency = 1
    tabButton.Text = name
    tabButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    tabButton.TextSize = 16
    tabButton.Font = Enum.Font.GothamBold
    tabButton.Parent = tabsContainer
    
    local underline = Instance.new("Frame")
    underline.Name = "Underline"
    underline.Size = UDim2.new(1, 0, 0, 2)
    underline.Position = UDim2.new(0, 0, 1, 0)
    underline.BackgroundColor3 = Color3.fromRGB(30, 90, 200)
    underline.BackgroundTransparency = 1
    underline.BorderSizePixel = 0
    underline.Parent = tabButton
    
    return tabButton, underline
end

local myListingsTab, myListingsUnderline = createTabButton("My Listings", 0)
local shopTab, shopUnderline = createTabButton("Shop", 120)
local faqTab, faqUnderline = createTabButton("FAQ", 240)
local inventoryTab, inventoryUnderline = createTabButton("Inventory", 360)

-- Add close button
local closeButton = Instance.new("ImageButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -40, 0, 10)
closeButton.BackgroundTransparency = 1
closeButton.Image = "rbxassetid://7743878857"
closeButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = titleBar

-- Create content frames for each tab
local contentsFrame = Instance.new("Frame")
contentsFrame.Name = "ContentsFrame"
contentsFrame.Size = UDim2.new(1, -40, 1, -70)
contentsFrame.Position = UDim2.new(0, 20, 0, 60)
contentsFrame.BackgroundTransparency = 1
contentsFrame.Parent = mainFrame

-- Create scrolling frame for listings
listingsFrame = Instance.new("ScrollingFrame")
listingsFrame.Name = "ListingsFrame"
listingsFrame.Size = UDim2.new(1, 0, 1, -50) -- Reduced size to make room for search bar
listingsFrame.Position = UDim2.new(0, 0, 0, 50) -- Moved down to make room for search bar
listingsFrame.BackgroundTransparency = 1
listingsFrame.BorderSizePixel = 0
listingsFrame.ScrollBarThickness = 6
listingsFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80)
listingsFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be updated dynamically
listingsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listingsFrame.Parent = contentsFrame
listingsFrame.Visible = true

-- Create search bar container
local searchContainer = Instance.new("Frame")
searchContainer.Name = "SearchContainer"
searchContainer.Size = UDim2.new(1, 0, 0, 40)
searchContainer.BackgroundTransparency = 1
searchContainer.Parent = contentsFrame

-- Create search bar
local searchBar = Instance.new("TextBox")
searchBar.Name = "SearchBar"
searchBar.Size = UDim2.new(0.7, 0, 0, 35)
searchBar.Position = UDim2.new(0.15, 0, 0, 0)
searchBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
searchBar.BorderSizePixel = 0
searchBar.PlaceholderText = "Search listings by title..."
searchBar.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
searchBar.Text = ""
searchBar.TextColor3 = Color3.fromRGB(230, 230, 230)
searchBar.TextSize = 16
searchBar.Font = Enum.Font.GothamMedium
searchBar.Parent = searchContainer
searchBar.ClearTextOnFocus = false

-- Add rounded corners to search bar
local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 8)
searchCorner.Parent = searchBar

-- Add search icon
local searchIcon = Instance.new("ImageLabel")
searchIcon.Name = "SearchIcon"
searchIcon.Size = UDim2.new(0, 20, 0, 20)
searchIcon.Position = UDim2.new(0, 10, 0.5, -10)
searchIcon.BackgroundTransparency = 1
searchIcon.Image = "rbxassetid://3926305904" -- Roblox magnifying glass icon
searchIcon.ImageRectOffset = Vector2.new(964, 324)
searchIcon.ImageRectSize = Vector2.new(36, 36)
searchIcon.ImageColor3 = Color3.fromRGB(150, 150, 150)
searchIcon.Parent = searchBar

-- Add clear button (initially hidden)
local clearButton = Instance.new("ImageButton")
clearButton.Name = "ClearButton"
clearButton.Size = UDim2.new(0, 20, 0, 20)
clearButton.Position = UDim2.new(1, -30, 0.5, -10)
clearButton.BackgroundTransparency = 1
clearButton.Image = "rbxassetid://9386939033" -- X icon
clearButton.ImageColor3 = Color3.fromRGB(150, 150, 150)
clearButton.ImageTransparency = 1 -- Initially hidden
clearButton.Parent = searchBar

-- Store original/all listings to use for filtering
-- (allListings is already declared at the top of the file)

-- Function to create listing
createListing = function(listingId, assetType, assetId, timeLeft, creationDate, customName)
    local listingFrame = Instance.new("Frame")
    listingFrame.Name = "Listing_" .. listingId
    listingFrame.Size = UDim2.new(1, -20, 0, 150) -- Increased height from 120 to 150
    listingFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    listingFrame.BorderSizePixel = 0
    listingFrame.Parent = listingsFrame
    listingFrame:SetAttribute("ListingKey", listingId)
    
    -- Add rounded corners
    local listingCorner = Instance.new("UICorner")
    listingCorner.CornerRadius = UDim.new(0, 8)
    listingCorner.Parent = listingFrame
    
    -- Add NPC preview on the left
    local previewFrame = Instance.new("ViewportFrame")
    previewFrame.Name = "PreviewFrame"
    previewFrame.Size = UDim2.new(0, 80, 0, 130) -- Increased height to match new frame height
    previewFrame.Position = UDim2.new(0, 15, 0, 10)
    previewFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    previewFrame.BackgroundTransparency = 0.2
    previewFrame.Parent = listingFrame
    
    -- Add rounded corners to preview
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 6)
    previewCorner.Parent = previewFrame
    
    -- Setup NPC preview in the viewport
    local camera = Instance.new("Camera")
    camera.FieldOfView = 70
    previewFrame.CurrentCamera = camera
    camera.Parent = previewFrame
    
    -- Add a light to improve visibility
    local light = Instance.new("PointLight")
    light.Brightness = 1
    light.Range = 10
    light.Parent = previewFrame
    
    -- Create basic NPC model
    local npcModel = Instance.new("Model")
    npcModel.Name = "PreviewNPC"
    
    -- Create humanoid
    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = npcModel
    
    -- Create parts
    local rootPart = Instance.new("Part")
    rootPart.Name = "HumanoidRootPart"
    rootPart.Size = Vector3.new(2, 2, 1)
    rootPart.Transparency = 1
    rootPart.CanCollide = false
    rootPart.Parent = npcModel
    
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Position = rootPart.Position
    torso.Parent = npcModel
    
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1, 1, 1)
    head.Position = torso.Position + Vector3.new(0, 1.5, 0)
    head.Parent = npcModel
    
    local leftArm = Instance.new("Part")
    leftArm.Name = "Left Arm"
    leftArm.Size = Vector3.new(1, 2, 1)
    leftArm.Position = torso.Position + Vector3.new(1.5, 0, 0)
    leftArm.Parent = npcModel
    
    local rightArm = Instance.new("Part")
    rightArm.Name = "Right Arm"
    rightArm.Size = Vector3.new(1, 2, 1)
    rightArm.Position = torso.Position + Vector3.new(-1.5, 0, 0)
    rightArm.Parent = npcModel
    
    local leftLeg = Instance.new("Part")
    leftLeg.Name = "Left Leg"
    leftLeg.Size = Vector3.new(1, 2, 1)
    leftLeg.Position = torso.Position + Vector3.new(0.5, -2, 0)
    leftLeg.Parent = npcModel
    
    local rightLeg = Instance.new("Part")
    rightLeg.Name = "Right Leg"
    rightLeg.Size = Vector3.new(1, 2, 1)
    rightLeg.Position = torso.Position + Vector3.new(-0.5, -2, 0)
    rightLeg.Parent = npcModel
    
    -- Add clothing using server-side template fetching
    if assetType == "Shirt" then
        spawn(function()
            if getClothingTemplateFunc then
                local success, template = pcall(function()
                    return getClothingTemplateFunc:InvokeServer(assetId, "Shirt")
                end)
                
                if success and template then
                    local shirt = Instance.new("Shirt")
                    shirt.ShirtTemplate = template
                    shirt.Parent = npcModel
                    print("DEBUG: [ListingsGUI] Applied shirt template: " .. template)
                else
                    -- Fallback
        local shirt = Instance.new("Shirt")
        shirt.ShirtTemplate = "rbxassetid://" .. assetId
        shirt.Parent = npcModel
                    print("DEBUG: [ListingsGUI] Used fallback for shirt: " .. assetId)
                end
            else
                -- Fallback if RemoteFunction not available
                local shirt = Instance.new("Shirt")
                shirt.ShirtTemplate = "rbxassetid://" .. assetId
                shirt.Parent = npcModel
                print("DEBUG: [ListingsGUI] RemoteFunction not available, used fallback for shirt: " .. assetId)
            end
        end)
    elseif assetType == "Pants" then
        spawn(function()
            if getClothingTemplateFunc then
                local success, template = pcall(function()
                    return getClothingTemplateFunc:InvokeServer(assetId, "Pants")
                end)
                
                if success and template then
                    local pants = Instance.new("Pants")
                    pants.PantsTemplate = template
                    pants.Parent = npcModel
                    print("DEBUG: [ListingsGUI] Applied pants template: " .. template)
                else
                    -- Fallback
        local pants = Instance.new("Pants")
        pants.PantsTemplate = "rbxassetid://" .. assetId
        pants.Parent = npcModel
                    print("DEBUG: [ListingsGUI] Used fallback for pants: " .. assetId)
                end
            else
                -- Fallback if RemoteFunction not available
                local pants = Instance.new("Pants")
                pants.PantsTemplate = "rbxassetid://" .. assetId
                pants.Parent = npcModel
                print("DEBUG: [ListingsGUI] RemoteFunction not available, used fallback for pants: " .. assetId)
            end
        end)
    end
    
    -- Add skin color
    local bodyColors = Instance.new("BodyColors")
    bodyColors.HeadColor = BrickColor.new("Light orange")
    bodyColors.LeftArmColor = BrickColor.new("Light orange")
    bodyColors.RightArmColor = BrickColor.new("Light orange")
    bodyColors.TorsoColor = BrickColor.new("Light orange")
    bodyColors.LeftLegColor = BrickColor.new("Light orange")
    bodyColors.RightLegColor = BrickColor.new("Light orange")
    bodyColors.Parent = npcModel
    
    -- Add to viewport
    npcModel.Parent = previewFrame
    
    -- Position camera
    camera.CFrame = CFrame.new(head.Position + Vector3.new(0, -1.2, -5.2), head.Position + Vector3.new(0, -1.2, 0)) -- Moved camera view up to show more of upper body
    
    -- Add custom name (if provided) or default name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(0.4, -10, 0, 25)
    nameLabel.Position = UDim2.new(0.3, 15, 0, 15)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = customName and customName ~= "" and customName or (assetType .. " #" .. assetId)
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 18
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = listingFrame

    -- Add edit name button
    local editNameButton = Instance.new("ImageButton")
    editNameButton.Name = "EditNameButton"
    editNameButton.Size = UDim2.new(0, 20, 0, 20)
    editNameButton.Position = UDim2.new(0.7, -10, 0, 17.5)
    editNameButton.BackgroundTransparency = 1
    editNameButton.Image = "rbxassetid://93742865849125" -- Updated edit icon
    editNameButton.ImageColor3 = Color3.fromRGB(150, 150, 150)
    editNameButton.Parent = listingFrame
    
    -- Add reset name button (always visible)
    local resetNameButton = Instance.new("ImageButton")
    resetNameButton.Name = "ResetNameButton"
    resetNameButton.Size = UDim2.new(0, 20, 0, 20)
    resetNameButton.Position = UDim2.new(0.7, 15, 0, 17.5) -- Positioned directly next to edit button
    resetNameButton.BackgroundTransparency = 1
    resetNameButton.Image = "rbxassetid://123038098589950" -- Reset icon
    resetNameButton.ImageColor3 = Color3.fromRGB(150, 150, 150)
    resetNameButton.Visible = true
    resetNameButton.Parent = listingFrame

    -- Create the editable text box (initially hidden)
    local nameInput = Instance.new("TextBox")
    nameInput.Name = "NameInput"
    nameInput.Size = UDim2.new(0.35, -10, 0, 25)  -- Narrower to avoid overlapping buttons
    nameInput.Position = UDim2.new(0.3, 15, 0, 15)
    nameInput.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    nameInput.BorderSizePixel = 0
    nameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameInput.TextSize = 18
    nameInput.Font = Enum.Font.GothamBold
    nameInput.TextXAlignment = Enum.TextXAlignment.Left
    nameInput.Text = nameLabel.Text
    nameInput.Visible = false
    nameInput.PlaceholderText = "Enter listing name"
    nameInput.ClearTextOnFocus = false
    nameInput.Parent = listingFrame

    -- Add rounded corners to the name input
    local nameInputCorner = Instance.new("UICorner")
    nameInputCorner.CornerRadius = UDim.new(0, 4)
    nameInputCorner.Parent = nameInput

    -- Create save name remote event if it doesn't exist
    local saveNameEvent = ReplicatedStorage:FindFirstChild("SaveListingNameEvent")
    if not saveNameEvent then
        saveNameEvent = Instance.new("RemoteEvent")
        saveNameEvent.Name = "SaveListingNameEvent"
        saveNameEvent.Parent = ReplicatedStorage
    end

    -- Store original name for reset functionality 
    -- We'll use the actual original name from creation, or default to current if not specified
    local originalName = customName and customName ~= "" and customName or (assetType .. " #" .. assetId)
    
    -- Connect edit name button
    editNameButton.MouseEnter:Connect(function()
        editNameButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    end)

    editNameButton.MouseLeave:Connect(function()
        editNameButton.ImageColor3 = Color3.fromRGB(150, 150, 150)
    end)

    editNameButton.MouseButton1Click:Connect(function()
        -- Show the input and hide the label
        nameLabel.Visible = false
        nameInput.Visible = true
        nameInput:CaptureFocus()
    end)
    
    -- Connect reset name button
    resetNameButton.MouseEnter:Connect(function()
        resetNameButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    end)

    resetNameButton.MouseLeave:Connect(function()
        resetNameButton.ImageColor3 = Color3.fromRGB(150, 150, 150)
    end)
    
    resetNameButton.MouseButton1Click:Connect(function()
        -- Reset to original name
        nameInput.Text = originalName
        nameLabel.Text = originalName
        
        -- Save the name to the server
        saveNameEvent:FireServer(listingId, originalName)
        
        -- Hide the input if it's visible
        if nameInput.Visible then
            nameInput.Visible = false
            nameLabel.Visible = true
        end
    end)

    -- Handle saving the name
    nameInput.FocusLost:Connect(function(enterPressed)
        -- Hide the input and show the label
        nameInput.Visible = false
        nameLabel.Visible = true
        
        -- Only update if the name changed
        if nameInput.Text ~= "" and nameInput.Text ~= nameLabel.Text then
            nameLabel.Text = nameInput.Text
            
            -- Save the name to the server
            saveNameEvent:FireServer(listingId, nameInput.Text)
        end
    end)
    
    -- Add asset info (moved down below the name)
    local assetLabel = Instance.new("TextLabel")
    assetLabel.Name = "AssetLabel"
    assetLabel.Size = UDim2.new(0.5, -10, 0, 25)
    assetLabel.Position = UDim2.new(0.3, 15, 0, 40)
    assetLabel.BackgroundTransparency = 1
    assetLabel.Text = assetType .. ": " .. assetId
    assetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    assetLabel.TextSize = 14
    assetLabel.Font = Enum.Font.GothamSemibold
    assetLabel.TextXAlignment = Enum.TextXAlignment.Left
    assetLabel.Parent = listingFrame
    
    -- Add creation date (moved down)
    local dateLabel = Instance.new("TextLabel")
    dateLabel.Name = "DateLabel"
    dateLabel.Size = UDim2.new(0.5, -10, 0, 25)
    dateLabel.Position = UDim2.new(0.3, 15, 0, 65)
    dateLabel.BackgroundTransparency = 1
    dateLabel.Text = "Added: " .. creationDate
    dateLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    dateLabel.TextSize = 14
    dateLabel.Font = Enum.Font.GothamMedium
    dateLabel.TextXAlignment = Enum.TextXAlignment.Left
    dateLabel.Parent = listingFrame
    
    -- Add status display (Expired or Time Left)
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(0, 70, 0, 25)
    statusLabel.Position = UDim2.new(1, -80, 0, 15)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextSize = 15
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    statusLabel.Parent = listingFrame
    
    -- Create renew button first
    local renewButton = Instance.new("TextButton")
    renewButton.Name = "RenewButton"
    renewButton.Size = UDim2.new(0, 120, 0, 32)
    renewButton.Position = UDim2.new(0.65, -60, 0, 105)
    renewButton.BackgroundColor3 = Color3.fromRGB(50, 180, 100)
    renewButton.BorderSizePixel = 0
    renewButton.Text = "Renew Listing"
    renewButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    renewButton.TextSize = 16
    renewButton.Font = Enum.Font.GothamBold
    renewButton.Visible = false -- Default to hidden, will set below
    renewButton.Parent = listingFrame
    
    -- Add rounded corners to renew button
    local renewCorner = Instance.new("UICorner")
    renewCorner.CornerRadius = UDim.new(0, 8)
    renewCorner.Parent = renewButton
    
    -- Add gradient to button
    local renewGradient = Instance.new("UIGradient")
    renewGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 200, 110)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 160, 90))
    })
    renewGradient.Rotation = 90
    renewGradient.Parent = renewButton
    
    -- Update time display and renew button visibility
    if timeLeft and timeLeft > 0 then
        local hours = math.floor(timeLeft / 3600)
        local minutes = math.floor((timeLeft % 3600) / 60)
        statusLabel.Text = hours .. "h " .. minutes .. "m"
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        renewButton.Visible = false
    else
        statusLabel.Text = "Expired"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        renewButton.Visible = true
    end
    
    -- Create continuous timer update system
    local initialTimestamp = os.time() + timeLeft -- Calculate the expiration timestamp
    local timerConnection
    local hasExpired = timeLeft <= 0
    
    timerConnection = RunService.Heartbeat:Connect(function()
        local currentTime = os.time()
        local remainingTime = initialTimestamp - currentTime
        
        if remainingTime > 0 then
            -- Still time left - update display
            local hours = math.floor(remainingTime / 3600)
            local minutes = math.floor((remainingTime % 3600) / 60)
            statusLabel.Text = hours .. "h " .. minutes .. "m"
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            renewButton.Visible = false
        else
            -- Timer expired
            statusLabel.Text = "Expired"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            renewButton.Visible = true
            
            -- If this just expired (wasn't already expired), refresh the listings
            if not hasExpired then
                hasExpired = true
                print("DEBUG: [Timer] Listing", listingId, "just expired, refreshing listings...")
                -- Only refresh if we're currently on My Listings tab
                if selectedTab == "My Listings" then
                    updateListings(nil, true) -- Force refresh to get server data with renewal buttons
                end
            end
        end
    end)
    
    -- Clean up timer connection when listing frame is destroyed
    listingFrame.AncestryChanged:Connect(function(_, parent)
        if not parent and timerConnection then
            timerConnection:Disconnect()
            timerConnection = nil
        end
    end)
    
    -- Create "See Stats" button - only show if player owns the gamepass
    local statsButton = nil
    local MarketplaceService = game:GetService("MarketplaceService")
    
    -- Check if player owns the See Stats gamepass
    local ownsStatsGamepass = false
    local success, result = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1234092306)
    end)
    
    print("DEBUG: [ListingsGUI] See Stats gamepass check - Success:", success, "Result:", result, "for player:", player.Name)
    
    if success and result then
        ownsStatsGamepass = true
    end
    
    -- TEMPORARY: Bypass gamepass check for testing
    ownsStatsGamepass = true
    print("DEBUG: [ListingsGUI] TEMPORARILY BYPASSED gamepass check - forcing button creation")
    
    print("DEBUG: [ListingsGUI] Owns stats gamepass:", ownsStatsGamepass, "Creating button:", ownsStatsGamepass)
    
    -- Only create the button if player owns the gamepass
    if ownsStatsGamepass then
        print("DEBUG: [ListingsGUI] Creating See Stats button for asset:", assetId, "type:", assetType)
        statsButton = Instance.new("TextButton")
        statsButton.Name = "StatsButton"
        statsButton.Size = UDim2.new(0, 120, 0, 32)
        statsButton.Position = UDim2.new(0.35, -60, 0, 105) -- Moved down from 80 to 105
        statsButton.BackgroundColor3 = Color3.fromRGB(30, 120, 255)
        statsButton.BorderSizePixel = 0
        statsButton.Text = "See Stats"
        statsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        statsButton.TextSize = 16
        statsButton.Font = Enum.Font.GothamBold
        statsButton.Parent = listingFrame

        -- Add rounded corners to button
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = statsButton
        
        -- Add gradient to button
        local buttonGradient = Instance.new("UIGradient")
        buttonGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 170, 240)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 120, 200))
        })
        buttonGradient.Rotation = 90
        buttonGradient.Parent = statsButton
        
        -- Add hover effect to the button
        statsButton.MouseEnter:Connect(function()
            TweenService:Create(
                statsButton,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {BackgroundColor3 = Color3.fromRGB(70, 140, 220)}
            ):Play()
        end)
        
        statsButton.MouseLeave:Connect(function()
            TweenService:Create(
                statsButton,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {BackgroundColor3 = Color3.fromRGB(30, 90, 200)}
            ):Play()
        end)
        
        -- Button-down effect
        statsButton.MouseButton1Down:Connect(function()
            TweenService:Create(
                statsButton,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 115, 0, 30), Position = UDim2.new(0.35, -57.5, 0, 106)} -- Adjusted position
            ):Play()
        end)
        
        statsButton.MouseButton1Up:Connect(function()
            TweenService:Create(
                statsButton,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 120, 0, 32), Position = UDim2.new(0.35, -60, 0, 105)} -- Adjusted position
            ):Play()
        end)
        
        -- Connect the stats button
        statsButton.MouseButton1Click:Connect(function()
            print("DEBUG: [ListingsGUI] See Stats button clicked! AssetId:", assetId, "AssetType:", assetType)
            openAssetStatsEvent:FireServer(assetId, assetType)
            print("DEBUG: [ListingsGUI] Fired openAssetStatsEvent to server")
        end)
        
        print("DEBUG: [ListingsGUI] See Stats button created successfully")
    else
        print("DEBUG: [ListingsGUI] Player does not own See Stats gamepass, skipping button creation")
    end
    
    -- Create delete button with trash icon - moved down
    local deleteButton = Instance.new("ImageButton")
    deleteButton.Name = "DeleteButton"
    deleteButton.Size = UDim2.new(0, 32, 0, 32)
    deleteButton.Position = UDim2.new(0.95, -16, 0, 105) -- Moved down from 80 to 105
    deleteButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    deleteButton.BorderSizePixel = 0
    deleteButton.Image = "rbxassetid://6022668885"  -- Trash icon
    deleteButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    deleteButton.Parent = listingFrame
    
    -- Add rounded corners to delete button
    local deleteButtonCorner = Instance.new("UICorner")
    deleteButtonCorner.CornerRadius = UDim.new(0, 8)
    deleteButtonCorner.Parent = deleteButton
    
    -- Add hover effect to the delete button
    deleteButton.MouseEnter:Connect(function()
        TweenService:Create(
            deleteButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(230, 70, 70), Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0.95, -18, 0, 103)}
        ):Play()
    end)
    
    deleteButton.MouseLeave:Connect(function()
        TweenService:Create(
            deleteButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(200, 60, 60), Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0.95, -16, 0, 105)}
        ):Play()
    end)
    
    -- Button-down effect
    deleteButton.MouseButton1Down:Connect(function()
        TweenService:Create(
            deleteButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(0.95, -14, 0, 107)} -- Adjusted position
        ):Play()
    end)
    
    deleteButton.MouseButton1Up:Connect(function()
        TweenService:Create(
            deleteButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0.95, -16, 0, 105)} -- Adjusted position
        ):Play()
    end)
    
    -- Connect the delete button to show confirmation dialog
    deleteButton.MouseButton1Click:Connect(function()
        showConfirmationDialog(listingId, listingFrame)
    end)
    
    -- Rotate the model slowly
    local rotation = 0
    local rotationConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if npcModel and npcModel.Parent then
            rotation = rotation + deltaTime * 0.5
            rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, rotation, 0)
        else
            rotationConnection:Disconnect()
        end
    end)
    
    -- Store the connection in the viewport
    previewFrame:SetAttribute("RotationConnection", true)
    previewFrame.AncestryChanged:Connect(function(_, parent)
        if not parent then
            rotationConnection:Disconnect()
        end
    end)
    
    -- Add hover effect to renew button
    renewButton.MouseEnter:Connect(function()
        TweenService:Create(
            renewButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(60, 200, 110)}
        ):Play()
    end)
    
    renewButton.MouseLeave:Connect(function()
        TweenService:Create(
            renewButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(50, 180, 100)}
        ):Play()
    end)
    
    -- Button-down effect for renew button
    renewButton.MouseButton1Down:Connect(function()
        TweenService:Create(
            renewButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 115, 0, 30), Position = UDim2.new(0.65, -57.5, 0, 106)} -- Adjusted position
        ):Play()
    end)
    
    renewButton.MouseButton1Up:Connect(function()
        TweenService:Create(
            renewButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 120, 0, 32), Position = UDim2.new(0.65, -60, 0, 105)} -- Adjusted position
        ):Play()
    end)
    
    -- Connect renew button to server event
    renewButton.MouseButton1Click:Connect(function()
        print("DEBUG: Renew button clicked for listing ID:", listingId)
        
        -- Save original button properties to restore later
        local originalText = renewButton.Text
        local originalColor = renewButton.BackgroundColor3
        local originalActive = renewButton.Active
        
        -- Update button appearance
        renewButton.Text = "Renewing..."
        renewButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        renewButton.Active = false -- Use Active instead of Enabled which is not valid for TextButton
        
        -- Fire server event to handle renewal
        print("DEBUG: Firing renewListingEvent to server with ID:", listingId)
        renewListingEvent:FireServer(listingId)
        
        -- Listen for success event first
        local successConnection
        local failureConnection  
        local timeoutThread
        
        successConnection = renewSuccessEvent.OnClientEvent:Connect(function(successListingId)
            print("DEBUG: Received renewal success for listing:", successListingId)
            if successListingId == listingId then
                -- Cancel timeout
                if timeoutThread then
                    task.cancel(timeoutThread)
                    timeoutThread = nil
                end
                
                -- Disconnect this temporary connection
                if successConnection then
                    successConnection:Disconnect()
                    successConnection = nil
                end
                if failureConnection then
                    failureConnection:Disconnect()
                    failureConnection = nil
                end
                
                -- Show success notification
                showNotification("Listing renewed successfully!", Color3.fromRGB(0, 255, 0))
                
                -- Force refresh the listings to show updated timestamp
                updateListings(nil, true) -- Force refresh with updated data
            end
        end)
        
        -- Listen for failure event
        failureConnection = renewFailedEvent.OnClientEvent:Connect(function(failedListingId)
            print("DEBUG: Received renewal failure for listing:", failedListingId)
            if failedListingId == listingId then
                -- Cancel timeout
                if timeoutThread then
                    task.cancel(timeoutThread)
                    timeoutThread = nil
                end
                
                -- Disconnect this temporary connection
                if failureConnection then
                    failureConnection:Disconnect()
                    failureConnection = nil
                end
                if successConnection then
                    successConnection:Disconnect()
                    successConnection = nil
                end
                
                -- Show failure notification
                showNotification("Failed to renew listing. Please try again.", Color3.fromRGB(255, 0, 0))
                
                -- Reset button
                renewButton.Text = originalText
                renewButton.BackgroundColor3 = originalColor
                renewButton.Active = originalActive
            end
        end)
        
        -- Timeout after 10 seconds to prevent hanging
        timeoutThread = task.spawn(function()
            task.wait(10)
            print("DEBUG: Renewal response timed out for listing:", listingId)
            
            -- Disconnect any remaining connections
            if successConnection then
                successConnection:Disconnect()
                successConnection = nil
            end
            if failureConnection then
                failureConnection:Disconnect()
                failureConnection = nil
            end
            
            -- Show timeout notification
            showNotification("Renewal request timed out. Please try again.", Color3.fromRGB(255, 165, 0))
            
            -- Reset button
            if renewButton and renewButton.Parent then
                renewButton.Text = originalText
                renewButton.BackgroundColor3 = originalColor
                renewButton.Active = originalActive
            end
            
            timeoutThread = nil
        end)
    end)
    
    -- Return the frame for further modifications
    return listingFrame
end



-- Connect clear button
clearButton.MouseButton1Click:Connect(function()
    searchBar.Text = ""
    clearButton.ImageTransparency = 1
    if isGUIInitialized and selectedTab == "My Listings" then
        updateListings(nil, true) -- Force refresh to get latest data
    end
end)

-- Debounce variables for search
local searchDebounce = false
local searchDelay = 0.3 -- 300ms delay

-- Connect search bar events
searchBar.Changed:Connect(function(property)
    if property == "Text" then
        -- Show/hide clear button based on if there's text
        clearButton.ImageTransparency = (searchBar.Text == "") and 1 or 0
        
        -- Only perform search if GUI is initialized and we're on My Listings tab
        if isGUIInitialized and selectedTab == "My Listings" then
            -- Debounce the search to prevent too many rapid calls
            if not searchDebounce then
                searchDebounce = true
                
                -- Delay the search slightly to allow for rapid typing
                task.spawn(function()
                    task.wait(searchDelay)
                    
                    -- Perform real-time search as user types
                    if isGUIInitialized and selectedTab == "My Listings" then -- Double-check
                        print("DEBUG: [SearchEvent] Calling updateListings with query:", searchBar.Text)
                        -- Force refresh to get latest data (including any edited names)
                        updateListings(searchBar.Text, true) -- Force refresh = true
                    end
                    
                    searchDebounce = false
                end)
            end
        end
    end
end)

-- We can simplify the FocusLost connection since the searching is now handled in real-time
searchBar.FocusLost:Connect(function(enterPressed)
    -- We don't need to do anything here now, as search happens in real-time
end)

-- Add hover effects for clear button
clearButton.MouseEnter:Connect(function()
    if searchBar.Text ~= "" then
        TweenService:Create(clearButton, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(220, 220, 220)}):Play()
    end
end)

clearButton.MouseLeave:Connect(function()
    TweenService:Create(clearButton, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(150, 150, 150)}):Play()
end)

-- Create frame for shop tab (initially hidden)
local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Size = UDim2.new(1, 0, 1, 0)
shopFrame.BackgroundTransparency = 1
shopFrame.Parent = contentsFrame
shopFrame.Visible = false

-- Create scrolling frame for shop items
local shopScrollFrame = Instance.new("ScrollingFrame")
shopScrollFrame.Name = "ShopScrollFrame"
shopScrollFrame.Size = UDim2.new(1, 0, 1, 0)
shopScrollFrame.BackgroundTransparency = 1
shopScrollFrame.BorderSizePixel = 0
shopScrollFrame.ScrollBarThickness = 6
shopScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80)
shopScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 780) -- Increased from 700 to 780 to ensure VIP crate is fully visible
shopScrollFrame.Parent = shopFrame

-- Create shop title
local shopTitle = Instance.new("TextLabel")
shopTitle.Name = "ShopTitle"
shopTitle.Size = UDim2.new(1, -40, 0, 40)
shopTitle.Position = UDim2.new(0, 20, 0, 10)
shopTitle.BackgroundTransparency = 1
shopTitle.Text = "Crate Shop"
shopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
shopTitle.TextSize = 24
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.Parent = shopScrollFrame

-- Create shop description
local shopDescription = Instance.new("TextLabel")
shopDescription.Name = "ShopDescription"
shopDescription.Size = UDim2.new(1, -40, 0, 30)
shopDescription.Position = UDim2.new(0, 20, 0, 50)
shopDescription.BackgroundTransparency = 1
shopDescription.Text = "Purchase crates to get exclusive clothing items!"
shopDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
shopDescription.TextSize = 16
shopDescription.Font = Enum.Font.GothamMedium
shopDescription.TextXAlignment = Enum.TextXAlignment.Left
shopDescription.Parent = shopScrollFrame

-- Function to create a crate item
local function createCrateItem(name, color, position, coinPrice, robuxPrice, imageId, devProductId)
    -- Create crate container
    local crateFrame = Instance.new("Frame")
    crateFrame.Name = name .. "Crate"
    crateFrame.Size = UDim2.new(1, -40, 0, 150) -- Increased height from 120 to 150
    crateFrame.Position = position
    crateFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    crateFrame.BorderSizePixel = 0
    crateFrame.Parent = shopScrollFrame
    
    -- Add rounded corners
    local crateCorner = Instance.new("UICorner")
    crateCorner.CornerRadius = UDim.new(0, 10)
    crateCorner.Parent = crateFrame
    
    -- Add crate image
    local crateImage = Instance.new("ImageLabel")
    crateImage.Name = "CrateImage"
    crateImage.Size = UDim2.new(0, 80, 0, 80)
    crateImage.Position = UDim2.new(0, 20, 0.5, -40)
    crateImage.BackgroundTransparency = 1 -- Make the background transparent
    crateImage.BorderSizePixel = 0
    crateImage.Image = "rbxassetid://" .. imageId -- Use specific crate image
    crateImage.Parent = crateFrame
    
    -- Add rounded corners to image
    local imageCorner = Instance.new("UICorner")
    imageCorner.CornerRadius = UDim.new(0, 8)
    imageCorner.Parent = crateImage
    
    -- Add crate name
    local crateName = Instance.new("TextLabel")
    crateName.Name = "CrateName"
    crateName.Size = UDim2.new(0.6, -20, 0, 30)
    crateName.Position = UDim2.new(0.4, 0, 0, 15)
    crateName.BackgroundTransparency = 1
    crateName.Text = name .. " Crate"
    crateName.TextColor3 = Color3.fromRGB(255, 255, 255)
    crateName.TextSize = 18
    crateName.Font = Enum.Font.GothamBold
    crateName.TextXAlignment = Enum.TextXAlignment.Left
    crateName.Parent = crateFrame
    
    -- Add crate description
    local crateDescription = Instance.new("TextLabel")
    crateDescription.Name = "CrateDescription"
    crateDescription.Size = UDim2.new(0.6, -20, 0, 70) -- Increased height from 50 to 70
    crateDescription.Position = UDim2.new(0.4, 0, 0, 45)
    crateDescription.BackgroundTransparency = 1
    crateDescription.Text = "Contains " .. string.lower(name) .. " clothing items with a chance for rare finds!"
    crateDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
    crateDescription.TextSize = 14
    crateDescription.TextWrapped = true
    crateDescription.Font = Enum.Font.GothamMedium
    crateDescription.TextXAlignment = Enum.TextXAlignment.Left
    crateDescription.Parent = crateFrame
    
    -- Add View Contents button (positioned in upper right corner)
    local viewContentsButton = Instance.new("TextButton")
    viewContentsButton.Name = "ViewContentsButton"
    viewContentsButton.Size = UDim2.new(0, 90, 0, 25)
    viewContentsButton.Position = UDim2.new(1, -100, 0, 10) -- Upper right corner
    viewContentsButton.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
    viewContentsButton.BorderSizePixel = 0
    viewContentsButton.Text = "View Contents"
    viewContentsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    viewContentsButton.TextSize = 12
    viewContentsButton.Font = Enum.Font.GothamSemibold
    viewContentsButton.Parent = crateFrame
    
    -- Add rounded corners to view contents button
    local viewContentsCorner = Instance.new("UICorner")
    viewContentsCorner.CornerRadius = UDim.new(0, 6)
    viewContentsCorner.Parent = viewContentsButton

    -- Add coins purchase button
    local coinButton = Instance.new("TextButton")
    coinButton.Name = "CoinButton"
    coinButton.Size = UDim2.new(0, 140, 0, 36)
    coinButton.Position = UDim2.new(0.45, -70, 1, -46) -- Moved from right side (1, -250) to more centered position
    coinButton.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
    coinButton.BorderSizePixel = 0
    coinButton.Text = "    " .. coinPrice .. " Coins" -- Add spaces for padding
    coinButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    coinButton.TextSize = 16
    coinButton.Font = Enum.Font.GothamBold
    coinButton.Parent = crateFrame
    
    -- Add coin icon to the button
    local coinIcon = Instance.new("ImageLabel")
    coinIcon.Name = "CoinIcon"
    coinIcon.Size = UDim2.new(0, 20, 0, 20)
    coinIcon.Position = UDim2.new(0, 10, 0.5, -10)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Image = "rbxassetid://85328818138281" -- Updated coin icon from ModernProgressBar
    coinIcon.ImageColor3 = Color3.fromRGB(255, 215, 0) -- Gold color
    coinIcon.Parent = coinButton
    
    -- Add rounded corners to coin button
    local coinButtonCorner = Instance.new("UICorner")
    coinButtonCorner.CornerRadius = UDim.new(0, 8)
    coinButtonCorner.Parent = coinButton
    
    -- Add Robux purchase button
    local robuxButton = Instance.new("TextButton")
    robuxButton.Name = "RobuxButton"
    robuxButton.Size = UDim2.new(0, 120, 0, 36)
    robuxButton.Position = UDim2.new(0.75, -60, 1, -46) -- Moved from right side (1, -120) to more centered position
    robuxButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    robuxButton.BorderSizePixel = 0
    robuxButton.Text = "    " .. robuxPrice .. " R$" -- Add spaces for padding
    robuxButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    robuxButton.TextSize = 16
    robuxButton.Font = Enum.Font.GothamBold
    robuxButton.Parent = crateFrame
    
    -- Add Robux icon to the button
    local robuxIcon = Instance.new("ImageLabel")
    robuxIcon.Name = "RobuxIcon"
    robuxIcon.Size = UDim2.new(0, 20, 0, 20)
    robuxIcon.Position = UDim2.new(0, 10, 0.5, -10)
    robuxIcon.BackgroundTransparency = 1
    robuxIcon.Image = "rbxassetid://1080142088" -- Robux icon
    robuxIcon.ImageColor3 = Color3.fromRGB(0, 190, 0) -- Green color
    robuxIcon.Parent = robuxButton
    
    -- Add rounded corners to Robux button
    local robuxButtonCorner = Instance.new("UICorner")
    robuxButtonCorner.CornerRadius = UDim.new(0, 8)
    robuxButtonCorner.Parent = robuxButton
    
    -- Add hover effects to the coin button
    coinButton.MouseEnter:Connect(function()
        TweenService:Create(
            coinButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(80, 180, 80)}
        ):Play()
    end)
    
    coinButton.MouseLeave:Connect(function()
        TweenService:Create(
            coinButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(60, 160, 60)}
        ):Play()
    end)
    
    -- Button-down effect for coin button
    coinButton.MouseButton1Down:Connect(function()
        TweenService:Create(
            coinButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 136, 0, 34), Position = UDim2.new(0.45, -68, 1, -45)} -- Adjusted for new position
        ):Play()
    end)
    
    coinButton.MouseButton1Up:Connect(function()
        TweenService:Create(
            coinButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 140, 0, 36), Position = UDim2.new(0.45, -70, 1, -46)} -- Adjusted for new position
        ):Play()
    end)
    
    -- Button-down effect for Robux button
    robuxButton.MouseButton1Down:Connect(function()
        TweenService:Create(
            robuxButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 116, 0, 34), Position = UDim2.new(0.75, -58, 1, -45)} -- Adjusted for new position
        ):Play()
    end)
    
    robuxButton.MouseButton1Up:Connect(function()
        TweenService:Create(
            robuxButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 120, 0, 36), Position = UDim2.new(0.75, -60, 1, -46)} -- Adjusted for new position
        ):Play()
    end)
    
    -- Connect view contents button
    viewContentsButton.MouseButton1Click:Connect(function()
        showCrateContents(name)
    end)
    
    -- Add hover effects to view contents button
    viewContentsButton.MouseEnter:Connect(function()
        TweenService:Create(
            viewContentsButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(120, 120, 140)}
        ):Play()
    end)
    
    viewContentsButton.MouseLeave:Connect(function()
        TweenService:Create(
            viewContentsButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(100, 100, 120)}
        ):Play()
    end)
    
    -- Button-down effect for view contents button
    viewContentsButton.MouseButton1Down:Connect(function()
        TweenService:Create(
            viewContentsButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 86, 0, 23), Position = UDim2.new(1, -98, 0, 11)}
        ):Play()
    end)
    
    viewContentsButton.MouseButton1Up:Connect(function()
        TweenService:Create(
            viewContentsButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 90, 0, 25), Position = UDim2.new(1, -100, 0, 10)}
        ):Play()
    end)

    -- Connect coin purchase button
    coinButton.MouseButton1Click:Connect(function()
        -- Check VIP access for VIP crate
        if name == "VIP" then
            local MarketplaceService = game:GetService("MarketplaceService")
            local hasVIP = false
            local success = pcall(function()
                hasVIP = MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1226490667) -- VIP gamepass ID
            end)
            
            if not success or not hasVIP then
                showNotification("VIP gamepass required to purchase VIP crates!", Color3.fromRGB(200, 60, 60))
                return
            end
        end
        
        -- Show confirmation dialog instead of direct purchase
        showCoinPurchaseDialog(name, coinPrice)
    end)
    
    -- Connect Robux purchase button
    robuxButton.MouseButton1Click:Connect(function()
        -- Check VIP access for VIP crate
        if name == "VIP" then
            local MarketplaceService = game:GetService("MarketplaceService")
            local hasVIP = false
            local success = pcall(function()
                hasVIP = MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1226490667) -- VIP gamepass ID
            end)
            
            if not success or not hasVIP then
                showNotification("VIP gamepass required to purchase VIP crates!", Color3.fromRGB(200, 60, 60))
                return
            end
        end
        
        -- Implement dev product purchase if ID is provided
        if devProductId then
        
            
            -- Create or get the purchase event if it doesn't exist
            local purchaseDevProductEvent = ReplicatedStorage:FindFirstChild("PurchaseDevProductEvent")
            if not purchaseDevProductEvent then
                purchaseDevProductEvent = Instance.new("RemoteFunction")
                purchaseDevProductEvent.Name = "PurchaseDevProductEvent"
                purchaseDevProductEvent.Parent = ReplicatedStorage
            end
            
            -- Call server to prompt purchase
            local purchasePrompted = purchaseDevProductEvent:InvokeServer(devProductId, name)
            
            -- Only show error if we couldn't even prompt the purchase
            if not purchasePrompted then
                showNotification("Unable to start purchase. Please try again later.", Color3.fromRGB(200, 60, 60))
                -- Restore ListingsGUI if purchase failed to prompt
    
            end
            -- Success notification will be handled by the server after actual purchase confirmation
        else
            -- Default notification for crates without dev product ID
            showNotification("Coming soon! " .. name .. " crate purchase with Robux", Color3.fromRGB(60, 120, 200))
        end
    end)
    
    return crateFrame
end

-- Create Game Passes section divider
local gamePassesDivider = Instance.new("Frame")
gamePassesDivider.Name = "GamePassesDivider"
gamePassesDivider.Size = UDim2.new(1, -40, 0, 2)
gamePassesDivider.Position = UDim2.new(0, 20, 0, 780)
gamePassesDivider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
gamePassesDivider.BorderSizePixel = 0
gamePassesDivider.Parent = shopScrollFrame

-- Create Game Passes title
local gamePassesTitle = Instance.new("TextLabel")
gamePassesTitle.Name = "GamePassesTitle"
gamePassesTitle.Size = UDim2.new(1, -40, 0, 40)
gamePassesTitle.Position = UDim2.new(0, 20, 0, 800)
gamePassesTitle.BackgroundTransparency = 1
gamePassesTitle.Text = "Game Passes"
gamePassesTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
gamePassesTitle.TextSize = 24
gamePassesTitle.Font = Enum.Font.GothamBold
gamePassesTitle.TextXAlignment = Enum.TextXAlignment.Left
gamePassesTitle.Parent = shopScrollFrame

-- Create Game Passes description
local gamePassesDescription = Instance.new("TextLabel")
gamePassesDescription.Name = "GamePassesDescription"
gamePassesDescription.Size = UDim2.new(1, -40, 0, 30)
gamePassesDescription.Position = UDim2.new(0, 20, 0, 840)
gamePassesDescription.BackgroundTransparency = 1
gamePassesDescription.Text = "Special perks and benefits for your Clothing Universe experience!"
gamePassesDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
gamePassesDescription.TextSize = 16
gamePassesDescription.Font = Enum.Font.GothamMedium
gamePassesDescription.TextXAlignment = Enum.TextXAlignment.Left
gamePassesDescription.Parent = shopScrollFrame

-- Create VIP Game Pass frame
local vipGamePassFrame = Instance.new("Frame")
vipGamePassFrame.Name = "VIPGamePass"
vipGamePassFrame.Size = UDim2.new(1, -40, 0, 150)
vipGamePassFrame.Position = UDim2.new(0, 20, 0, 880)
vipGamePassFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
vipGamePassFrame.BorderSizePixel = 0
vipGamePassFrame.Parent = shopScrollFrame

-- Add rounded corners to VIP Game Pass frame
local vipGamePassCorner = Instance.new("UICorner")
vipGamePassCorner.CornerRadius = UDim.new(0, 10)
vipGamePassCorner.Parent = vipGamePassFrame

-- Add VIP Game Pass icon
local vipGamePassIcon = Instance.new("ImageLabel")
vipGamePassIcon.Name = "VIPGamePassIcon"
vipGamePassIcon.Size = UDim2.new(0, 80, 0, 80)
vipGamePassIcon.Position = UDim2.new(0, 20, 0.5, -40)
vipGamePassIcon.BackgroundTransparency = 1
vipGamePassIcon.Image = "rbxassetid://132147304727347" -- VIP icon from user
vipGamePassIcon.ImageColor3 = Color3.fromRGB(255, 255, 255) -- Use original color
vipGamePassIcon.Parent = vipGamePassFrame

-- Add VIP Game Pass title
local vipGamePassTitle = Instance.new("TextLabel")
vipGamePassTitle.Name = "VIPGamePassTitle"
vipGamePassTitle.Size = UDim2.new(0.6, -20, 0, 30)
vipGamePassTitle.Position = UDim2.new(0.4, 0, 0, 15)
vipGamePassTitle.BackgroundTransparency = 1
vipGamePassTitle.Text = "VIP Membership"
vipGamePassTitle.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold color
vipGamePassTitle.TextSize = 18
vipGamePassTitle.Font = Enum.Font.GothamBold
vipGamePassTitle.TextXAlignment = Enum.TextXAlignment.Left
vipGamePassTitle.Parent = vipGamePassFrame

-- Add VIP Game Pass description
local vipGamePassDescription = Instance.new("TextLabel")
vipGamePassDescription.Name = "VIPGamePassDescription"
vipGamePassDescription.Size = UDim2.new(0.6, -20, 0, 70)
vipGamePassDescription.Position = UDim2.new(0.4, 0, 0, 45)
vipGamePassDescription.BackgroundTransparency = 1
vipGamePassDescription.Text = "Unlock exclusive perks: 2x coin earnings, VIP clothing items, special name tag, and more!"
vipGamePassDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
vipGamePassDescription.TextSize = 14
vipGamePassDescription.TextWrapped = true
vipGamePassDescription.Font = Enum.Font.GothamMedium
vipGamePassDescription.TextXAlignment = Enum.TextXAlignment.Left
vipGamePassDescription.Parent = vipGamePassFrame

-- Add purchase button for VIP Game Pass
local vipGamePassButton = Instance.new("TextButton")
vipGamePassButton.Name = "VIPGamePassButton"
vipGamePassButton.Size = UDim2.new(0, 120, 0, 36)
vipGamePassButton.Position = UDim2.new(0.75, -60, 1, -46)
vipGamePassButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
vipGamePassButton.BorderSizePixel = 0
vipGamePassButton.Text = "    50 R$"
vipGamePassButton.TextColor3 = Color3.fromRGB(255, 255, 255)
vipGamePassButton.TextSize = 16
vipGamePassButton.Font = Enum.Font.GothamBold
vipGamePassButton.Parent = vipGamePassFrame

-- Add Robux icon to the button
local robuxIcon = Instance.new("ImageLabel")
robuxIcon.Name = "RobuxIcon"
robuxIcon.Size = UDim2.new(0, 20, 0, 20)
robuxIcon.Position = UDim2.new(0, 10, 0.5, -10)
robuxIcon.BackgroundTransparency = 1
robuxIcon.Image = "rbxassetid://1080142088" -- Robux icon
robuxIcon.ImageColor3 = Color3.fromRGB(0, 190, 0) -- Green color
robuxIcon.Parent = vipGamePassButton

-- Add rounded corners to purchase button
local vipGamePassButtonCorner = Instance.new("UICorner")
vipGamePassButtonCorner.CornerRadius = UDim.new(0, 8)
vipGamePassButtonCorner.Parent = vipGamePassButton

-- Add hover and click effects to VIP Game Pass button
vipGamePassButton.MouseEnter:Connect(function()
    if vipGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            vipGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(60, 200, 60)}
        ):Play()
    end
end)

vipGamePassButton.MouseLeave:Connect(function()
    if vipGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            vipGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(40, 180, 40)}
        ):Play()
    end
end)

vipGamePassButton.MouseButton1Down:Connect(function()
    TweenService:Create(
        vipGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 116, 0, 34), Position = UDim2.new(0.75, -58, 1, -45)}
    ):Play()
end)

vipGamePassButton.MouseButton1Up:Connect(function()
    TweenService:Create(
        vipGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 120, 0, 36), Position = UDim2.new(0.75, -60, 1, -46)}
    ):Play()
end)

-- Function to check gamepass ownership and update button
local function updateGamePassButton(button, gamePassId, price)
    local MarketplaceService = game:GetService("MarketplaceService")
    local success, ownsGamePass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
    end)
    
    if success and ownsGamePass then
        button.Text = "You already own this"
        button.BackgroundTransparency = 1 -- Make button background transparent
        button.TextColor3 = Color3.fromRGB(200, 200, 200)
        -- Hide the Robux icon
        local robuxIcon = button:FindFirstChild("RobuxIcon")
        if robuxIcon then
            robuxIcon.Visible = false
        end
        return true
    else
        button.Text = "    " .. price .. " R$"
        button.BackgroundTransparency = 0 -- Show button background
        button.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        -- Show the Robux icon
        local robuxIcon = button:FindFirstChild("RobuxIcon")
        if robuxIcon then
            robuxIcon.Visible = true
        end
        return false
    end
end

-- Update VIP gamepass button on load
spawn(function()
    updateGamePassButton(vipGamePassButton, 1226490667, "50")
end)

-- Connect purchase button to prompt game pass purchase
vipGamePassButton.MouseButton1Click:Connect(function()
    -- Use the VIP gamepass ID provided by the user
    local gamePassId = 1226490667
    
    -- Check if player already owns the gamepass
    if updateGamePassButton(vipGamePassButton, gamePassId, "50") then
        showNotification("You already own this gamepass!", "warning")
        return
    end
    
    -- Prompt the game pass purchase
    local MarketplaceService = game:GetService("MarketplaceService")
    local success, errorMessage = pcall(function()
        MarketplaceService:PromptGamePassPurchase(player, gamePassId)
    end)
    
    if not success then
        -- Show error notification
        showNotification("Error prompting purchase: " .. tostring(errorMessage), "error")
    end
end)

-- Create Claim a Stand Game Pass frame
local claimStandGamePassFrame = Instance.new("Frame")
claimStandGamePassFrame.Name = "ClaimStandGamePass"
claimStandGamePassFrame.Size = UDim2.new(1, -40, 0, 150)
claimStandGamePassFrame.Position = UDim2.new(0, 20, 0, 1040)
claimStandGamePassFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
claimStandGamePassFrame.BorderSizePixel = 0
claimStandGamePassFrame.Parent = shopScrollFrame

-- Add rounded corners to Claim a Stand Game Pass frame
local claimStandGamePassCorner = Instance.new("UICorner")
claimStandGamePassCorner.CornerRadius = UDim.new(0, 10)
claimStandGamePassCorner.Parent = claimStandGamePassFrame

-- Add Claim a Stand Game Pass icon
local claimStandGamePassIcon = Instance.new("ImageLabel")
claimStandGamePassIcon.Name = "ClaimStandGamePassIcon"
claimStandGamePassIcon.Size = UDim2.new(0, 80, 0, 80)
claimStandGamePassIcon.Position = UDim2.new(0, 20, 0.5, -40)
claimStandGamePassIcon.BackgroundTransparency = 1
claimStandGamePassIcon.Image = "rbxassetid://75058902911414" -- Claim a Stand icon
claimStandGamePassIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
claimStandGamePassIcon.Parent = claimStandGamePassFrame

-- Add Claim a Stand Game Pass title
local claimStandGamePassTitle = Instance.new("TextLabel")
claimStandGamePassTitle.Name = "ClaimStandGamePassTitle"
claimStandGamePassTitle.Size = UDim2.new(0.6, -20, 0, 30)
claimStandGamePassTitle.Position = UDim2.new(0.4, 0, 0, 15)
claimStandGamePassTitle.BackgroundTransparency = 1
claimStandGamePassTitle.Text = "Claim a Stand"
claimStandGamePassTitle.TextColor3 = Color3.fromRGB(100, 200, 255) -- Blue color
claimStandGamePassTitle.TextSize = 18
claimStandGamePassTitle.Font = Enum.Font.GothamBold
claimStandGamePassTitle.TextXAlignment = Enum.TextXAlignment.Left
claimStandGamePassTitle.Parent = claimStandGamePassFrame

-- Add Claim a Stand Game Pass description
local claimStandGamePassDescription = Instance.new("TextLabel")
claimStandGamePassDescription.Name = "ClaimStandGamePassDescription"
claimStandGamePassDescription.Size = UDim2.new(0.6, -20, 0, 70)
claimStandGamePassDescription.Position = UDim2.new(0.4, 0, 0, 45)
claimStandGamePassDescription.BackgroundTransparency = 1
claimStandGamePassDescription.Text = "Claim your own stand to display and showcase your clothing items to other players!"
claimStandGamePassDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
claimStandGamePassDescription.TextSize = 14
claimStandGamePassDescription.TextWrapped = true
claimStandGamePassDescription.Font = Enum.Font.GothamMedium
claimStandGamePassDescription.TextXAlignment = Enum.TextXAlignment.Left
claimStandGamePassDescription.Parent = claimStandGamePassFrame

-- Add purchase button for Claim a Stand Game Pass
local claimStandGamePassButton = Instance.new("TextButton")
claimStandGamePassButton.Name = "ClaimStandGamePassButton"
claimStandGamePassButton.Size = UDim2.new(0, 120, 0, 36)
claimStandGamePassButton.Position = UDim2.new(0.75, -60, 1, -46)
claimStandGamePassButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
claimStandGamePassButton.BorderSizePixel = 0
claimStandGamePassButton.Text = "    90 R$"
claimStandGamePassButton.TextColor3 = Color3.fromRGB(255, 255, 255)
claimStandGamePassButton.TextSize = 16
claimStandGamePassButton.Font = Enum.Font.GothamBold
claimStandGamePassButton.Parent = claimStandGamePassFrame

-- Add Robux icon to the Claim a Stand button
local claimStandRobuxIcon = Instance.new("ImageLabel")
claimStandRobuxIcon.Name = "RobuxIcon"
claimStandRobuxIcon.Size = UDim2.new(0, 20, 0, 20)
claimStandRobuxIcon.Position = UDim2.new(0, 10, 0.5, -10)
claimStandRobuxIcon.BackgroundTransparency = 1
claimStandRobuxIcon.Image = "rbxassetid://1080142088" -- Robux icon
claimStandRobuxIcon.ImageColor3 = Color3.fromRGB(0, 190, 0) -- Green color
claimStandRobuxIcon.Parent = claimStandGamePassButton

-- Add rounded corners to Claim a Stand purchase button
local claimStandGamePassButtonCorner = Instance.new("UICorner")
claimStandGamePassButtonCorner.CornerRadius = UDim.new(0, 8)
claimStandGamePassButtonCorner.Parent = claimStandGamePassButton

-- Add hover and click effects to Claim a Stand Game Pass button
claimStandGamePassButton.MouseEnter:Connect(function()
    if claimStandGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            claimStandGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(60, 200, 60)}
        ):Play()
    end
end)

claimStandGamePassButton.MouseLeave:Connect(function()
    if claimStandGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            claimStandGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(40, 180, 40)}
        ):Play()
    end
end)

claimStandGamePassButton.MouseButton1Down:Connect(function()
    TweenService:Create(
        claimStandGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 116, 0, 34), Position = UDim2.new(0.75, -58, 1, -45)}
    ):Play()
end)

claimStandGamePassButton.MouseButton1Up:Connect(function()
    TweenService:Create(
        claimStandGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 120, 0, 36), Position = UDim2.new(0.75, -60, 1, -46)}
    ):Play()
end)

-- Update Claim a Stand gamepass button on load
spawn(function()
    updateGamePassButton(claimStandGamePassButton, 1233611231, "90")
end)

-- Connect Claim a Stand purchase button to prompt game pass purchase
claimStandGamePassButton.MouseButton1Click:Connect(function()
    local gamePassId = 1233611231
    
    -- Check if player already owns the gamepass
    if updateGamePassButton(claimStandGamePassButton, gamePassId, "90") then
        showNotification("You already own this gamepass!", "warning")
        return
    end
    
    -- Prompt the game pass purchase
    local MarketplaceService = game:GetService("MarketplaceService")
    local success, errorMessage = pcall(function()
        MarketplaceService:PromptGamePassPurchase(player, gamePassId)
    end)
    
    if not success then
        -- Show error notification
        showNotification("Error prompting purchase: " .. tostring(errorMessage), "error")
    end
end)

-- Create Longer Listings Game Pass frame
local longerListingsGamePassFrame = Instance.new("Frame")
longerListingsGamePassFrame.Name = "LongerListingsGamePass"
longerListingsGamePassFrame.Size = UDim2.new(1, -40, 0, 150)
longerListingsGamePassFrame.Position = UDim2.new(0, 20, 0, 1200)
longerListingsGamePassFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
longerListingsGamePassFrame.BorderSizePixel = 0
longerListingsGamePassFrame.Parent = shopScrollFrame

-- Add rounded corners to Longer Listings Game Pass frame
local longerListingsGamePassCorner = Instance.new("UICorner")
longerListingsGamePassCorner.CornerRadius = UDim.new(0, 10)
longerListingsGamePassCorner.Parent = longerListingsGamePassFrame

-- Add Longer Listings Game Pass icon
local longerListingsGamePassIcon = Instance.new("ImageLabel")
longerListingsGamePassIcon.Name = "LongerListingsGamePassIcon"
longerListingsGamePassIcon.Size = UDim2.new(0, 80, 0, 80)
longerListingsGamePassIcon.Position = UDim2.new(0, 20, 0.5, -40)
longerListingsGamePassIcon.BackgroundTransparency = 1
longerListingsGamePassIcon.Image = "rbxassetid://78903033449447" -- Longer Listings icon
longerListingsGamePassIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
longerListingsGamePassIcon.Parent = longerListingsGamePassFrame

-- Add Longer Listings Game Pass title
local longerListingsGamePassTitle = Instance.new("TextLabel")
longerListingsGamePassTitle.Name = "LongerListingsGamePassTitle"
longerListingsGamePassTitle.Size = UDim2.new(0.6, -20, 0, 30)
longerListingsGamePassTitle.Position = UDim2.new(0.4, 0, 0, 15)
longerListingsGamePassTitle.BackgroundTransparency = 1
longerListingsGamePassTitle.Text = "Longer Listings"
longerListingsGamePassTitle.TextColor3 = Color3.fromRGB(255, 150, 50) -- Orange color
longerListingsGamePassTitle.TextSize = 18
longerListingsGamePassTitle.Font = Enum.Font.GothamBold
longerListingsGamePassTitle.TextXAlignment = Enum.TextXAlignment.Left
longerListingsGamePassTitle.Parent = longerListingsGamePassFrame

-- Add Longer Listings Game Pass description
local longerListingsGamePassDescription = Instance.new("TextLabel")
longerListingsGamePassDescription.Name = "LongerListingsGamePassDescription"
longerListingsGamePassDescription.Size = UDim2.new(0.6, -20, 0, 70)
longerListingsGamePassDescription.Position = UDim2.new(0.4, 0, 0, 45)
longerListingsGamePassDescription.BackgroundTransparency = 1
longerListingsGamePassDescription.Text = "Your listings stay active for 1 week instead of 3 days! Perfect for long-term sales."
longerListingsGamePassDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
longerListingsGamePassDescription.TextSize = 14
longerListingsGamePassDescription.TextWrapped = true
longerListingsGamePassDescription.Font = Enum.Font.GothamMedium
longerListingsGamePassDescription.TextXAlignment = Enum.TextXAlignment.Left
longerListingsGamePassDescription.Parent = longerListingsGamePassFrame

-- Add purchase button for Longer Listings Game Pass
local longerListingsGamePassButton = Instance.new("TextButton")
longerListingsGamePassButton.Name = "LongerListingsGamePassButton"
longerListingsGamePassButton.Size = UDim2.new(0, 120, 0, 36)
longerListingsGamePassButton.Position = UDim2.new(0.75, -60, 1, -46)
longerListingsGamePassButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
longerListingsGamePassButton.BorderSizePixel = 0
longerListingsGamePassButton.Text = "    80 R$"
longerListingsGamePassButton.TextColor3 = Color3.fromRGB(255, 255, 255)
longerListingsGamePassButton.TextSize = 16
longerListingsGamePassButton.Font = Enum.Font.GothamBold
longerListingsGamePassButton.Parent = longerListingsGamePassFrame

-- Add Robux icon to the Longer Listings button
local longerListingsRobuxIcon = Instance.new("ImageLabel")
longerListingsRobuxIcon.Name = "RobuxIcon"
longerListingsRobuxIcon.Size = UDim2.new(0, 20, 0, 20)
longerListingsRobuxIcon.Position = UDim2.new(0, 10, 0.5, -10)
longerListingsRobuxIcon.BackgroundTransparency = 1
longerListingsRobuxIcon.Image = "rbxassetid://1080142088" -- Robux icon
longerListingsRobuxIcon.ImageColor3 = Color3.fromRGB(0, 190, 0) -- Green color
longerListingsRobuxIcon.Parent = longerListingsGamePassButton

-- Add rounded corners to Longer Listings purchase button
local longerListingsGamePassButtonCorner = Instance.new("UICorner")
longerListingsGamePassButtonCorner.CornerRadius = UDim.new(0, 8)
longerListingsGamePassButtonCorner.Parent = longerListingsGamePassButton

-- Add hover and click effects to Longer Listings Game Pass button
longerListingsGamePassButton.MouseEnter:Connect(function()
    if longerListingsGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            longerListingsGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(60, 200, 60)}
        ):Play()
    end
end)

longerListingsGamePassButton.MouseLeave:Connect(function()
    if longerListingsGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            longerListingsGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(40, 180, 40)}
        ):Play()
    end
end)

longerListingsGamePassButton.MouseButton1Down:Connect(function()
    TweenService:Create(
        longerListingsGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 116, 0, 34), Position = UDim2.new(0.75, -58, 1, -45)}
    ):Play()
end)

longerListingsGamePassButton.MouseButton1Up:Connect(function()
    TweenService:Create(
        longerListingsGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 120, 0, 36), Position = UDim2.new(0.75, -60, 1, -46)}
    ):Play()
end)

-- Update Longer Listings gamepass button on load
spawn(function()
    updateGamePassButton(longerListingsGamePassButton, 1233852859, "80")
end)

-- Connect Longer Listings purchase button to prompt game pass purchase
longerListingsGamePassButton.MouseButton1Click:Connect(function()
    local gamePassId = 1233852859
    
    -- Check if player already owns the gamepass
    if updateGamePassButton(longerListingsGamePassButton, gamePassId, "80") then
        showNotification("You already own this gamepass!", "warning")
        return
    end
    
    -- Prompt the game pass purchase
    local MarketplaceService = game:GetService("MarketplaceService")
    local success, errorMessage = pcall(function()
        MarketplaceService:PromptGamePassPurchase(player, gamePassId)
    end)
    
    if not success then
        -- Show error notification
        showNotification("Error prompting purchase: " .. tostring(errorMessage), "error")
    end
end)

-- Create See Stats Game Pass frame
local seeStatsGamePassFrame = Instance.new("Frame")
seeStatsGamePassFrame.Name = "SeeStatsGamePass"
seeStatsGamePassFrame.Size = UDim2.new(1, -40, 0, 150)
seeStatsGamePassFrame.Position = UDim2.new(0, 20, 0, 1360)
seeStatsGamePassFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
seeStatsGamePassFrame.BorderSizePixel = 0
seeStatsGamePassFrame.Parent = shopScrollFrame

-- Add rounded corners to See Stats Game Pass frame
local seeStatsGamePassCorner = Instance.new("UICorner")
seeStatsGamePassCorner.CornerRadius = UDim.new(0, 10)
seeStatsGamePassCorner.Parent = seeStatsGamePassFrame

-- Add See Stats Game Pass icon
local seeStatsGamePassIcon = Instance.new("ImageLabel")
seeStatsGamePassIcon.Name = "SeeStatsGamePassIcon"
seeStatsGamePassIcon.Size = UDim2.new(0, 80, 0, 80)
seeStatsGamePassIcon.Position = UDim2.new(0, 20, 0.5, -40)
seeStatsGamePassIcon.BackgroundTransparency = 1
seeStatsGamePassIcon.Image = "rbxassetid://89231981277954" -- See Stats icon
seeStatsGamePassIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
seeStatsGamePassIcon.Parent = seeStatsGamePassFrame

-- Add See Stats Game Pass title
local seeStatsGamePassTitle = Instance.new("TextLabel")
seeStatsGamePassTitle.Name = "SeeStatsGamePassTitle"
seeStatsGamePassTitle.Size = UDim2.new(0.6, -20, 0, 30)
seeStatsGamePassTitle.Position = UDim2.new(0.4, 0, 0, 15)
seeStatsGamePassTitle.BackgroundTransparency = 1
seeStatsGamePassTitle.Text = "See Stats"
seeStatsGamePassTitle.TextColor3 = Color3.fromRGB(150, 255, 150) -- Light green color
seeStatsGamePassTitle.TextSize = 18
seeStatsGamePassTitle.Font = Enum.Font.GothamBold
seeStatsGamePassTitle.TextXAlignment = Enum.TextXAlignment.Left
seeStatsGamePassTitle.Parent = seeStatsGamePassFrame

-- Add See Stats Game Pass description
local seeStatsGamePassDescription = Instance.new("TextLabel")
seeStatsGamePassDescription.Name = "SeeStatsGamePassDescription"
seeStatsGamePassDescription.Size = UDim2.new(0.6, -20, 0, 70)
seeStatsGamePassDescription.Position = UDim2.new(0.4, 0, 0, 45)
seeStatsGamePassDescription.BackgroundTransparency = 1
seeStatsGamePassDescription.Text = "View detailed statistics for your listings including views, try-ons, and more!"
seeStatsGamePassDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
seeStatsGamePassDescription.TextSize = 14
seeStatsGamePassDescription.TextWrapped = true
seeStatsGamePassDescription.Font = Enum.Font.GothamMedium
seeStatsGamePassDescription.TextXAlignment = Enum.TextXAlignment.Left
seeStatsGamePassDescription.Parent = seeStatsGamePassFrame

-- Add purchase button for See Stats Game Pass
local seeStatsGamePassButton = Instance.new("TextButton")
seeStatsGamePassButton.Name = "SeeStatsGamePassButton"
seeStatsGamePassButton.Size = UDim2.new(0, 120, 0, 36)
seeStatsGamePassButton.Position = UDim2.new(0.75, -60, 1, -46)
seeStatsGamePassButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
seeStatsGamePassButton.BorderSizePixel = 0
seeStatsGamePassButton.Text = "    20 R$"
seeStatsGamePassButton.TextColor3 = Color3.fromRGB(255, 255, 255)
seeStatsGamePassButton.TextSize = 16
seeStatsGamePassButton.Font = Enum.Font.GothamBold
seeStatsGamePassButton.Parent = seeStatsGamePassFrame

-- Add Robux icon to the See Stats button
local seeStatsRobuxIcon = Instance.new("ImageLabel")
seeStatsRobuxIcon.Name = "RobuxIcon"
seeStatsRobuxIcon.Size = UDim2.new(0, 20, 0, 20)
seeStatsRobuxIcon.Position = UDim2.new(0, 10, 0.5, -10)
seeStatsRobuxIcon.BackgroundTransparency = 1
seeStatsRobuxIcon.Image = "rbxassetid://1080142088" -- Robux icon
seeStatsRobuxIcon.ImageColor3 = Color3.fromRGB(0, 190, 0) -- Green color
seeStatsRobuxIcon.Parent = seeStatsGamePassButton

-- Add rounded corners to See Stats purchase button
local seeStatsGamePassButtonCorner = Instance.new("UICorner")
seeStatsGamePassButtonCorner.CornerRadius = UDim.new(0, 8)
seeStatsGamePassButtonCorner.Parent = seeStatsGamePassButton

-- Add hover and click effects to See Stats Game Pass button
seeStatsGamePassButton.MouseEnter:Connect(function()
    if seeStatsGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            seeStatsGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(60, 200, 60)}
        ):Play()
    end
end)

seeStatsGamePassButton.MouseLeave:Connect(function()
    if seeStatsGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            seeStatsGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(40, 180, 40)}
        ):Play()
    end
end)

seeStatsGamePassButton.MouseButton1Down:Connect(function()
    TweenService:Create(
        seeStatsGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 116, 0, 34), Position = UDim2.new(0.75, -58, 1, -45)}
    ):Play()
end)

seeStatsGamePassButton.MouseButton1Up:Connect(function()
    TweenService:Create(
        seeStatsGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 120, 0, 36), Position = UDim2.new(0.75, -60, 1, -46)}
    ):Play()
end)

-- Update See Stats gamepass button on load
spawn(function()
    updateGamePassButton(seeStatsGamePassButton, 1234092306, "20")
end)

-- Connect See Stats purchase button to prompt game pass purchase
seeStatsGamePassButton.MouseButton1Click:Connect(function()
    local gamePassId = 1234092306
    
    -- Check if player already owns the gamepass
    if updateGamePassButton(seeStatsGamePassButton, gamePassId, "20") then
        showNotification("You already own this gamepass!", "warning")
        return
    end
    
    -- Prompt the game pass purchase
    local MarketplaceService = game:GetService("MarketplaceService")
    local success, errorMessage = pcall(function()
        MarketplaceService:PromptGamePassPurchase(player, gamePassId)
    end)
    
    if not success then
        -- Show error notification
        showNotification("Error prompting purchase: " .. tostring(errorMessage), "error")
    end
end)

-- Create Boombox Game Pass frame
local boomboxGamePassFrame = Instance.new("Frame")
boomboxGamePassFrame.Name = "BoomboxGamePass"
boomboxGamePassFrame.Size = UDim2.new(1, -40, 0, 150)
boomboxGamePassFrame.Position = UDim2.new(0, 20, 0, 1520)
boomboxGamePassFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
boomboxGamePassFrame.BorderSizePixel = 0
boomboxGamePassFrame.Parent = shopScrollFrame

-- Add rounded corners to Boombox Game Pass frame
local boomboxGamePassCorner = Instance.new("UICorner")
boomboxGamePassCorner.CornerRadius = UDim.new(0, 10)
boomboxGamePassCorner.Parent = boomboxGamePassFrame

-- Add Boombox Game Pass icon
local boomboxGamePassIcon = Instance.new("ImageLabel")
boomboxGamePassIcon.Name = "BoomboxGamePassIcon"
boomboxGamePassIcon.Size = UDim2.new(0, 80, 0, 80)
boomboxGamePassIcon.Position = UDim2.new(0, 20, 0.5, -40)
boomboxGamePassIcon.BackgroundTransparency = 1
boomboxGamePassIcon.Image = "rbxassetid://128375712120168" -- Boombox icon
boomboxGamePassIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
boomboxGamePassIcon.Parent = boomboxGamePassFrame

-- Add Boombox Game Pass title
local boomboxGamePassTitle = Instance.new("TextLabel")
boomboxGamePassTitle.Name = "BoomboxGamePassTitle"
boomboxGamePassTitle.Size = UDim2.new(0.6, -20, 0, 30)
boomboxGamePassTitle.Position = UDim2.new(0.4, 0, 0, 15)
boomboxGamePassTitle.BackgroundTransparency = 1
boomboxGamePassTitle.Text = "Boombox"
boomboxGamePassTitle.TextColor3 = Color3.fromRGB(255, 100, 255) -- Purple color
boomboxGamePassTitle.TextSize = 18
boomboxGamePassTitle.Font = Enum.Font.GothamBold
boomboxGamePassTitle.TextXAlignment = Enum.TextXAlignment.Left
boomboxGamePassTitle.Parent = boomboxGamePassFrame

-- Add Boombox Game Pass description
local boomboxGamePassDescription = Instance.new("TextLabel")
boomboxGamePassDescription.Name = "BoomboxGamePassDescription"
boomboxGamePassDescription.Size = UDim2.new(0.6, -20, 0, 70)
boomboxGamePassDescription.Position = UDim2.new(0.4, 0, 0, 45)
boomboxGamePassDescription.BackgroundTransparency = 1
boomboxGamePassDescription.Text = "Get access to the Boombox tool! Press R to equip/unequip and play music for everyone!"
boomboxGamePassDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
boomboxGamePassDescription.TextSize = 14
boomboxGamePassDescription.TextWrapped = true
boomboxGamePassDescription.Font = Enum.Font.GothamMedium
boomboxGamePassDescription.TextXAlignment = Enum.TextXAlignment.Left
boomboxGamePassDescription.Parent = boomboxGamePassFrame

-- Add purchase button for Boombox Game Pass
local boomboxGamePassButton = Instance.new("TextButton")
boomboxGamePassButton.Name = "BoomboxGamePassButton"
boomboxGamePassButton.Size = UDim2.new(0, 120, 0, 36)
boomboxGamePassButton.Position = UDim2.new(0.75, -60, 1, -46)
boomboxGamePassButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
boomboxGamePassButton.BorderSizePixel = 0
boomboxGamePassButton.Text = "    50 R$"
boomboxGamePassButton.TextColor3 = Color3.fromRGB(255, 255, 255)
boomboxGamePassButton.TextSize = 16
boomboxGamePassButton.Font = Enum.Font.GothamBold
boomboxGamePassButton.Parent = boomboxGamePassFrame

-- Add Robux icon to the Boombox button
local boomboxRobuxIcon = Instance.new("ImageLabel")
boomboxRobuxIcon.Name = "RobuxIcon"
boomboxRobuxIcon.Size = UDim2.new(0, 20, 0, 20)
boomboxRobuxIcon.Position = UDim2.new(0, 10, 0.5, -10)
boomboxRobuxIcon.BackgroundTransparency = 1
boomboxRobuxIcon.Image = "rbxassetid://1080142088" -- Robux icon
boomboxRobuxIcon.ImageColor3 = Color3.fromRGB(0, 190, 0) -- Green color
boomboxRobuxIcon.Parent = boomboxGamePassButton

-- Add rounded corners to Boombox purchase button
local boomboxGamePassButtonCorner = Instance.new("UICorner")
boomboxGamePassButtonCorner.CornerRadius = UDim.new(0, 8)
boomboxGamePassButtonCorner.Parent = boomboxGamePassButton

-- Add hover and click effects to Boombox Game Pass button
boomboxGamePassButton.MouseEnter:Connect(function()
    if boomboxGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            boomboxGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(60, 200, 60)}
        ):Play()
    end
end)

boomboxGamePassButton.MouseLeave:Connect(function()
    if boomboxGamePassButton.Text ~= "You already own this" then
        TweenService:Create(
            boomboxGamePassButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(40, 180, 40)}
        ):Play()
    end
end)

boomboxGamePassButton.MouseButton1Down:Connect(function()
    TweenService:Create(
        boomboxGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 116, 0, 34), Position = UDim2.new(0.75, -58, 1, -45)}
    ):Play()
end)

boomboxGamePassButton.MouseButton1Up:Connect(function()
    TweenService:Create(
        boomboxGamePassButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 120, 0, 36), Position = UDim2.new(0.75, -60, 1, -46)}
    ):Play()
end)

-- Update Boombox gamepass button on load
spawn(function()
    updateGamePassButton(boomboxGamePassButton, 1236848449, "50")
end)

-- Connect Boombox purchase button to prompt game pass purchase
boomboxGamePassButton.MouseButton1Click:Connect(function()
    local gamePassId = 1236848449
    
    -- Check if player already owns the gamepass
    if updateGamePassButton(boomboxGamePassButton, gamePassId, "50") then
        showNotification("You already own this gamepass!", "warning")
        return
    end
    
    -- Prompt the game pass purchase
    local MarketplaceService = game:GetService("MarketplaceService")
    local success, errorMessage = pcall(function()
        MarketplaceService:PromptGamePassPurchase(player, gamePassId)
    end)
    
    if not success then
        -- Show error notification
        showNotification("Error prompting purchase: " .. tostring(errorMessage), "error")
    end
end)

-- Create Buy Coins section divider
local buyCoinseDivider = Instance.new("Frame")
buyCoinseDivider.Name = "BuyCoinsDivider"
buyCoinseDivider.Size = UDim2.new(1, -40, 0, 2)
buyCoinseDivider.Position = UDim2.new(0, 20, 0, 1690)
buyCoinseDivider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
buyCoinseDivider.BorderSizePixel = 0
buyCoinseDivider.Parent = shopScrollFrame

-- Create Buy Coins title
local buyCoinsTitle = Instance.new("TextLabel")
buyCoinsTitle.Name = "BuyCoinsTitle"
buyCoinsTitle.Size = UDim2.new(1, -40, 0, 40)
buyCoinsTitle.Position = UDim2.new(0, 20, 0, 1710)
buyCoinsTitle.BackgroundTransparency = 1
buyCoinsTitle.Text = "Buy Coins"
buyCoinsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
buyCoinsTitle.TextSize = 24
buyCoinsTitle.Font = Enum.Font.GothamBold
buyCoinsTitle.TextXAlignment = Enum.TextXAlignment.Left
buyCoinsTitle.Parent = shopScrollFrame

-- Create Buy Coins description
local buyCoinsDescription = Instance.new("TextLabel")
buyCoinsDescription.Name = "BuyCoinsDescription"
buyCoinsDescription.Size = UDim2.new(1, -40, 0, 30)
buyCoinsDescription.Position = UDim2.new(0, 20, 0, 1750)
buyCoinsDescription.BackgroundTransparency = 1
buyCoinsDescription.Text = "Purchase coins to use in the Clothing Universe!"
buyCoinsDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
buyCoinsDescription.TextSize = 16
buyCoinsDescription.Font = Enum.Font.GothamMedium
buyCoinsDescription.TextXAlignment = Enum.TextXAlignment.Left
buyCoinsDescription.Parent = shopScrollFrame

-- Function to create a coin purchase option
local function createCoinPurchaseOption(amount, price, position, devProductId)
    -- Create container frame
    local optionFrame = Instance.new("Frame")
    optionFrame.Name = "CoinOption_" .. amount
    optionFrame.Size = UDim2.new(0.5, -30, 0, 100)
    optionFrame.Position = position
    optionFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    optionFrame.BorderSizePixel = 0
    optionFrame.Parent = shopScrollFrame
    
    -- Add rounded corners
    local cornerRadius = Instance.new("UICorner")
    cornerRadius.CornerRadius = UDim.new(0, 10)
    cornerRadius.Parent = optionFrame
    
    -- Add coin icon with different image based on amount
    local coinIcon = Instance.new("ImageLabel")
    coinIcon.Name = "CoinIcon"
    coinIcon.Size = UDim2.new(0, 40, 0, 40)
    coinIcon.Position = UDim2.new(0, 15, 0, 15)
    coinIcon.BackgroundTransparency = 1
    
    -- Set image based on amount
    if amount == 500 then
        coinIcon.Image = "rbxassetid://85328818138281"
    elseif amount == 1000 then
        coinIcon.Image = "rbxassetid://105936343493060"
    elseif amount == 10000 then
        coinIcon.Image = "rbxassetid://134912029900977"
    elseif amount == 50000 then
        coinIcon.Image = "rbxassetid://99364418952144"
    end
    
    coinIcon.ImageColor3 = Color3.fromRGB(255, 255, 255) -- Use original color
    coinIcon.Parent = optionFrame
    
    -- Add amount text
    local amountText = Instance.new("TextLabel")
    amountText.Name = "AmountText"
    amountText.Size = UDim2.new(0, 150, 0, 30)
    amountText.Position = UDim2.new(0, 65, 0, 15)
    amountText.BackgroundTransparency = 1
    amountText.Text = tostring(amount) .. " Coins"
    amountText.TextColor3 = Color3.fromRGB(255, 255, 255)
    amountText.TextSize = 18
    amountText.Font = Enum.Font.GothamBold
    amountText.TextXAlignment = Enum.TextXAlignment.Left
    amountText.Parent = optionFrame
    
    -- Add purchase button
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(0, 120, 0, 36)
    purchaseButton.Position = UDim2.new(0.5, -60, 1, -46)
    purchaseButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
    purchaseButton.BorderSizePixel = 0
    purchaseButton.Text = "    " .. price .. " R$"
    purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseButton.TextSize = 16
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.Parent = optionFrame
    
    -- Add Robux icon to the button
    local robuxIcon = Instance.new("ImageLabel")
    robuxIcon.Name = "RobuxIcon"
    robuxIcon.Size = UDim2.new(0, 20, 0, 20)
    robuxIcon.Position = UDim2.new(0, 10, 0.5, -10)
    robuxIcon.BackgroundTransparency = 1
    robuxIcon.Image = "rbxassetid://1080142088" -- Robux icon
    robuxIcon.ImageColor3 = Color3.fromRGB(0, 190, 0) -- Green color
    robuxIcon.Parent = purchaseButton
    
    -- Add rounded corners to button
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = purchaseButton
    
    -- Add hover effects to the button
    purchaseButton.MouseEnter:Connect(function()
        TweenService:Create(
            purchaseButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(80, 140, 220)}
        ):Play()
    end)
    
    purchaseButton.MouseLeave:Connect(function()
        TweenService:Create(
            purchaseButton,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(60, 120, 200)}
        ):Play()
    end)
    
    -- Button-down effect
    purchaseButton.MouseButton1Down:Connect(function()
        TweenService:Create(
            purchaseButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 116, 0, 34), Position = UDim2.new(0.5, -58, 1, -45)}
        ):Play()
    end)
    
    purchaseButton.MouseButton1Up:Connect(function()
        TweenService:Create(
            purchaseButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 120, 0, 36), Position = UDim2.new(0.5, -60, 1, -46)}
        ):Play()
    end)
    
    -- Connect purchase button to prompt developer product purchase
    purchaseButton.MouseButton1Click:Connect(function()
        -- Create or get the purchase dev product event if it doesn't exist
        local purchaseDevProductEvent = ReplicatedStorage:FindFirstChild("PurchaseDevProductEvent")
        if not purchaseDevProductEvent then
            purchaseDevProductEvent = Instance.new("RemoteFunction")
            purchaseDevProductEvent.Name = "PurchaseDevProductEvent"
            purchaseDevProductEvent.Parent = ReplicatedStorage
        end
        
        -- Call server to prompt purchase
        local purchasePrompted = purchaseDevProductEvent:InvokeServer(devProductId, amount .. " Coins")
        
        -- Only show error if we couldn't even prompt the purchase
        if not purchasePrompted then
            showNotification("Unable to start purchase. Please try again later.", Color3.fromRGB(200, 60, 60))
        end
        -- Success notification will be handled by the server after actual purchase confirmation
    end)
    
    return optionFrame
end

-- Create coin purchase options with the provided Dev Product IDs
local coinOption500 = createCoinPurchaseOption(500, "50", UDim2.new(0, 20, 0, 1790), 3293171503) -- 500 Coins dev product
local coinOption1000 = createCoinPurchaseOption(1000, "90", UDim2.new(0.5, 10, 0, 1790), 3293172244) -- 1000 Coins dev product
local coinOption10000 = createCoinPurchaseOption(10000, "750", UDim2.new(0, 20, 0, 1900), 3293172868) -- 10000 Coins dev product
local coinOption50000 = createCoinPurchaseOption(50000, "3200", UDim2.new(0.5, 10, 0, 1900), 3293173356) -- 50000 Coins dev product

-- Update canvas size to include all sections including new gamepasses
shopScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 2020)  -- Increased to accommodate new Boombox gamepass and Buy Coins options

-- Create frame for FAQ tab (initially hidden)
local faqFrame = Instance.new("Frame")
faqFrame.Name = "FAQFrame"
faqFrame.Size = UDim2.new(1, 0, 1, 0)
faqFrame.BackgroundTransparency = 1
faqFrame.Parent = contentsFrame
faqFrame.Visible = false

-- Create label for FAQ tab
local faqLabel = Instance.new("TextLabel")
faqLabel.Name = "FAQLabel"
faqLabel.Size = UDim2.new(1, 0, 0, 30)
faqLabel.Position = UDim2.new(0, 0, 0, 10)
faqLabel.BackgroundTransparency = 1
faqLabel.Text = "Frequently Asked Questions"
faqLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
faqLabel.TextSize = 24
faqLabel.Font = Enum.Font.GothamBold
faqLabel.Parent = faqFrame

-- Create scrolling frame for FAQ content
local faqScrollFrame = Instance.new("ScrollingFrame")
faqScrollFrame.Name = "FAQScrollFrame"
faqScrollFrame.Size = UDim2.new(1, -40, 1, -60)
faqScrollFrame.Position = UDim2.new(0, 20, 0, 50)
faqScrollFrame.BackgroundTransparency = 1
faqScrollFrame.BorderSizePixel = 0
faqScrollFrame.ScrollBarThickness = 8
faqScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
faqScrollFrame.Parent = faqFrame

-- FAQ content
local faqContent = {
    {
        question = "What is Clothing Universe?",
        answer = "Clothing Universe is a game where you can list your clothing which will be added to the clothing universe. NPCs will spawn wearing your clothing, giving other players a chance to try on and buy your items. You can also advertise on billboards to promote your clothing!"
    },
    {
        question = "How do I sell clothing?",
        answer = "Open the NPC Generator and input your shirt ID or pants ID (or both) and press generate. If you can see your clothing on the preview, it's a correct ID. If not, then it's not a valid ID."
    },
    {
        question = "What are Pets and how do they work?",
        answer = "Pets are companions that follow you around the game. You can collect different pets with various rarities. Equip up to 3 pets at once in your inventory. Higher rarity pets are more valuable and sought after."
    },
    {
        question = "How do I level up?",
        answer = "Gain experience (XP) by playing the game, completing activities, opening crates, or buying clothing. Higher levels unlock new features like additional pet slots and exclusive items."
    },
    {
        question = "What happens if my billboard rental expires?",
        answer = "When your billboard rental expires, your advertisement will be removed. You can renew your rental before it expires to keep your ad displayed. Check the 'My Billboards' section to manage your rentals."
    }
}

-- Create FAQ items
local yPosition = 10
for i, faq in ipairs(faqContent) do
    -- Question frame
    local questionFrame = Instance.new("Frame")
    questionFrame.Name = "Question" .. i
    questionFrame.Size = UDim2.new(1, -20, 0, 40)
    questionFrame.Position = UDim2.new(0, 10, 0, yPosition)
    questionFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    questionFrame.BorderSizePixel = 0
    questionFrame.Parent = faqScrollFrame
    
    local questionCorner = Instance.new("UICorner")
    questionCorner.CornerRadius = UDim.new(0, 8)
    questionCorner.Parent = questionFrame
    
    -- Question text
    local questionLabel = Instance.new("TextLabel")
    questionLabel.Name = "QuestionLabel"
    questionLabel.Size = UDim2.new(1, -20, 1, 0)
    questionLabel.Position = UDim2.new(0, 10, 0, 0)
    questionLabel.BackgroundTransparency = 1
    questionLabel.Text = "Q: " .. faq.question
    questionLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    questionLabel.TextSize = 16
    questionLabel.Font = Enum.Font.GothamSemibold
    questionLabel.TextXAlignment = Enum.TextXAlignment.Left
    questionLabel.TextYAlignment = Enum.TextYAlignment.Center
    questionLabel.Parent = questionFrame
    
    yPosition = yPosition + 50
    
    -- Answer frame
    local answerFrame = Instance.new("Frame")
    answerFrame.Name = "Answer" .. i
    answerFrame.Size = UDim2.new(1, -20, 0, 80)
    answerFrame.Position = UDim2.new(0, 10, 0, yPosition)
    answerFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    answerFrame.BorderSizePixel = 0
    answerFrame.Parent = faqScrollFrame
    
    local answerCorner = Instance.new("UICorner")
    answerCorner.CornerRadius = UDim.new(0, 8)
    answerCorner.Parent = answerFrame
    
    -- Answer text
    local answerLabel = Instance.new("TextLabel")
    answerLabel.Name = "AnswerLabel"
    answerLabel.Size = UDim2.new(1, -20, 1, -10)
    answerLabel.Position = UDim2.new(0, 10, 0, 5)
    answerLabel.BackgroundTransparency = 1
    answerLabel.Text = "A: " .. faq.answer
    answerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    answerLabel.TextSize = 14
    answerLabel.Font = Enum.Font.GothamMedium
    answerLabel.TextXAlignment = Enum.TextXAlignment.Left
    answerLabel.TextYAlignment = Enum.TextYAlignment.Top
    answerLabel.TextWrapped = true
    answerLabel.Parent = answerFrame
    
    yPosition = yPosition + 100
end

-- Set canvas size for scrolling
faqScrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPosition + 20)

-- Create frame for Inventory tab (initially hidden)
local inventoryFrame = Instance.new("Frame")
inventoryFrame.Name = "InventoryFrame"
inventoryFrame.Size = UDim2.new(1, 0, 1, 0)
inventoryFrame.BackgroundTransparency = 1
inventoryFrame.Parent = contentsFrame
inventoryFrame.Visible = false

-- Create equipped pets section
local equippedPetsFrame = Instance.new("Frame")
equippedPetsFrame.Name = "EquippedPetsFrame"
equippedPetsFrame.Size = UDim2.new(1, -40, 0, 190)
equippedPetsFrame.Position = UDim2.new(0, 20, 0, 10)
equippedPetsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
equippedPetsFrame.BorderSizePixel = 0
equippedPetsFrame.Parent = inventoryFrame

-- Add rounded corners to equipped pets frame
local equippedCorner = Instance.new("UICorner")
equippedCorner.CornerRadius = UDim.new(0, 10)
equippedCorner.Parent = equippedPetsFrame

-- Create title for equipped pets
local equippedTitle = Instance.new("TextLabel")
equippedTitle.Name = "EquippedTitle"
equippedTitle.Size = UDim2.new(1, -20, 0, 40)
equippedTitle.Position = UDim2.new(0, 10, 0, 10)
equippedTitle.BackgroundTransparency = 1
equippedTitle.Text = "Equipped Pets"
equippedTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
equippedTitle.TextSize = 24
equippedTitle.Font = Enum.Font.GothamBold
equippedTitle.TextXAlignment = Enum.TextXAlignment.Left
equippedTitle.Parent = equippedPetsFrame

-- Create description text
local equippedDescription = Instance.new("TextLabel")
equippedDescription.Name = "EquippedDescription"
equippedDescription.Size = UDim2.new(1, -20, 0, 20)
equippedDescription.Position = UDim2.new(0, 10, 0, 45)
equippedDescription.BackgroundTransparency = 1
equippedDescription.Text = "Pets that follow you around"
equippedDescription.TextColor3 = Color3.fromRGB(200, 200, 200)
equippedDescription.TextSize = 16
equippedDescription.Font = Enum.Font.GothamMedium
equippedDescription.TextXAlignment = Enum.TextXAlignment.Left
equippedDescription.Parent = equippedPetsFrame

-- Create the 3 pet slots
local slotSize = 100
local slotPadding = 20
local totalWidth = (slotSize * 3) + (slotPadding * 2)
local startX = (equippedPetsFrame.Size.X.Offset - totalWidth) / 2

-- Function to create a pet slot
local function createPetSlot(position, slotNumber, levelReq)
    local slotFrame = Instance.new("Frame")
    slotFrame.Name = "Slot" .. slotNumber
    slotFrame.Size = UDim2.new(0, slotSize, 0, slotSize)
    slotFrame.Position = position
    slotFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    slotFrame.BorderSizePixel = 0
    slotFrame.Parent = equippedPetsFrame
    
    -- Debug text to identify this slot
    print("Creating Slot", slotNumber, " - Reference:", slotFrame)
    
    -- Add explicit ID to the slot
    slotFrame:SetAttribute("ActualSlotNumber", slotNumber)
    
    -- Add rounded corners
    local slotCorner = Instance.new("UICorner")
    slotCorner.CornerRadius = UDim.new(0, 8)
    slotCorner.Parent = slotFrame
    
    -- Add placeholder icon for empty slot
    local placeholderIcon = Instance.new("ImageLabel")
    placeholderIcon.Name = "PlaceholderIcon"
    placeholderIcon.Size = UDim2.new(0, 60, 0, 60)
    placeholderIcon.Position = UDim2.new(0.5, -30, 0.3, -20)
    placeholderIcon.BackgroundTransparency = 1
    placeholderIcon.Image = "rbxassetid://3970039622" -- Generic pet icon
    placeholderIcon.ImageTransparency = 0.5
    placeholderIcon.Parent = slotFrame
    
    -- Add slot number
    local slotLabel = Instance.new("TextLabel")
    slotLabel.Name = "SlotLabel"
    slotLabel.Size = UDim2.new(1, 0, 0, 20)
    slotLabel.Position = UDim2.new(0, 0, 0.7, 0)
    slotLabel.BackgroundTransparency = 1
    slotLabel.Text = "Slot " .. slotNumber
    slotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    slotLabel.TextSize = 16
    slotLabel.Font = Enum.Font.GothamMedium
    slotLabel.Parent = slotFrame
    
    -- Check player's current level - improved check to handle exact level matching
    local playerMeetsRequirement = true -- Default to true for slot 1
    
    -- Only check for level requirements on slots 2 and 3
    if slotNumber > 1 and levelReq > 0 then
        playerMeetsRequirement = false -- Set to false until we verify
        
        -- Get player's level
        local leaderstats = player:FindFirstChild("leaderstats")
        local playerLevel = 0
        if leaderstats and leaderstats:FindFirstChild("Level") then
            playerLevel = leaderstats.Level.Value
            
            -- Check if player meets the requirement (now using >= instead of just comparing slot numbers)
            if playerLevel >= levelReq then
                playerMeetsRequirement = true
            end
        end
    end
    
    -- Only add level requirement if the player doesn't meet it
    if slotNumber > 1 and levelReq > 0 and not playerMeetsRequirement then
        local levelLabel = Instance.new("TextLabel")
        levelLabel.Name = "LevelLabel"
        levelLabel.Size = UDim2.new(1, 0, 0, 20)
        levelLabel.Position = UDim2.new(0, 0, 0.85, 0)
        levelLabel.BackgroundTransparency = 1
        levelLabel.Text = "Requires Level " .. levelReq
        levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        levelLabel.TextSize = 12
        levelLabel.Font = Enum.Font.GothamMedium
        levelLabel.Parent = slotFrame
    end
    
    -- Make slot clickable
    local button = Instance.new("TextButton")
    button.Name = "SlotButton"
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.Parent = slotFrame
    
    -- Create a basic empty ViewportFrame placeholder for each slot 
    -- to ensure all slots have a ViewportFrame container
    local placeholderPreview = Instance.new("ViewportFrame")
    placeholderPreview.Name = "PlaceholderPreview"
    placeholderPreview.Size = UDim2.new(0.8, 0, 0.5, 0)
    placeholderPreview.Position = UDim2.new(0.1, 0, 0.1, 0)
    placeholderPreview.BackgroundTransparency = 0.7
    placeholderPreview.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    placeholderPreview.Visible = false -- Hide by default
    placeholderPreview.Parent = slotFrame
    
    -- Add debug attribute
    button:SetAttribute("SlotNumber", slotNumber)
    
    return slotFrame, button
end

-- Create the 3 slots with fixed, absolute positioning to ensure correct alignment
local slot1, slot1Button = createPetSlot(UDim2.new(0, 50, 0, 70), 1, 0)
slot1:SetAttribute("SlotNumber", 1) -- Add attribute to identify slot

local slot2, slot2Button = createPetSlot(UDim2.new(0, 170, 0, 70), 2, 5)
slot2:SetAttribute("SlotNumber", 2) -- Add attribute to identify slot

local slot3, slot3Button = createPetSlot(UDim2.new(0, 290, 0, 70), 3, 10)
slot3:SetAttribute("SlotNumber", 3) -- Add attribute to identify slot

-- Print debug message to verify slots were created properly
print("Pet slots created: Slot1:", slot1, "Slot2:", slot2, "Slot3:", slot3)

-- Immediately check player level and hide level requirements based on player level
local leaderstats = player:FindFirstChild("leaderstats")
if leaderstats and leaderstats:FindFirstChild("Level") then
    local playerLevel = leaderstats.Level.Value
    
    -- Check for slot 2 (requires level 5)
    if playerLevel >= 5 then
        local levelLabel = slot2:FindFirstChild("LevelLabel")
        if levelLabel then
            levelLabel:Destroy()
        end
    end
    
    -- Check for slot 3 (requires level 10)
    if playerLevel >= 10 then
        local levelLabel = slot3:FindFirstChild("LevelLabel")
        if levelLabel then
            levelLabel:Destroy()
        end
    end
end

-- Create scrolling frame for pets inventory
local petsScrollFrame = Instance.new("ScrollingFrame")
petsScrollFrame.Name = "PetsScrollFrame"
petsScrollFrame.Size = UDim2.new(1, 0, 1, -210) -- Make room for equipped pets section
petsScrollFrame.Position = UDim2.new(0, 0, 0, 210)
petsScrollFrame.BackgroundTransparency = 1
petsScrollFrame.BorderSizePixel = 0
petsScrollFrame.ScrollBarThickness = 6
petsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80)
petsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
petsScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
petsScrollFrame.Parent = inventoryFrame

-- Create title for pets inventory
local petsTitle = Instance.new("TextLabel")
petsTitle.Name = "PetsTitle"
petsTitle.Size = UDim2.new(1, -40, 0, 40)
petsTitle.Position = UDim2.new(0, 20, 0, 10)
petsTitle.BackgroundTransparency = 1
petsTitle.Text = "My Pets"
petsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
petsTitle.TextSize = 24
petsTitle.Font = Enum.Font.GothamBold
petsTitle.TextXAlignment = Enum.TextXAlignment.Left
petsTitle.Parent = petsScrollFrame

-- Create pets count display
local petsCount = Instance.new("TextLabel")
petsCount.Name = "PetsCount"
petsCount.Size = UDim2.new(1, -40, 0, 30)
petsCount.Position = UDim2.new(0, 20, 0, 50)
petsCount.BackgroundTransparency = 1
petsCount.Text = "Loading pets..."
petsCount.TextColor3 = Color3.fromRGB(200, 200, 200)
petsCount.TextSize = 16
petsCount.Font = Enum.Font.GothamMedium
petsCount.TextXAlignment = Enum.TextXAlignment.Left
petsCount.Parent = petsScrollFrame

-- Create or get the get pets data event
local getPetsDataEvent = ReplicatedStorage:FindFirstChild("GetPetsDataEvent")
if not getPetsDataEvent then
    getPetsDataEvent = Instance.new("RemoteFunction")
    getPetsDataEvent.Name = "GetPetsDataEvent"
    getPetsDataEvent.Parent = ReplicatedStorage
end

-- Get equip/unequip events
local getEquippedPetsEvent = ReplicatedStorage:FindFirstChild("GetEquippedPetsEvent")
if not getEquippedPetsEvent then
    getEquippedPetsEvent = Instance.new("RemoteFunction")
    getEquippedPetsEvent.Name = "GetEquippedPetsEvent"
    getEquippedPetsEvent.Parent = ReplicatedStorage
end

local equipPetEvent = ReplicatedStorage:FindFirstChild("EquipPetEvent")
if not equipPetEvent then
    equipPetEvent = Instance.new("RemoteFunction")
    equipPetEvent.Name = "EquipPetEvent"
    equipPetEvent.Parent = ReplicatedStorage
end

local unequipPetEvent = ReplicatedStorage:FindFirstChild("UnequipPetEvent")
if not unequipPetEvent then
    unequipPetEvent = Instance.new("RemoteFunction")
    unequipPetEvent.Name = "UnequipPetEvent"
    unequipPetEvent.Parent = ReplicatedStorage
end

-- Variables to store selected pet for equipping
local selectedPetForEquip = nil
local petsData = {}
local equippedPetSlots = {}

-- Function to create a pet card UI
local function createPetCard(pet, position)
    -- Create pet container
    local petFrame = Instance.new("Frame")
    petFrame.Name = "Pet_" .. pet.id
    petFrame.Size = UDim2.new(1, -40, 0, 120)
    petFrame.Position = position
    petFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    petFrame.BorderSizePixel = 0
    petFrame.Parent = petsScrollFrame
    
    -- Add rounded corners
    local petCorner = Instance.new("UICorner")
    petCorner.CornerRadius = UDim.new(0, 10)
    petCorner.Parent = petFrame
    
    -- Add pet preview
    local previewFrame = Instance.new("ViewportFrame")
    previewFrame.Name = "PreviewFrame"
    previewFrame.Size = UDim2.new(0, 80, 0, 80)
    previewFrame.Position = UDim2.new(0, 20, 0.5, -40)
    previewFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    previewFrame.BackgroundTransparency = 0.2
    previewFrame.Parent = petFrame
    
    -- Add rounded corners to preview
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 6)
    previewCorner.Parent = previewFrame
    
    -- Setup pet preview in the viewport
    local camera = Instance.new("Camera")
    camera.FieldOfView = 70
    previewFrame.CurrentCamera = camera
    camera.Parent = previewFrame
    
    -- Get the pet model from ReplicatedStorage
    local success, petModel = pcall(function()
        local path = "Pets/" .. pet.rarity
        local folder = ReplicatedStorage
        for _, pathPart in ipairs(string.split(path, "/")) do
            folder = folder:FindFirstChild(pathPart)
            if not folder then return nil end
        end
        
        return folder:FindFirstChild(pet.name)
    end)
    
    -- If we found the pet model, clone it for display
    if success and petModel then
        local displayModel = petModel:Clone()
        displayModel.Parent = previewFrame
        
        -- Position the camera
        if displayModel:IsA("Model") then
            local primaryPart = displayModel.PrimaryPart or displayModel:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                camera.CFrame = CFrame.new(primaryPart.Position + Vector3.new(0, 0, -3), primaryPart.Position)
            end
        elseif displayModel:IsA("MeshPart") or displayModel:IsA("BasePart") then
            camera.CFrame = CFrame.new(displayModel.Position + Vector3.new(0, 0, -3), displayModel.Position)
        end
    end
    
    -- Add pet name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(0.6, -20, 0, 25)
    nameLabel.Position = UDim2.new(0.4, 0, 0, 15)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = pet.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 18
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = petFrame
    
    -- Add pet rarity
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Name = "RarityLabel"
    rarityLabel.Size = UDim2.new(0.6, -20, 0, 20)
    rarityLabel.Position = UDim2.new(0.4, 0, 0, 45)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = "Rarity: " .. pet.rarity
    rarityLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    rarityLabel.TextSize = 14
    rarityLabel.Font = Enum.Font.GothamMedium
    rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
    rarityLabel.Parent = petFrame
    
    -- Add equip button
    local equipButton = Instance.new("TextButton")
    equipButton.Name = "EquipButton"
    equipButton.Size = UDim2.new(0, 80, 0, 30)
    equipButton.Position = UDim2.new(1, -100, 0.5, 0)
    equipButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    equipButton.BorderSizePixel = 0
    equipButton.Text = "Equip"
    equipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    equipButton.TextSize = 14
    equipButton.Font = Enum.Font.GothamSemibold
    equipButton.Parent = petFrame
    
    -- Add rounded corners to button
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = equipButton
    
    -- If pet is already equipped, show visually
    local isEquipped = false
    if pet and pet.id then
        -- Ensure we have the latest data before checking
        local slotSuccess, slotInfo = pcall(function()
            return getEquippedPetsEvent:InvokeServer()
        end)
        
        if slotSuccess and slotInfo then
            -- Update our local copy
            equippedPetSlots = slotInfo
            
            if UI_DEBUG then
                debugPrint("Fresh equip check for pet", pet.name, "ID:", pet.id)
            end
            
            -- Now check all slots for this pet
            for slotName, slotInfo in pairs(equippedPetSlots) do
                if slotInfo and slotInfo.petId == pet.id then
                    isEquipped = true
                    equipButton.Text = "Equipped"
                    equipButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
                    
                    if UI_DEBUG then
                        debugPrint("Pet", pet.name, "is equipped in", slotName)
                    end
                    break
                end
            end
        end
    end
    
    -- Connect equip button
    equipButton.MouseButton1Click:Connect(function()
        if isEquipped then
            -- Already equipped, show message
            local notification = screenGui:FindFirstChild("Notification")
            if notification then
                notification.Text = "This pet is already equipped. Unequip it from a slot first."
                notification.Visible = true
                task.delay(3, function()
                    notification.Visible = false
                end)
            end
        else
            -- Select this pet for equipping
            selectedPetForEquip = pet.id
            
            -- Show notification to select a slot
            local notification = screenGui:FindFirstChild("Notification")
            if notification then
                notification.Text = "Select a slot to equip this pet."
                notification.Visible = true
                task.delay(3, function()
                    notification.Visible = false
                end)
            end
        end
    end)
    
    return petFrame
end

-- Function to update pets display
local function updatePetsDisplay()
    if UI_DEBUG then
        debugPrint("Updating pets display")
    end
    
    -- Clear existing pets
    for _, child in ipairs(petsScrollFrame:GetChildren()) do
        if child.Name:match("^Pet_") then
            child:Destroy()
        end
    end
    
    -- Try to get pets data from server
    local success, fetchedPetsData = pcall(function()
        return getPetsDataEvent:InvokeServer()
    end)
    
    if not success or not fetchedPetsData then
        petsCount.Text = "Failed to load pets. Please try again later."
        return
    end
    
    -- Store pets data
    petsData = fetchedPetsData
    
    if UI_DEBUG then
        debugPrint("Fetched", #petsData, "pets from server")
    end
    
    -- Always get the latest equipped slots data when updating pets display
    local slotInfo
    local slotSuccess, slotError = pcall(function()
        slotInfo = getEquippedPetsEvent:InvokeServer()
        return true
    end)
    
    if slotSuccess and slotInfo then
        if UI_DEBUG then
            debugPrint("Updated equipped slots data:")
            for slotName, info in pairs(slotInfo) do
                debugPrint("  " .. slotName .. ":", info.petId or "empty", "unlocked:", info.unlocked)
            end
        end
        equippedPetSlots = slotInfo
    else
        warn("Could not get equipped pet slots: " .. (slotError or "unknown error"))
        -- Use existing data if we can't get new data
        if not equippedPetSlots then
            equippedPetSlots = {}
        end
    end
    
    -- Update count display
    petsCount.Text = #petsData .. " / 50 Pets"
    
    -- Update equipped slots with error handling
    pcall(function()
        updateEquippedSlots()
    end)
    
    -- Create pet cards
    local yOffset = 90 -- Start below the title and count
    for i, pet in ipairs(petsData) do
        local petCard = createPetCard(pet, UDim2.new(0, 20, 0, yOffset))
        yOffset = yOffset + 130 -- Add spacing between cards
    end
    
    -- Show "No pets" message if no pets
    if #petsData == 0 then
        local noPetsLabel = Instance.new("TextLabel")
        noPetsLabel.Name = "NoPetsLabel"
        noPetsLabel.Size = UDim2.new(1, -40, 0, 50)
        noPetsLabel.Position = UDim2.new(0, 20, 0, 90)
        noPetsLabel.BackgroundTransparency = 1
        noPetsLabel.Text = "You don't have any pets yet. Visit the Shop to get some!"
        noPetsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        noPetsLabel.TextSize = 16
        noPetsLabel.Font = Enum.Font.GothamMedium
        noPetsLabel.Parent = petsScrollFrame
    end
end

-- Function to update equipped pet slots display
local function updateEquippedSlots()
    if UI_DEBUG then
        debugPrint("Updating equipped slots UI")
    end
    
    -- First make sure we have slot references before continuing
    if not slot1 or not slot2 or not slot3 or not slot1Button or not slot2Button or not slot3Button then
        warn("Slot references missing - cannot update equipped slots UI")
        return
    end
    
    -- Use existing slot data if we already have it
    if not equippedPetSlots then
        -- Try to get equipped pets from server
        local success, slotInfo = pcall(function()
            return getEquippedPetsEvent:InvokeServer()
        end)
        
        if not success or not slotInfo then
            warn("Failed to get equipped pets")
            -- Initialize empty slots if we have no data
            equippedPetSlots = {
                slot1 = { petId = nil, unlocked = true },
                slot2 = { petId = nil, unlocked = false },
                slot3 = { petId = nil, unlocked = false }
            }
        else
            equippedPetSlots = slotInfo
        end
    end
    
    -- For debugging, show what data we have
    if UI_DEBUG then
        debugPrint("Current slot info:")
        for slotName, info in pairs(equippedPetSlots) do
            if info then
                debugPrint("  " .. slotName .. ":", info.petId or "empty", "unlocked:", info.unlocked or false)
            end
        end
    end
    
    -- Update slot displays
    local slots = {
        {slot = slot1, button = slot1Button, slotNumber = 1, info = equippedPetSlots.slot1 or { petId = nil, unlocked = true }},
        {slot = slot2, button = slot2Button, slotNumber = 2, info = equippedPetSlots.slot2 or { petId = nil, unlocked = false }},
        {slot = slot3, button = slot3Button, slotNumber = 3, info = equippedPetSlots.slot3 or { petId = nil, unlocked = false }}
    }
    
    -- Debug print to verify slots
    print("Updating equipped slots - Slot references:", 
          "Slot1:", slot1, 
          "Slot2:", slot2, 
          "Slot3:", slot3)
    
    for i, slotData in ipairs(slots) do
        print("Processing slot", i, "- Reference:", slotData.slot, "Button:", slotData.button)
        
        -- Skip if any reference is nil
        if not slotData.slot or not slotData.button then
            warn("Slot reference is nil, skipping slot " .. slotData.slotNumber)
            continue
        end
        
        -- Add an identifier attribute to help with debugging
        slotData.slot:SetAttribute("ProcessedInLoop", true)
        
        -- Clean up existing elements first
        local placeholderIcon = slotData.slot:FindFirstChild("PlaceholderIcon")
        if placeholderIcon then
            placeholderIcon.Visible = not (slotData.info and slotData.info.petId)
        end
        
        -- Remove existing pet displays if present
        for _, child in pairs(slotData.slot:GetChildren()) do
            if child.Name == "PetImage" or child.Name == "PetPreview" or child.Name == "PetNameLabel" then
                -- Disconnect any rotation connections first
                if child:GetAttribute("RotationConnection") then
                    child:SetAttribute("RotationConnection", false)
                end
                child:Destroy()
            end
        end
        
        -- Find equipped pet data
        if slotData.info and slotData.info.petId and slotData.info.petId ~= "" then
            local petId = slotData.info.petId
            
            if UI_DEBUG then
                debugPrint("Slot", slotData.slotNumber, "has pet ID:", petId)
            end
            
            -- Look for pet data in petsData
            local foundPet = false
            local petData = nil
            
            for _, pet in ipairs(petsData) do
                if pet.id == petId then
                    petData = pet
                    foundPet = true
                    break
                end
            end
            
            if foundPet and petData then
                local petName = petData.name
                local petRarity = petData.rarity
                    
                    if UI_DEBUG then
                    debugPrint("Found pet in slot", slotData.slotNumber, ":", petName, "Rarity:", petRarity)
                end
                
                -- Create a viewport frame to show actual pet preview
                local petPreview = Instance.new("ViewportFrame")
                petPreview.Name = "PetPreview"
                petPreview.Size = UDim2.new(0.8, 0, 0.7, 0)
                petPreview.Position = UDim2.new(0.1, 0, 0.05, 0)
                petPreview.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                petPreview.BackgroundTransparency = 0.2
                petPreview.Parent = slotData.slot
                
                -- Add rounded corners to preview
                local previewCorner = Instance.new("UICorner")
                previewCorner.CornerRadius = UDim.new(0, 6)
                previewCorner.Parent = petPreview
                
                -- Setup pet preview in the viewport
                local camera = Instance.new("Camera")
                camera.FieldOfView = 60
                petPreview.CurrentCamera = camera
                camera.Parent = petPreview
                
                -- Add a light to improve visibility
                local light = Instance.new("PointLight")
                light.Brightness = 2
                light.Range = 10
                light.Parent = petPreview
                
                -- Try to get the pet model from ReplicatedStorage
                local petModel = nil
                pcall(function()
                    -- Create a proper path to find the pet model
                    local petsFolder = ReplicatedStorage:FindFirstChild("Pets")
                    if petsFolder then
                        local rarityFolder = petsFolder:FindFirstChild(petRarity)
                        if rarityFolder then
                            petModel = rarityFolder:FindFirstChild(petName)
                        end
                    end
                end)
                
                -- If we found the pet model, clone it for display
                if petModel then
                    local displayModel = petModel:Clone()
                    displayModel.Parent = petPreview
                    
                    -- Position the camera
                    local targetPart = nil
                    if displayModel:IsA("Model") then
                        targetPart = displayModel.PrimaryPart or displayModel:FindFirstChildWhichIsA("BasePart")
                        
                        -- If no primary part, try other methods to find a good part
                        if not targetPart then
                            local allParts = {}
                            for _, part in pairs(displayModel:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    table.insert(allParts, part)
                                end
                            end
                            
                            if #allParts > 0 then
                                targetPart = allParts[1]
                            end
                        end
                    elseif displayModel:IsA("BasePart") then
                        targetPart = displayModel
                    end
                    
                    -- Position the camera
                    if targetPart then
                        -- Create a CFrame that focuses on the pet model
                        local modelSize = targetPart.Size.Magnitude
                        local modelCenter = targetPart.Position
                        -- Reduce distance to zoom in closer and position camera on opposite side
                        local distance = modelSize * 1.3
                        
                        -- Position camera to look at model from the opposite angle (front view)
                        camera.CFrame = CFrame.new(modelCenter - Vector3.new(0, 0, distance), modelCenter)
                        
                        -- Create a folder to hold animation parts
                        local animationFolder = Instance.new("Folder")
                        animationFolder.Name = "AnimationParts" 
                        animationFolder.Parent = petPreview
                        
                        -- Create an anchor part for rotation
                        local anchor = Instance.new("Part")
                        anchor.Name = "RotationAnchor"
                        anchor.Anchored = true
                        anchor.CanCollide = false
                        anchor.Transparency = 1
                        anchor.Size = Vector3.new(0.1, 0.1, 0.1)
                        anchor.Position = modelCenter
                        anchor.Parent = animationFolder
                        
                        -- Weld the model to the anchor
                        if displayModel:IsA("Model") then
                            -- Create a weld for the model
                            local weld = Instance.new("WeldConstraint")
                            weld.Part0 = anchor
                            weld.Part1 = targetPart
                            weld.Parent = anchor
                        elseif displayModel:IsA("BasePart") then
                            -- Just set the CFrame
                            displayModel.Anchored = true
                        end
                        
                        -- Set up rotation animation
                        local runServiceInstance = getService("RunService")
                        if runServiceInstance then
                            local rotation = 0
                            local rotationConnection = runServiceInstance.RenderStepped:Connect(function(deltaTime)
                                if petPreview and petPreview.Parent and anchor and anchor.Parent then
                                    rotation = rotation + deltaTime * 0.5
                                    anchor.CFrame = CFrame.new(modelCenter) * CFrame.Angles(0, rotation, 0)
                                else
                                    pcall(function()
                                        rotationConnection:Disconnect()
                                    end)
                                end
                            end)
                            
                            -- Store the connection for cleanup
                            petPreview:SetAttribute("RotationConnection", true)
                            petPreview.AncestryChanged:Connect(function(_, parent)
                                if not parent then
                                    rotationConnection:Disconnect()
                                end
                            end)
                        end
                    end
                else
                    -- If model not found, show placeholder
                    local sphere = Instance.new("Part")
                    sphere.Shape = Enum.PartType.Ball
                    sphere.Size = Vector3.new(2, 2, 2)
                    sphere.Position = Vector3.new(0, 0, 0)
                    sphere.Anchored = true
                    sphere.CanCollide = false
                    sphere.Material = Enum.Material.Neon
                    sphere.Color = Color3.fromRGB(100, 100, 255)
                    sphere.Parent = petPreview
                    
                    -- Position camera
                    camera.CFrame = CFrame.new(Vector3.new(0, 0, -3), Vector3.new(0, 0, 0))
                    
                    -- Add rotation animation
                    local runServiceInstance = getService("RunService")
                    if runServiceInstance then
                        local rotation = 0
                        local rotationConnection = runServiceInstance.RenderStepped:Connect(function(deltaTime)
                            if petPreview and petPreview.Parent and sphere and sphere.Parent then
                                rotation = rotation + deltaTime * 0.5
                                sphere.CFrame = CFrame.new(Vector3.new(0, 0, 0)) * CFrame.Angles(0, rotation, 0)
                            else
                                pcall(function()
                                    rotationConnection:Disconnect()
                                end)
                            end
                        end)
                        
                        -- Store the connection for cleanup
                        petPreview:SetAttribute("RotationConnection", true)
                        petPreview.AncestryChanged:Connect(function(_, parent)
                            if not parent then
                                pcall(function()
                                    rotationConnection:Disconnect()
                                end)
                            end
                        end)
                    end
                end
                
                -- Add pet name label below viewport
                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Name = "PetNameLabel"
                nameLabel.Size = UDim2.new(0.8, 0, 0.2, 0)
                nameLabel.Position = UDim2.new(0.1, 0, 0.8, 0)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Text = petName
                    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLabel.Font = Enum.Font.GothamBold
                    nameLabel.TextSize = 12
                    nameLabel.TextWrapped = true
                nameLabel.Parent = slotData.slot
                    
                    -- Hide placeholder
                    if placeholderIcon then
                        placeholderIcon.Visible = false
                    end
            else
                -- Create a viewport frame for unknown pet
                local petPreview = Instance.new("ViewportFrame")
                petPreview.Name = "PetPreview"
                petPreview.Size = UDim2.new(0.8, 0, 0.7, 0)
                petPreview.Position = UDim2.new(0.1, 0, 0.05, 0)
                petPreview.BackgroundColor3 = Color3.fromRGB(150, 80, 80)
                petPreview.BackgroundTransparency = 0.2
                petPreview.Parent = slotData.slot
                
                -- Add rounded corners
                local previewCorner = Instance.new("UICorner")
                previewCorner.CornerRadius = UDim.new(0, 6)
                previewCorner.Parent = petPreview
                
                -- Setup camera
                local camera = Instance.new("Camera")
                camera.FieldOfView = 70
                petPreview.CurrentCamera = camera
                camera.Parent = petPreview
                
                -- Add a placeholder question mark icon for unknown pets
                local questionMark = Instance.new("TextLabel")
                questionMark.Name = "QuestionMark"
                questionMark.Size = UDim2.new(1, 0, 1, 0)
                questionMark.BackgroundTransparency = 1
                questionMark.Text = "?"
                questionMark.TextColor3 = Color3.fromRGB(255, 255, 255)
                questionMark.Font = Enum.Font.GothamBold
                questionMark.TextSize = 50
                questionMark.Parent = petPreview
                
                -- Add rotation animation to question mark for visual interest
                local runServiceInstance = getService("RunService")
                if runServiceInstance then
                    local rotation = 0
                    local rotationConnection
                    
                    -- Use pcall to ensure no errors
                    pcall(function()
                        rotationConnection = runServiceInstance.RenderStepped:Connect(function(deltaTime)
                            if petPreview and petPreview.Parent and questionMark and questionMark.Parent then
                                rotation = rotation + deltaTime * 0.2
                                questionMark.Rotation = math.sin(rotation) * 10
                            else
                                if rotationConnection then
                                    rotationConnection:Disconnect()
                end
            end
                        end)
                    end)
                    
                    -- Store the connection for cleanup
                    petPreview:SetAttribute("RotationConnection", true)
                    petPreview.AncestryChanged:Connect(function(_, parent)
                        if not parent then
                            pcall(function()
                                if rotationConnection then
                                    rotationConnection:Disconnect()
                                end
                            end)
                        end
                    end)
                end
                
                -- Add unknown pet label
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Name = "PetNameLabel"
                nameLabel.Size = UDim2.new(0.8, 0, 0.2, 0)
                nameLabel.Position = UDim2.new(0.1, 0, 0.8, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = "Unknown Pet"
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 11
                nameLabel.TextWrapped = true
                nameLabel.Parent = slotData.slot
                
                -- Hide placeholder
                if placeholderIcon then
                    placeholderIcon.Visible = false
                end
            end
        else
            -- Show placeholder for empty slot
            if placeholderIcon then
                placeholderIcon.Visible = true
            end
            
            if UI_DEBUG then
                debugPrint("Slot", slotData.slotNumber, "is empty")
            end
        end
        
        -- Connect slot button for equipping/unequipping
        -- We need to disconnect any existing connections to avoid duplicates
        local existingConnection = slotData.button:GetAttribute("ConnectionActive")
        if existingConnection then
            -- Skip reconnection
            continue
        end
        
        slotData.button:SetAttribute("ConnectionActive", true)
        slotData.button.MouseButton1Click:Connect(function()
            -- Check if slot is unlocked
            if not slotData.info.unlocked then
                -- Show notification about level requirement
                local notification = screenGui:FindFirstChild("Notification")
                if notification then
                    -- Check player's current level
                    local leaderstats = player:FindFirstChild("leaderstats")
                    local playerLevel = 0
                    if leaderstats and leaderstats:FindFirstChild("Level") then
                        playerLevel = leaderstats.Level.Value
                    end
                    
                    if slotData.slotNumber == 2 then
                        if playerLevel >= 5 then
                            -- This is the case where the player is level 5+ but slot is still marked as locked
                            -- Refresh slot info from server to ensure it's up-to-date
                            local freshSlotInfo = getEquippedPetsEvent:InvokeServer()
                            if freshSlotInfo and freshSlotInfo.slot2 and freshSlotInfo.slot2.unlocked then
                                -- Slot is actually unlocked now, update UI
                                updateEquippedSlots()
                                return
                            end
                            
                            notification.Text = "You are level " .. playerLevel .. " - Slot 2 should be unlocked. Try rejoining."
                        else
                            notification.Text = "Slot 2 unlocks at Level 5 (You are level " .. playerLevel .. ")"
                        end
                    else
                        notification.Text = "Slot 3 unlocks at Level 10"
                    end
                    notification.Visible = true
                    task.delay(3, function()
                        notification.Visible = false
                    end)
                end
                return
            end
            
            -- If a pet is selected for equipping, equip it to this slot
            if selectedPetForEquip then
                if UI_DEBUG then
                    debugPrint("Attempting to equip pet", selectedPetForEquip, "to slot", slotData.slotNumber)
                end
                
                local success, error = pcall(function()
                    return equipPetEvent:InvokeServer(selectedPetForEquip, slotData.slotNumber)
                end)
                
                if success then
                    if UI_DEBUG then
                        debugPrint("Successfully equipped pet to slot", slotData.slotNumber)
                    end
                    
                    -- Get fresh equipped slots data
                    local freshSlotInfo = getEquippedPetsEvent:InvokeServer()
                    if freshSlotInfo then
                        equippedPetSlots = freshSlotInfo
                        
                        if UI_DEBUG then
                            debugPrint("Updated equipped slots after equip:")
                            for slotName, info in pairs(equippedPetSlots) do
                                debugPrint("  " .. slotName .. ":", info.petId or "empty", "unlocked:", info.unlocked)
                            end
                        end
                    end
                    
                    -- Show notification about successful equip
                    local notification = screenGui:FindFirstChild("Notification")
                    if notification then
                        notification.Text = "Pet equipped to Slot " .. slotData.slotNumber
                        notification.Visible = true
                        task.delay(3, function()
                            notification.Visible = false
                        end)
                    end
                    
                    -- Update the displays
                    updateEquippedSlots()
                    updatePetsDisplay() -- Refresh the whole list to update equipped states
                    selectedPetForEquip = nil
                else
                    warn("Failed to equip pet: " .. tostring(error))
                    
                    -- Show error notification
                    local notification = screenGui:FindFirstChild("Notification")
                    if notification then
                        notification.Text = "Failed to equip pet: " .. tostring(error)
                        notification.Visible = true
                        task.delay(3, function()
                            notification.Visible = false
                        end)
                    end
                end
            elseif slotData.info.petId then
                -- Unequip the pet in this slot
                if UI_DEBUG then
                    debugPrint("Attempting to unequip pet from slot", slotData.slotNumber)
                end
                
                local success, error = pcall(function()
                    return unequipPetEvent:InvokeServer(slotData.slotNumber)
                end)
                
                if success then
                    if UI_DEBUG then
                        debugPrint("Successfully unequipped pet from slot", slotData.slotNumber)
                    end
                    
                    -- Clear the pet ID from the slot info immediately
                    if equippedPetSlots["slot" .. slotData.slotNumber] then
                        equippedPetSlots["slot" .. slotData.slotNumber].petId = nil
                        
                        if UI_DEBUG then
                            debugPrint("Cleared petId for slot", slotData.slotNumber)
                        end
                    end
                    
                    -- Show notification about successful unequip
                    local notification = screenGui:FindFirstChild("Notification")
                    if notification then
                        notification.Text = "Pet unequipped from Slot " .. slotData.slotNumber
                        notification.Visible = true
                        task.delay(3, function()
                            notification.Visible = false
                        end)
                    end
                    
                    -- Update the displays with fresh data
                    updateEquippedSlots()
                    updatePetsDisplay() -- Refresh the whole list to update equipped states
                else
                    warn("Failed to unequip pet: " .. tostring(error))
                    
                    -- Show error notification
                    local notification = screenGui:FindFirstChild("Notification")
                    if notification then
                        notification.Text = "Failed to unequip pet: " .. tostring(error)
                        notification.Visible = true
                        task.delay(3, function()
                            notification.Visible = false
                        end)
                    end
                end
            else
                -- Empty slot, show message to select a pet first
                local notification = screenGui:FindFirstChild("Notification")
                if notification then
                    notification.Text = "Select a pet to equip first."
                    notification.Visible = true
                    task.delay(3, function()
                        notification.Visible = false
                    end)
                end
            end
        end)
    end
end

-- Create confirmation dialog for listing deletion
local confirmationDialog = Instance.new("Frame")
confirmationDialog.Name = "ConfirmationDialog"
confirmationDialog.Size = UDim2.new(0, 300, 0, 150)
confirmationDialog.Position = UDim2.new(0.5, -150, 0.5, -75)
confirmationDialog.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
confirmationDialog.BorderSizePixel = 0
confirmationDialog.Visible = false
confirmationDialog.ZIndex = 10
confirmationDialog.Parent = screenGui

-- Create confirmation dialog for coin purchases
local coinPurchaseDialog = Instance.new("Frame")
coinPurchaseDialog.Name = "CoinPurchaseDialog"
coinPurchaseDialog.Size = UDim2.new(0, 350, 0, 180)
coinPurchaseDialog.Position = UDim2.new(0.5, -175, 0.5, -90)
coinPurchaseDialog.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
coinPurchaseDialog.BorderSizePixel = 0
coinPurchaseDialog.Visible = false
coinPurchaseDialog.ZIndex = 15
coinPurchaseDialog.Parent = screenGui

-- Add rounded corners to coin purchase dialog
local coinDialogCorner = Instance.new("UICorner")
coinDialogCorner.CornerRadius = UDim.new(0, 8)
coinDialogCorner.Parent = coinPurchaseDialog

-- Add coin purchase confirmation message
local coinConfirmMessage = Instance.new("TextLabel")
coinConfirmMessage.Name = "CoinConfirmMessage"
coinConfirmMessage.Size = UDim2.new(1, -20, 0, 80)
coinConfirmMessage.Position = UDim2.new(0, 10, 0, 10)
coinConfirmMessage.BackgroundTransparency = 1
coinConfirmMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
coinConfirmMessage.TextSize = 16
coinConfirmMessage.Text = "Are you sure you want to purchase this crate?"
coinConfirmMessage.TextWrapped = true
coinConfirmMessage.Font = Enum.Font.GothamBold
coinConfirmMessage.ZIndex = 16
coinConfirmMessage.Parent = coinPurchaseDialog

-- Add coin purchase Yes button
local coinYesButton = Instance.new("TextButton")
coinYesButton.Name = "CoinYesButton"
coinYesButton.Size = UDim2.new(0, 140, 0, 40)
coinYesButton.Position = UDim2.new(0, 20, 1, -60)
coinYesButton.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
coinYesButton.BorderSizePixel = 0
coinYesButton.Text = "Yes, Purchase"
coinYesButton.TextColor3 = Color3.fromRGB(255, 255, 255)
coinYesButton.TextSize = 16
coinYesButton.Font = Enum.Font.GothamBold
coinYesButton.ZIndex = 16
coinYesButton.Parent = coinPurchaseDialog

-- Add rounded corners to coin Yes button
local coinYesButtonCorner = Instance.new("UICorner")
coinYesButtonCorner.CornerRadius = UDim.new(0, 8)
coinYesButtonCorner.Parent = coinYesButton

-- Add coin purchase No button
local coinNoButton = Instance.new("TextButton")
coinNoButton.Name = "CoinNoButton"
coinNoButton.Size = UDim2.new(0, 140, 0, 40)
coinNoButton.Position = UDim2.new(1, -160, 1, -60)
coinNoButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
coinNoButton.BorderSizePixel = 0
coinNoButton.Text = "Cancel"
coinNoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
coinNoButton.TextSize = 16
coinNoButton.Font = Enum.Font.GothamBold
coinNoButton.ZIndex = 16
coinNoButton.Parent = coinPurchaseDialog

-- Add rounded corners to coin No button
local coinNoButtonCorner = Instance.new("UICorner")
coinNoButtonCorner.CornerRadius = UDim.new(0, 8)
coinNoButtonCorner.Parent = coinNoButton

-- Variables to store current coin purchase being confirmed
local currentCoinPurchaseCrate = nil

-- Function to show coin purchase confirmation dialog
showCoinPurchaseDialog = function(crateName, coinPrice)
    currentCoinPurchaseCrate = crateName
    coinConfirmMessage.Text = "Are you sure you want to purchase the " .. crateName .. " Crate for " .. coinPrice .. " coins?"
    coinPurchaseDialog.Visible = true
end

-- Connect coin purchase No button to close dialog
coinNoButton.MouseButton1Click:Connect(function()
    coinPurchaseDialog.Visible = false
    currentCoinPurchaseCrate = nil
end)

-- Connect coin purchase Yes button to confirm purchase
coinYesButton.MouseButton1Click:Connect(function()
    if currentCoinPurchaseCrate then
       
        -- Get the coin purchase event
        local coinPurchaseEvent = ReplicatedStorage:FindFirstChild("CoinPurchaseCrateEvent")
        if not coinPurchaseEvent then
            coinPurchaseEvent = Instance.new("RemoteFunction")
            coinPurchaseEvent.Name = "CoinPurchaseCrateEvent"
            coinPurchaseEvent.Parent = ReplicatedStorage
        end
        
        -- Call server to process coin purchase
        local success, message = coinPurchaseEvent:InvokeServer(currentCoinPurchaseCrate)
        
        -- Show appropriate notification for failures and restore GUI
        if not success then
            showNotification(message or "Purchase failed. Please try again later.", Color3.fromRGB(200, 60, 60))
        end
        
        -- Hide dialog
        coinPurchaseDialog.Visible = false
        currentCoinPurchaseCrate = nil
    end
end)

-- Button hover effects for coin purchase dialog
coinYesButton.MouseEnter:Connect(function()
    TweenService:Create(coinYesButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 180, 80)}):Play()
end)

coinYesButton.MouseLeave:Connect(function()
    TweenService:Create(coinYesButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(60, 160, 60)}):Play()
end)

coinNoButton.MouseEnter:Connect(function()
    TweenService:Create(coinNoButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(100, 100, 110)}):Play()
end)

coinNoButton.MouseLeave:Connect(function()
    TweenService:Create(coinNoButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 80, 90)}):Play()
end)

-- Create crate contents dialog
local crateContentsDialog = Instance.new("Frame")
crateContentsDialog.Name = "CrateContentsDialog"
crateContentsDialog.Size = UDim2.new(0, 400, 0, 300)
crateContentsDialog.Position = UDim2.new(0.5, -200, 0.5, -150)
crateContentsDialog.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
crateContentsDialog.BorderSizePixel = 0
crateContentsDialog.Visible = false
crateContentsDialog.ZIndex = 20
crateContentsDialog.Parent = screenGui

-- Add rounded corners to crate contents dialog
local crateContentsCorner = Instance.new("UICorner")
crateContentsCorner.CornerRadius = UDim.new(0, 8)
crateContentsCorner.Parent = crateContentsDialog

-- Add crate contents title
local crateContentsTitle = Instance.new("TextLabel")
crateContentsTitle.Name = "CrateContentsTitle"
crateContentsTitle.Size = UDim2.new(1, -60, 0, 40)
crateContentsTitle.Position = UDim2.new(0, 20, 0, 10)
crateContentsTitle.BackgroundTransparency = 1
crateContentsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
crateContentsTitle.TextSize = 20
crateContentsTitle.Text = "Crate Contents"
crateContentsTitle.Font = Enum.Font.GothamBold
crateContentsTitle.TextXAlignment = Enum.TextXAlignment.Left
crateContentsTitle.ZIndex = 21
crateContentsTitle.Parent = crateContentsDialog

-- Add close button for crate contents
local crateContentsCloseButton = Instance.new("TextButton")
crateContentsCloseButton.Name = "CrateContentsCloseButton"
crateContentsCloseButton.Size = UDim2.new(0, 30, 0, 30)
crateContentsCloseButton.Position = UDim2.new(1, -40, 0, 10)
crateContentsCloseButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
crateContentsCloseButton.BorderSizePixel = 0
crateContentsCloseButton.Text = "X"
crateContentsCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
crateContentsCloseButton.TextSize = 16
crateContentsCloseButton.Font = Enum.Font.GothamBold
crateContentsCloseButton.ZIndex = 21
crateContentsCloseButton.Parent = crateContentsDialog

-- Add rounded corners to close button
local crateContentsCloseCorner = Instance.new("UICorner")
crateContentsCloseCorner.CornerRadius = UDim.new(0, 4)
crateContentsCloseCorner.Parent = crateContentsCloseButton

-- Add scrolling frame for contents
local crateContentsScrollFrame = Instance.new("ScrollingFrame")
crateContentsScrollFrame.Name = "CrateContentsScrollFrame"
crateContentsScrollFrame.Size = UDim2.new(1, -40, 1, -100)
crateContentsScrollFrame.Position = UDim2.new(0, 20, 0, 60)
crateContentsScrollFrame.BackgroundTransparency = 1
crateContentsScrollFrame.BorderSizePixel = 0
crateContentsScrollFrame.ScrollBarThickness = 6
crateContentsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80)
crateContentsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
crateContentsScrollFrame.ZIndex = 21
crateContentsScrollFrame.Parent = crateContentsDialog

-- Connect close button for crate contents
crateContentsCloseButton.MouseButton1Click:Connect(function()
    crateContentsDialog.Visible = false
end)

-- Add hover effect to close button
crateContentsCloseButton.MouseEnter:Connect(function()
    TweenService:Create(crateContentsCloseButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(230, 70, 70)}):Play()
end)

crateContentsCloseButton.MouseLeave:Connect(function()
    TweenService:Create(crateContentsCloseButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(200, 60, 60)}):Play()
end)

-- Function to show crate contents
showCrateContents = function(crateName)
    crateContentsTitle.Text = crateName .. " Crate Contents"
    
    -- Clear existing contents
    for _, child in ipairs(crateContentsScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Define crate contents using actual pets from CrateRewardsConfig
    local crateContents = {}
    if crateName == "Common" then
        crateContents = {
            {name = "BassBear", rarity = "Common", color = Color3.fromRGB(150, 150, 150)},
            {name = "Boxer", rarity = "Common", color = Color3.fromRGB(150, 150, 150)},
            {name = "Gnome", rarity = "Common", color = Color3.fromRGB(150, 150, 150)},
            {name = "Heart", rarity = "Common", color = Color3.fromRGB(150, 150, 150)},
            {name = "Mia", rarity = "Common", color = Color3.fromRGB(150, 150, 150)},
            {name = "WhiteCat", rarity = "Common", color = Color3.fromRGB(150, 150, 150)}
        }
    elseif crateName == "Rare" then
        crateContents = {
            {name = "Fox", rarity = "Rare", color = Color3.fromRGB(30, 100, 200)},
            {name = "Pirate", rarity = "Rare", color = Color3.fromRGB(30, 100, 200)},
            {name = "Sly", rarity = "Rare", color = Color3.fromRGB(30, 100, 200)},
            {name = "Zebra", rarity = "Rare", color = Color3.fromRGB(30, 100, 200)}
        }
    elseif crateName == "Legendary" then
        crateContents = {
            {name = "ConfusedAstronaut", rarity = "Legendary", color = Color3.fromRGB(170, 130, 20)},
            {name = "FBIAgent", rarity = "Legendary", color = Color3.fromRGB(170, 130, 20)},
            {name = "Murray", rarity = "Legendary", color = Color3.fromRGB(170, 130, 20)},
            {name = "Sticky", rarity = "Legendary", color = Color3.fromRGB(170, 130, 20)}
        }
    elseif crateName == "VIP" then
        crateContents = {
            {name = "Cthulhu", rarity = "VIP", color = Color3.fromRGB(170, 30, 170)},
            {name = "DarthVader", rarity = "VIP", color = Color3.fromRGB(170, 30, 170)},
            {name = "ElephantShrew", rarity = "VIP", color = Color3.fromRGB(170, 30, 170)},
            {name = "Penguin", rarity = "VIP", color = Color3.fromRGB(170, 30, 170)}
        }
    end
    
    -- Create pet preview cards
    local yOffset = 10
    local petsPerRow = 2
    local petIndex = 0
    
    for i, pet in ipairs(crateContents) do
        local row = math.floor(petIndex / petsPerRow)
        local col = petIndex % petsPerRow
        
        -- Create pet preview card
        local petCard = Instance.new("Frame")
        petCard.Name = "PetCard_" .. i
        petCard.Size = UDim2.new(0.48, 0, 0, 120) -- Slightly smaller to fit 2 per row
        petCard.Position = UDim2.new(col * 0.52, 0, 0, yOffset + (row * 130))
        petCard.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        petCard.BorderSizePixel = 0
        petCard.ZIndex = 22
        petCard.Parent = crateContentsScrollFrame
        
        -- Add rounded corners
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = petCard
        
        -- Add rarity border
        local rarityBorder = Instance.new("Frame")
        rarityBorder.Name = "RarityBorder"
        rarityBorder.Size = UDim2.new(1, 0, 0, 3)
        rarityBorder.Position = UDim2.new(0, 0, 0, 0)
        rarityBorder.BackgroundColor3 = pet.color
        rarityBorder.BorderSizePixel = 0
        rarityBorder.ZIndex = 23
        rarityBorder.Parent = petCard
        
        -- Add rounded corners to border
        local borderCorner = Instance.new("UICorner")
        borderCorner.CornerRadius = UDim.new(0, 8)
        borderCorner.Parent = rarityBorder
        
        -- Add pet preview viewport
        local previewFrame = Instance.new("ViewportFrame")
        previewFrame.Name = "PreviewFrame"
        previewFrame.Size = UDim2.new(0, 60, 0, 60)
        previewFrame.Position = UDim2.new(0, 10, 0, 15)
        previewFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        previewFrame.BackgroundTransparency = 0.3
        previewFrame.ZIndex = 23
        previewFrame.Parent = petCard
        
        -- Add rounded corners to preview
        local previewCorner = Instance.new("UICorner")
        previewCorner.CornerRadius = UDim.new(0, 6)
        previewCorner.Parent = previewFrame
        
        -- Setup pet preview in the viewport
        local camera = Instance.new("Camera")
        camera.FieldOfView = 60
        previewFrame.CurrentCamera = camera
        camera.Parent = previewFrame
        
        -- Try to get the pet model from ReplicatedStorage
        local success, petModel = pcall(function()
            local petsFolder = ReplicatedStorage:FindFirstChild("Pets")
            if petsFolder then
                local rarityFolder = petsFolder:FindFirstChild(pet.rarity)
                if rarityFolder then
                    return rarityFolder:FindFirstChild(pet.name)
                end
            end
            return nil
        end)
        
        -- If we found the pet model, clone it for display
        if success and petModel then
            local displayModel = petModel:Clone()
            displayModel.Parent = previewFrame
            
            -- Position the camera
            local targetPart = nil
            if displayModel:IsA("Model") then
                targetPart = displayModel.PrimaryPart or displayModel:FindFirstChildWhichIsA("BasePart")
            elseif displayModel:IsA("BasePart") then
                targetPart = displayModel
            end
            
            if targetPart then
                local modelSize = targetPart.Size.Magnitude
                local modelCenter = targetPart.Position
                local distance = modelSize * 1.5
                camera.CFrame = CFrame.new(modelCenter + Vector3.new(0, 0, -distance), modelCenter)
                
                -- Add rotation animation
                local rotation = 0
                local runServiceInstance = getService("RunService")
                if runServiceInstance then
                    local rotationConnection = runServiceInstance.RenderStepped:Connect(function(deltaTime)
                        if previewFrame and previewFrame.Parent and targetPart and targetPart.Parent then
                            rotation = rotation + deltaTime * 0.5
                            targetPart.CFrame = CFrame.new(modelCenter) * CFrame.Angles(0, rotation, 0)
                        else
                            rotationConnection:Disconnect()
                        end
                    end)
                    
                    -- Store connection for cleanup
                    previewFrame:SetAttribute("RotationConnection", true)
                    previewFrame.AncestryChanged:Connect(function(_, parent)
                        if not parent then
                            rotationConnection:Disconnect()
                        end
                    end)
                end
            end
        else
            -- If model not found, show placeholder
            local placeholder = Instance.new("TextLabel")
            placeholder.Name = "Placeholder"
            placeholder.Size = UDim2.new(1, 0, 1, 0)
            placeholder.BackgroundTransparency = 1
            placeholder.Text = "?"
            placeholder.TextColor3 = pet.color
            placeholder.TextSize = 30
            placeholder.Font = Enum.Font.GothamBold
            placeholder.ZIndex = 24
            placeholder.Parent = previewFrame
        end
        
        -- Add pet name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Size = UDim2.new(1, -80, 0, 25)
        nameLabel.Position = UDim2.new(0, 75, 0, 15)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = pet.name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 14
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex = 23
        nameLabel.Parent = petCard
        
        -- Add rarity label
        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Name = "RarityLabel"
        rarityLabel.Size = UDim2.new(1, -80, 0, 20)
        rarityLabel.Position = UDim2.new(0, 75, 0, 40)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = pet.rarity
        rarityLabel.TextColor3 = pet.color
        rarityLabel.TextSize = 12
        rarityLabel.Font = Enum.Font.GothamSemibold
        rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
        rarityLabel.ZIndex = 23
        rarityLabel.Parent = petCard
        
        petIndex = petIndex + 1
    end
    
    -- Calculate total height needed
    local totalRows = math.ceil(#crateContents / petsPerRow)
    local totalHeight = yOffset + (totalRows * 130) + 20
    
    -- Update canvas size
    crateContentsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    
    -- Show dialog
    crateContentsDialog.Visible = true
end

-- Create crates with updated prices
local commonCrate = createCrateItem("Common", Color3.fromRGB(100, 100, 100), UDim2.new(0, 20, 0, 100), "500", "50", "89933894957162", 3286468900)
local rareCrate = createCrateItem("Rare", Color3.fromRGB(30, 100, 200), UDim2.new(0, 20, 0, 270), "1,500", "100", "86261687992490", 3286469077)
local legendaryCrate = createCrateItem("Legendary", Color3.fromRGB(170, 130, 20), UDim2.new(0, 20, 0, 440), "5,000", "350", "72310205565377", 3286469322)
local vipCrate = createCrateItem("VIP", Color3.fromRGB(170, 30, 170), UDim2.new(0, 20, 0, 610), "10,000", "300", "110022537678643", 3286470000)

-- Add rounded corners to confirmation dialog
local dialogCorner = Instance.new("UICorner")
dialogCorner.CornerRadius = UDim.new(0, 8)
dialogCorner.Parent = confirmationDialog

-- Add confirmation message
local confirmMessage = Instance.new("TextLabel")
confirmMessage.Name = "ConfirmMessage"
confirmMessage.Size = UDim2.new(1, -20, 0, 60)
confirmMessage.Position = UDim2.new(0, 10, 0, 10)
confirmMessage.BackgroundTransparency = 1
confirmMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
confirmMessage.TextSize = 16
confirmMessage.Text = "Are you sure you want to delete this listing?"
confirmMessage.TextWrapped = true
confirmMessage.Font = Enum.Font.GothamBold
confirmMessage.ZIndex = 11
confirmMessage.Parent = confirmationDialog

-- Add Yes button
local yesButton = Instance.new("TextButton")
yesButton.Name = "YesButton"
yesButton.Size = UDim2.new(0, 120, 0, 40)
yesButton.Position = UDim2.new(0, 20, 1, -60)
yesButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
yesButton.BorderSizePixel = 0
yesButton.Text = "Yes, Delete"
yesButton.TextColor3 = Color3.fromRGB(255, 255, 255)
yesButton.TextSize = 16
yesButton.Font = Enum.Font.GothamBold
yesButton.ZIndex = 11
yesButton.Parent = confirmationDialog

-- Add rounded corners to Yes button
local yesButtonCorner = Instance.new("UICorner")
yesButtonCorner.CornerRadius = UDim.new(0, 8)
yesButtonCorner.Parent = yesButton

-- Add No button
local noButton = Instance.new("TextButton")
noButton.Name = "NoButton"
noButton.Size = UDim2.new(0, 120, 0, 40)
noButton.Position = UDim2.new(1, -140, 1, -60)
noButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
noButton.BorderSizePixel = 0
noButton.Text = "Cancel"
noButton.TextColor3 = Color3.fromRGB(255, 255, 255)
noButton.TextSize = 16
noButton.Font = Enum.Font.GothamBold
noButton.ZIndex = 11
noButton.Parent = confirmationDialog

-- Add rounded corners to No button
local noButtonCorner = Instance.new("UICorner")
noButtonCorner.CornerRadius = UDim.new(0, 8)
noButtonCorner.Parent = noButton

-- Variables to store current listing being deleted
local currentDeletingListingId = nil
local currentDeletingListingFrame = nil

-- Function to show confirmation dialog
showConfirmationDialog = function(listingId, listingFrame)
    currentDeletingListingId = listingId
    currentDeletingListingFrame = listingFrame
    confirmationDialog.Visible = true
end

-- Connect No button to close dialog
noButton.MouseButton1Click:Connect(function()
    confirmationDialog.Visible = false
    currentDeletingListingId = nil
    currentDeletingListingFrame = nil
end)

-- Connect Yes button to delete listing
yesButton.MouseButton1Click:Connect(function()
    if currentDeletingListingId then
        -- Fire remote event to delete listing on server
        removeListingEvent:FireServer(currentDeletingListingId)
        
        -- Remove listing from UI immediately
        if currentDeletingListingFrame and currentDeletingListingFrame.Parent then
            currentDeletingListingFrame:Destroy()
        end
        
        -- Refresh the listings data after a short delay to ensure server processing
        spawn(function()
            wait(0.5) -- Give server time to process the deletion
            -- Refresh by calling switchTab with the current tab to trigger updateListings
            if selectedTab == "My Listings" then
                updateListings(nil, true) -- Force refresh My Listings
            end
            -- Shop tab doesn't need refresh as it shows crate shop, not listings
        end)
        
        -- Hide dialog
        confirmationDialog.Visible = false
        currentDeletingListingId = nil
        currentDeletingListingFrame = nil
    end
end)

-- Button hover effects
yesButton.MouseEnter:Connect(function()
    TweenService:Create(yesButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(255, 80, 80)}):Play()
end)

yesButton.MouseLeave:Connect(function()
    TweenService:Create(yesButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(220, 60, 60)}):Play()
end)

noButton.MouseEnter:Connect(function()
    TweenService:Create(noButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(100, 100, 110)}):Play()
end)

noButton.MouseLeave:Connect(function()
    TweenService:Create(noButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 80, 90)}):Play()
end)

-- Function to switch between tabs
local function switchTab(tabName)
    selectedTab = tabName
    print("DEBUG: [ListingsGUI] Switching to tab:", tabName)
    
    -- Hide all frames
    listingsFrame.Visible = false
    shopFrame.Visible = false
    faqFrame.Visible = false
    inventoryFrame.Visible = false
    
    -- Reset all underlines and text colors
    myListingsUnderline.BackgroundTransparency = 1
    myListingsTab.TextColor3 = Color3.fromRGB(200, 200, 200)
    shopUnderline.BackgroundTransparency = 1
    shopTab.TextColor3 = Color3.fromRGB(200, 200, 200)
    faqUnderline.BackgroundTransparency = 1
    faqTab.TextColor3 = Color3.fromRGB(200, 200, 200)
    inventoryUnderline.BackgroundTransparency = 1
    inventoryTab.TextColor3 = Color3.fromRGB(200, 200, 200)
    
    -- Show/hide search bar based on tab
    if selectedTab == "My Listings" then
        searchContainer.Visible = true
    else
        searchContainer.Visible = false
        -- Clear search when switching away from listing tabs
        searchBar.Text = ""
        clearButton.ImageTransparency = 1
    end
    
    -- Show selected tab
    if selectedTab == "My Listings" then
        print("DEBUG: [ListingsGUI] Loading My Listings tab")
        listingsFrame.Visible = true
        myListingsUnderline.BackgroundTransparency = 0
        myListingsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
        -- Force refresh when switching to My Listings to get latest player data
        print("DEBUG: [ListingsGUI] Forcing refresh for My Listings")
        -- Apply current search query if any
        local currentSearch = searchBar.Text
        updateListings(currentSearch ~= "" and currentSearch or nil, true)
    elseif selectedTab == "Shop" then
        print("DEBUG: [ListingsGUI] Loading Shop tab")
        shopFrame.Visible = true
        shopUnderline.BackgroundTransparency = 0
        shopTab.TextColor3 = Color3.fromRGB(255, 255, 255)
        -- Shop tab shows crate shop, no listings to update
    elseif selectedTab == "FAQ" then
        faqFrame.Visible = true
        faqUnderline.BackgroundTransparency = 0
        faqTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    elseif selectedTab == "Inventory" then
        inventoryFrame.Visible = true
        inventoryUnderline.BackgroundTransparency = 0
        inventoryTab.TextColor3 = Color3.fromRGB(255, 255, 255)
        updatePetsDisplay() -- Update the pets when switching to this tab
    end
end

-- Connect tab buttons
myListingsTab.MouseButton1Click:Connect(function()
    switchTab("My Listings")
end)

shopTab.MouseButton1Click:Connect(function()
    switchTab("Shop")
end)

faqTab.MouseButton1Click:Connect(function()
    switchTab("FAQ")
end)

inventoryTab.MouseButton1Click:Connect(function()
    switchTab("Inventory")
    
    -- Force update equipped slots when switching to inventory tab
    if UI_DEBUG then
        debugPrint("Switched to Inventory tab - forcing equipped slots refresh")
    end
    
    -- Get current player level to ensure level requirements are correct
    local leaderstats = player:FindFirstChild("leaderstats")
    local playerLevel = 0
    if leaderstats and leaderstats:FindFirstChild("Level") then
        playerLevel = leaderstats.Level.Value
    end
    
    -- Make sure RunService is defined for pet rotation
    if not RunService then
        RunService = game:GetService("RunService")
    end
    
    -- Disconnect any existing connections before recreating slots to prevent memory leaks
    for _, slotData in ipairs({
        {slot = slot1, num = 1},
        {slot = slot2, num = 2},
        {slot = slot3, num = 3}
    }) do
        if slotData.slot then
            -- Find pet preview with rotation connection
            local existingPreview = slotData.slot:FindFirstChild("PetPreview")
            if existingPreview and existingPreview:GetAttribute("RotationConnection") then
                -- The actual connection will be disconnected when the frame is destroyed
                existingPreview:SetAttribute("RotationConnection", false)
            end
        end
    end
    
    -- Recreate the slot frames to ensure they have the latest player level
    -- Destroy old slots first with error handling
    pcall(function()
    if slot1 and slot1.Parent then slot1:Destroy() end
    end)
    pcall(function()
    if slot2 and slot2.Parent then slot2:Destroy() end
    end)
    pcall(function()
    if slot3 and slot3.Parent then slot3:Destroy() end
    end)
    
    -- Create new slots with the current player level in mind
    pcall(function()
    slot1, slot1Button = createPetSlot(UDim2.new(0, 50, 0, 70), 1, 0)
    slot2, slot2Button = createPetSlot(UDim2.new(0, 170, 0, 70), 2, 5)
    slot3, slot3Button = createPetSlot(UDim2.new(0, 290, 0, 70), 3, 10)
    end)
    
    -- Force-refresh pet data from server 
    pcall(function()
        -- Make sure RunService is available
        if not _G.CachedServices.RunService then
            _G.CachedServices.RunService = getService("RunService")
        end
        
        -- Re-verify our slot references are still valid
        print("Checking slot references before refresh:")
        print("Slot1:", slot1, "Parent:", slot1 and slot1.Parent)
        print("Slot2:", slot2, "Parent:", slot2 and slot2.Parent)
        print("Slot3:", slot3, "Parent:", slot3 and slot3.Parent)
        
        -- First get fresh pet data
        local success, fetchedPetsData = pcall(function()
            return getPetsDataEvent:InvokeServer()
        end)
        
        if success and fetchedPetsData then
            petsData = fetchedPetsData
            print("Retrieved", #fetchedPetsData, "pets from server")
        end
        
        -- Then get equipped slot info
        local slotInfo = getEquippedPetsEvent:InvokeServer()
        if slotInfo then
            equippedPetSlots = slotInfo
            
            -- Debug print equipped slots
            print("Got equipped slots data from server:")
            for slotName, info in pairs(equippedPetSlots) do
                print("  " .. slotName .. ":", info.petId or "empty", "unlocked:", info.unlocked)
            end
            
            -- Update the visuals with the latest data
            pcall(function()
                -- Force verify slot2 is properly set
                if not slot2 or not slot2.Parent then
                    print("WARNING: Slot2 reference is invalid before updateEquippedSlots!")
                else
                    print("Slot2 is valid before updateEquippedSlots")
                end
                
            updateEquippedSlots()
            end)
            
            -- Also update pets display
            pcall(function()
                updatePetsDisplay()
            end)
        end
    end)
end)

-- Opening animation
local function showGUI()
    -- Reset the GUI position and size for the animation
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.BackgroundTransparency = 1
    shadow.ImageTransparency = 1
    mainFrame.Visible = true
    
    -- Create and play the animation
    local openTween = TweenService:Create(
        mainFrame,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 600, 0, 400), Position = UDim2.new(0.5, -300, 0.5, -200), BackgroundTransparency = 0}
    )
    
    local shadowTween = TweenService:Create(
        shadow,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {ImageTransparency = 0.5}
    )
    
    openTween:Play()
    shadowTween:Play()
    
    -- Select the default tab FIRST before any updates
    switchTab("My Listings")
    
    -- Update GUI state in the manager
    GUIManager:SetGUIState("ListingsGUIOpen", true)
end

-- Closing animation
local function hideGUI()
    -- Create closing animation
    local closeTween = TweenService:Create(
        mainFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1}
    )
    
    local shadowTween = TweenService:Create(
        shadow,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {ImageTransparency = 1}
    )
    
    closeTween:Play()
    shadowTween:Play()
    
    -- Hide the GUI after animation completes
    closeTween.Completed:Connect(function()
        mainFrame.Visible = false
        -- Update GUI state in the manager
        GUIManager:SetGUIState("ListingsGUIOpen", false)
    end)
    
    -- Fire the event to notify that this GUI was closed
    if listingsGUIClosed then
        listingsGUIClosed:Fire()
    end
end

-- Connect the close button
closeButton.MouseButton1Click:Connect(hideGUI)

-- Create the toggle button
local toggleButton = Instance.new("ImageButton")
toggleButton.Name = "ListingsGUIToggle"
toggleButton.Size = UDim2.new(0, 50, 0, 50)
toggleButton.Position = UDim2.new(0, 20, 1, -110) -- Position above daily bonus GUI (50px for bonus + 10px gap + 50px for button)
toggleButton.BackgroundColor3 = Color3.fromRGB(173, 173, 173)
toggleButton.BorderSizePixel = 0
toggleButton.Image = "rbxassetid://130107142296925"
toggleButton.ImageColor3 = Color3.fromRGB(220, 220, 255)
toggleButton.Parent = screenGui

-- DEBUG: Monitor toggle button visibility changes
toggleButton:GetPropertyChangedSignal("Visible"):Connect(function()
    print("DEBUG: [ListingsGUI] Toggle button visibility changed to:", toggleButton.Visible)
    print("DEBUG: [ListingsGUI] Stack trace:")
    print(debug.traceback())
    
    -- Force it back to visible if something tries to hide it
    if not toggleButton.Visible then
        print("DEBUG: [ListingsGUI] Forcing toggle button back to visible!")
        toggleButton.Visible = true
    end
end)

-- DEBUG: Monitor toggle button parent changes
toggleButton:GetPropertyChangedSignal("Parent"):Connect(function()
    print("DEBUG: [ListingsGUI] Toggle button parent changed to:", toggleButton.Parent and toggleButton.Parent.Name or "nil")
    print("DEBUG: [ListingsGUI] Stack trace:")
    print(debug.traceback())
end)

-- DEBUG: Add a periodic check to monitor toggle button state
spawn(function()
    while true do
        wait(2) -- Check every 2 seconds
        if toggleButton then
            local exists = toggleButton and toggleButton.Parent
            local visible = exists and toggleButton.Visible
            print("DEBUG: [ListingsGUI] Toggle button state check - Exists:", exists, "Visible:", visible, "Parent:", toggleButton.Parent and toggleButton.Parent.Name or "nil")
        else
            print("DEBUG: [ListingsGUI] Toggle button reference is nil!")
        end
    end
end)

-- Register the toggle button with the GUIManager
-- COMMENTED OUT: Don't use GUIManager for toggle buttons - it causes issues during crate opening
-- GUIManager:RegisterToggleButton("ListingsGUI", toggleButton)

-- Add rounded corners to toggle button
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 25)
toggleCorner.Parent = toggleButton

-- Add shadow to toggle button
local toggleShadow = Instance.new("ImageLabel")
toggleShadow.Name = "Shadow"
toggleShadow.Size = UDim2.new(1, 20, 1, 20)
toggleShadow.Position = UDim2.new(0, -10, 0, -10)
toggleShadow.BackgroundTransparency = 1
toggleShadow.Image = "rbxassetid://6014261993"
toggleShadow.ImageColor3 = Color3.fromRGB(255, 255, 255)
toggleShadow.ImageTransparency = 0.5
toggleShadow.ScaleType = Enum.ScaleType.Slice
toggleShadow.SliceCenter = Rect.new(49, 49, 450, 450)
toggleShadow.ZIndex = -1
toggleShadow.Parent = toggleButton

-- Function to toggle button visibility
local function setToggleButtonsVisible(visible)
    -- ALWAYS keep both toggle buttons visible, ignore the visible parameter
    toggleButton.Visible = true
    
    -- Find and keep the NPCGeneratorToggle button visible as well
    local npcGeneratorGUI = playerGui:FindFirstChild("NPCGeneratorGui")
    if npcGeneratorGUI then
        local npcToggleButton = npcGeneratorGUI:FindFirstChild("NPCGeneratorToggle")
        if npcToggleButton then
            npcToggleButton.Visible = true
        end
    end
end

-- Create or get the ListingsGUIClosed event
local listingsGUIClosed = ReplicatedStorage:FindFirstChild("ListingsGUIClosed")
if not listingsGUIClosed then
    listingsGUIClosed = Instance.new("BindableEvent")
    listingsGUIClosed.Name = "ListingsGUIClosed"
    listingsGUIClosed.Parent = ReplicatedStorage
end

-- Check if the other GUI is open
local function checkOtherGUI()
    local npcGeneratorGUI = playerGui:FindFirstChild("NPCGeneratorGui")
    if npcGeneratorGUI then
        local npcMainFrame = npcGeneratorGUI:FindFirstChild("MainFrame") 
        if npcMainFrame and npcMainFrame.Visible then
            return true -- The other GUI is open
        end
    end
    return false -- The other GUI is not open
end

-- Connect the toggle button
toggleButton.MouseButton1Click:Connect(function()
    if mainFrame.Visible then
        hideGUI()
    else
        showGUI()
    end
end)

-- Add hover effect to toggle button
toggleButton.MouseEnter:Connect(function()
    TweenService:Create(
        toggleButton,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(173, 173, 173), Size = UDim2.new(0, 55, 0, 55), Position = UDim2.new(0, 17.5, 1, -112.5)}
    ):Play()
end)

toggleButton.MouseLeave:Connect(function()
    TweenService:Create(
        toggleButton,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(173, 173, 173), Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 20, 1, -110)}
    ):Play()
end)

-- Button-down effect
toggleButton.MouseButton1Down:Connect(function()
    TweenService:Create(
        toggleButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 45, 0, 45), Position = UDim2.new(0, 22.5, 1, -107.5)}
    ):Play()
end)

toggleButton.MouseButton1Up:Connect(function()
    TweenService:Create(
        toggleButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 20, 1, -110)}
    ):Play()
end)

-- Set up periodic update (much less frequent and smarter)
local lastUpdateTime = 0
local UPDATE_INTERVAL = 60 -- Update every 60 seconds instead of 10
local lastListingCount = 0

spawn(function()
    while true do
        wait(UPDATE_INTERVAL)
        if mainFrame.Visible and isGUIInitialized then
            -- Only update if enough time has passed and GUI is actually visible
            local currentTime = tick()
            if currentTime - lastUpdateTime >= UPDATE_INTERVAL then
                -- Quick check: only update if we suspect changes (this is optional)
                -- For now, just update but much less frequently
            updateListings()
                lastUpdateTime = currentTime
                print("DEBUG: [ListingsGUI] Periodic update performed (every " .. UPDATE_INTERVAL .. " seconds)")
            end
        end
    end
end)

-- Initialize the GUI (don't show it on startup)
mainFrame.Visible = false  -- Ensure it's hidden initially
GUIManager:SetGUIState("ListingsGUIOpen", false)

-- Mark GUI as fully initialized
isGUIInitialized = true
print("Listings GUI initialized")

-- Load initial listings now that GUI is ready
task.spawn(function()
    task.wait(0.1) -- Small delay to ensure everything is ready
    updateListings()
end)

-- Set up event handlers for renewal responses
renewSuccessEvent.OnClientEvent:Connect(function(listingKey)
    -- Force update listings to reflect changes
    if isGUIInitialized then
        updateListings(nil, true) -- Force refresh after renewal
    end
    
    -- Show success notification
    local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
    if notificationEvent then
        -- Fixed: Instead of using FireClient which is for server->client communication,
        -- we should show notification directly or use FireServer for client->server
        notificationEvent:FireServer("Listing renewed successfully!", Color3.fromRGB(100, 255, 100))
    end
end)

renewFailedEvent.OnClientEvent:Connect(function(listingKey)
    -- Show error notification
    local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
    if notificationEvent then
        -- Fixed: Instead of using FireClient which is for server->client communication,
        -- we should show notification directly or use FireServer for client->server
        notificationEvent:FireServer("Failed to renew listing!", Color3.fromRGB(255, 100, 100))
    end
end)

-- Create a notification label for slot selection
local notification = Instance.new("TextLabel")
notification.Name = "Notification"
notification.Size = UDim2.new(0, 300, 0, 40)
notification.Position = UDim2.new(0.5, -150, 0.1, 0)
notification.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
notification.BackgroundTransparency = 0.2
notification.Text = ""
notification.TextColor3 = Color3.fromRGB(255, 255, 255)
notification.TextSize = 16
notification.Font = Enum.Font.GothamMedium
notification.Visible = false
notification.Parent = screenGui

-- Add rounded corners to notification
local notificationCorner = Instance.new("UICorner")
notificationCorner.CornerRadius = UDim.new(0, 8)
notificationCorner.Parent = notification

-- Connect to purchase success event to refresh listings
local purchaseSuccessEvent = ReplicatedStorage:WaitForChild("PurchaseSuccessEvent")
purchaseSuccessEvent.OnClientEvent:Connect(function()
    print("DEBUG: [ListingsGUI] Purchase successful - refreshing listings")
    -- Force refresh listings to show new listing and remove "Processing" state
    if mainFrame and mainFrame.Visible then
        print("DEBUG: [ListingsGUI] GUI is open - forcing immediate refresh")
        -- Force refresh with current tab
        updateListings(nil, true)
    else
        print("DEBUG: [ListingsGUI] GUI is closed - clearing cache for next open")
        -- Clear cache so next time GUI opens it will refresh
        allListings = {}
        lastDataFetch = 0
    end
end)

print("Listings GUI initialized")

-- Function to force initialize the inventory display
local function initializeInventory()
    if UI_DEBUG then
        debugPrint("Initializing inventory display on startup")
    end
    
    -- Get initial equipped pets data with retry mechanism
    local retryCount = 0
    local maxRetries = 3
    local retryDelay = 2
    local retryAttempt -- Declare in outer scope
    
    -- Properly return the result of the operation
    local function fetchAndUpdatePets()
        local ok, result = pcall(function()
            -- Clear any existing pet data first
            equippedPetSlots = { slot1 = { petId = nil, unlocked = true }, slot2 = { petId = nil, unlocked = false }, slot3 = { petId = nil, unlocked = false } }
            petsData = {}
            
            -- First get all pet data
            local success, fetchedPetsData = pcall(function()
                return getPetsDataEvent:InvokeServer()
            end)
            
            if success and fetchedPetsData then
                petsData = fetchedPetsData
            end
            
            -- Then get equipped pets data
            local initialSlotInfo = getEquippedPetsEvent:InvokeServer()
            if initialSlotInfo then
                equippedPetSlots = initialSlotInfo
                
                if UI_DEBUG then
                    debugPrint("Initial equipped slots data:")
                    for slotName, info in pairs(equippedPetSlots) do
                        debugPrint("  " .. slotName .. ":", info.petId or "empty", "unlocked:", info.unlocked)
                    end
                end
                
                -- Update the slots visually only after we have both pet data and slot info
                pcall(function()
                updateEquippedSlots()
                end)
                
                -- If we have a successful pets load, we're done
                return true
            end
            
            return false
        end)
        
        return ok and result -- Properly return the result
    end
    
    -- Define retryAttempt in the proper scope
    retryAttempt = function()
            retryCount = retryCount + 1
            if retryCount <= maxRetries then
                if UI_DEBUG then
                    debugPrint("Retrying pet data fetch, attempt", retryCount)
                end
            
            local success = fetchAndUpdatePets()
                
                if not success and retryCount < maxRetries then
                    task.delay(retryDelay, function()
                    -- Now this will work because retryAttempt is defined in the proper scope
                        retryAttempt()
                    end)
                end
            end
        end
        
    -- First attempt
    local success = fetchAndUpdatePets()
    
    -- Retry mechanism for more reliable loading
    if not success then
        task.delay(retryDelay, function()
            retryAttempt()
        end)
    end
end

-- Add UI elements for equipped pet slots
-- Make slot displays more visible
for i, slotData in ipairs({
    {slot = slot1, num = 1},
    {slot = slot2, num = 2},
    {slot = slot3, num = 3}
}) do
    -- Add a highlight indicator for active slot
    local highlightFrame = Instance.new("Frame")
    highlightFrame.Name = "SlotHighlight"
    highlightFrame.Size = UDim2.new(1, 0, 1, 0)
    highlightFrame.BackgroundColor3 = Color3.fromRGB(30, 100, 180)
    highlightFrame.BackgroundTransparency = 0.9
    highlightFrame.BorderSizePixel = 0
    highlightFrame.ZIndex = 1
    highlightFrame.Visible = false
    highlightFrame.Parent = slotData.slot
    
    -- Add rounded corners to highlight
    local highlightCorner = Instance.new("UICorner")
    highlightCorner.CornerRadius = UDim.new(0, 8)
    highlightCorner.Parent = highlightFrame
end

-- Initialize the inventory when GUI loads
task.spawn(function()
    task.wait(1) -- Wait a bit for other systems to initialize
    initializeInventory()
end)

-- The showGUI and hideGUI functions are already defined earlier in the script
-- Do not redefine them here

-- Function to refresh current tab
local function refreshCurrentTab()
    if selectedTab == "My Listings" then
        print("DEBUG: [ListingsGUI] Refreshing My Listings tab after deletion")
        updateListings(nil, true)
    end
    -- Shop tab doesn't need refresh as it shows crate shop, not listings
end

end) -- End of pcall

-- Handle any errors that occurred
if not success then
    warn("ListingsGUI Error: " .. tostring(errorMessage))
    print("ListingsGUI failed to load properly, but game should continue running")
end