-- AssetStatsViewer.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Debug function
local DEBUG_ENABLED = false
local function debugPrint(...)
    if DEBUG_ENABLED then
        print("[AssetStatsViewer]", ...)
    end
end

-- Delete any existing instances to prevent duplicates
local existingGui = playerGui:FindFirstChild("AssetStatsViewerGui")
if existingGui then
    existingGui:Destroy()
end

-- Create a RemoteFunction for fetching asset sales data
local getAssetStatsFunc = ReplicatedStorage:FindFirstChild("GetAssetStatsFunc")
if not getAssetStatsFunc then
    print("DEBUG: [AssetStatsViewer] Waiting for GetAssetStatsFunc from server...")
    getAssetStatsFunc = ReplicatedStorage:WaitForChild("GetAssetStatsFunc", 10)
    if getAssetStatsFunc then
        print("DEBUG: [AssetStatsViewer] Found GetAssetStatsFunc from server")
    else
        warn("DEBUG: [AssetStatsViewer] GetAssetStatsFunc not found after 10 seconds - creating fallback")
        getAssetStatsFunc = Instance.new("RemoteFunction")
        getAssetStatsFunc.Name = "GetAssetStatsFunc"
        getAssetStatsFunc.Parent = ReplicatedStorage
    end
else
    print("DEBUG: [AssetStatsViewer] Found existing GetAssetStatsFunc")
end

-- Create the GUI
local statsGui = Instance.new("ScreenGui")
statsGui.Name = "AssetStatsViewerGui"
statsGui.ResetOnSpawn = false
statsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
statsGui.Enabled = false
statsGui.Parent = playerGui

-- Table to store hidden buttons
local hiddenButtons = {}

-- Create main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "StatsFrame"
mainFrame.Size = UDim2.new(0, 350, 0, 240) -- Increased height for try-on label
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -120) -- Adjusted position
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 101 -- High ZIndex to ensure visibility
mainFrame.Parent = statsGui

-- Add corner radius
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Add title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -100, 0, 40)
titleLabel.Position = UDim2.new(0, 20, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Asset Statistics"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 24
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 102
titleLabel.Parent = mainFrame

-- Close button (MUCH larger and more prominent)
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 60, 0, 60) -- Doubled size
closeButton.Position = UDim2.new(1, -70, 0, 10) -- Adjusted position
closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeButton.BackgroundTransparency = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 30 -- Larger text
closeButton.Font = Enum.Font.GothamBold
closeButton.ZIndex = 103 -- Highest ZIndex to ensure it's clickable
closeButton.Parent = mainFrame

-- Add corner radius to close button
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- Add a shadow to close button to make it stand out more
local closeButtonShadow = Instance.new("UIStroke")
closeButtonShadow.Name = "Shadow"
closeButtonShadow.Color = Color3.fromRGB(0, 0, 0)
closeButtonShadow.Thickness = 2
closeButtonShadow.Parent = closeButton

-- Asset ID Label
local assetIdLabel = Instance.new("TextLabel")
assetIdLabel.Name = "AssetIdLabel"
assetIdLabel.Size = UDim2.new(1, -40, 0, 30)
assetIdLabel.Position = UDim2.new(0, 20, 0, 60)
assetIdLabel.BackgroundTransparency = 1
assetIdLabel.TextXAlignment = Enum.TextXAlignment.Left
assetIdLabel.Text = "Asset ID: "
assetIdLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
assetIdLabel.TextSize = 18
assetIdLabel.Font = Enum.Font.GothamSemibold
assetIdLabel.ZIndex = 102
assetIdLabel.Parent = mainFrame

-- Asset Type Label
local assetTypeLabel = Instance.new("TextLabel")
assetTypeLabel.Name = "AssetTypeLabel"
assetTypeLabel.Size = UDim2.new(1, -40, 0, 30)
assetTypeLabel.Position = UDim2.new(0, 20, 0, 95)
assetTypeLabel.BackgroundTransparency = 1
assetTypeLabel.TextXAlignment = Enum.TextXAlignment.Left
assetTypeLabel.Text = "Type: "
assetTypeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
assetTypeLabel.TextSize = 18
assetTypeLabel.Font = Enum.Font.GothamSemibold
assetTypeLabel.ZIndex = 102
assetTypeLabel.Parent = mainFrame

-- Total Sales Label
local totalSalesLabel = Instance.new("TextLabel")
totalSalesLabel.Name = "TotalSalesLabel"
totalSalesLabel.Size = UDim2.new(1, -40, 0, 30)
totalSalesLabel.Position = UDim2.new(0, 20, 0, 130)
totalSalesLabel.BackgroundTransparency = 1
totalSalesLabel.TextXAlignment = Enum.TextXAlignment.Left
totalSalesLabel.Text = "Total Sales: 0"
totalSalesLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
totalSalesLabel.TextSize = 18
totalSalesLabel.Font = Enum.Font.GothamSemibold
totalSalesLabel.ZIndex = 102
totalSalesLabel.Parent = mainFrame

-- Recent Sales Label
local recentSalesLabel = Instance.new("TextLabel")
recentSalesLabel.Name = "RecentSalesLabel"
recentSalesLabel.Size = UDim2.new(1, -40, 0, 30)
recentSalesLabel.Position = UDim2.new(0, 20, 0, 165)
recentSalesLabel.BackgroundTransparency = 1
recentSalesLabel.TextXAlignment = Enum.TextXAlignment.Left
recentSalesLabel.Text = "Recent Sales (24h): 0"
recentSalesLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
recentSalesLabel.TextSize = 18
recentSalesLabel.Font = Enum.Font.GothamSemibold
recentSalesLabel.ZIndex = 102
recentSalesLabel.Parent = mainFrame

-- Try Ons Label
local tryOnsLabel = Instance.new("TextLabel")
tryOnsLabel.Name = "TryOnsLabel"
tryOnsLabel.Size = UDim2.new(1, -40, 0, 30)
tryOnsLabel.Position = UDim2.new(0, 20, 0, 200)
tryOnsLabel.BackgroundTransparency = 1
tryOnsLabel.TextXAlignment = Enum.TextXAlignment.Left
tryOnsLabel.Text = "Try Ons: 0"
tryOnsLabel.TextColor3 = Color3.fromRGB(255, 100, 255) -- Purple color
tryOnsLabel.TextSize = 18
tryOnsLabel.Font = Enum.Font.GothamSemibold
tryOnsLabel.ZIndex = 102
tryOnsLabel.Parent = mainFrame

-- Add debug label to show info about button hiding
local debugLabel = Instance.new("TextLabel")
debugLabel.Name = "DebugLabel"
debugLabel.Size = UDim2.new(1, -40, 0, 30)
debugLabel.Position = UDim2.new(0, 20, 1, -30)
debugLabel.BackgroundTransparency = 1
debugLabel.TextXAlignment = Enum.TextXAlignment.Left
debugLabel.Text = "Debug: No buttons hidden"
debugLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
debugLabel.TextSize = 12
debugLabel.Font = Enum.Font.Code
debugLabel.ZIndex = 102
debugLabel.Visible = DEBUG_ENABLED
debugLabel.Parent = mainFrame

-- Variable to track the button-hiding heartbeat connection
local buttonHidingConnection = nil

-- Helper function to find the correct ListingsGUI (the ScreenGui, not the folder)
local function findListingsScreenGui()
    -- Search through all children in PlayerGui to find the ScreenGui named ListingsGUI
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == "ListingsGUI" and child:IsA("ScreenGui") then
            return child
        end
    end
    
    -- If not found, try another approach - look for any ScreenGui that has a MainFrame with ContentsFrame
    for _, child in ipairs(playerGui:GetChildren()) do
        if child:IsA("ScreenGui") then
            local mainFrame = child:FindFirstChild("MainFrame")
            if mainFrame then
                local contentsFrame = mainFrame:FindFirstChild("ContentsFrame")
                if contentsFrame then
                    return child
                end
            end
        end
    end
    
    return nil
end

-- Function to find and hide specific buttons to prevent interaction issues
local function hideInterfereingButtons()
    -- Clear existing hidden buttons table
    hiddenButtons = {}
    
    -- Disconnect any existing connection
    if buttonHidingConnection then
        buttonHidingConnection:Disconnect()
        buttonHidingConnection = nil
    end

    -- Get the correct ListingsGUI ScreenGui
    local listingsGUI = findListingsScreenGui()
    if not listingsGUI then
        debugPrint("ListingsGUI ScreenGui not found, nothing to hide")
        return
    end
    
    debugPrint("Found ListingsGUI ScreenGui:", listingsGUI:GetFullName())
    
    -- Find MainFrame > ContentsFrame > ListingsFrame
    local mainFrame = listingsGUI:FindFirstChild("MainFrame")
    if not mainFrame then
        debugPrint("MainFrame not found in ListingsGUI")
        return
    end
    
    local contentsFrame = mainFrame:FindFirstChild("ContentsFrame")
    if not contentsFrame then
        debugPrint("ContentsFrame not found in MainFrame")
        return
    end
    
    local listingsFrame = contentsFrame:FindFirstChild("ListingsFrame")
    if not listingsFrame then
        debugPrint("ListingsFrame not found in ContentsFrame")
        return
    end
    
    -- Now find all the buttons in all listing frames
    local buttonsHidden = 0
    
    -- Look for buttons in all listings
    for _, listingFrame in ipairs(listingsFrame:GetChildren()) do
        if listingFrame:IsA("Frame") and listingFrame.Name:match("^Listing_") then
            -- Look for edit button (includes all buttons that need to be hidden)
            local buttonsToHide = {"EditNameButton", "ResetNameButton", "DeleteButton", "RenewButton", "CustomizeButton"}
            
            for _, buttonName in ipairs(buttonsToHide) do
                local button = listingFrame:FindFirstChild(buttonName)
                if button and button:IsA("GuiObject") then
                    -- Store button and its original state
                    table.insert(hiddenButtons, {
                        button = button,
                        wasVisible = button.Visible,
                        wasActive = button.Active
                    })
                    
                    -- Hide and disable the button
                    button.Visible = false
                    button.Active = false
                    buttonsHidden = buttonsHidden + 1
                    
                    debugPrint("Hid button:", buttonName, "in", listingFrame.Name)
                end
            end
        end
    end
    
    if buttonsHidden > 0 then
        debugPrint("Successfully hid", buttonsHidden, "buttons")
        debugLabel.Text = "Debug: " .. buttonsHidden .. " buttons hidden"
    else
        debugPrint("No buttons found to hide")
        debugLabel.Text = "Debug: No buttons found to hide"
    end
end

-- Function to restore all hidden buttons
local function restoreInterfereingButtons()
    -- Disconnect any active button hiding connection
    if buttonHidingConnection then
        buttonHidingConnection:Disconnect()
        buttonHidingConnection = nil
    end

    local buttonsRestored = 0
    
    -- Restore all the buttons we hid
    for _, buttonData in ipairs(hiddenButtons) do
        if buttonData.button and buttonData.button:IsA("GuiObject") then
            -- Restore original visibility and active state
            buttonData.button.Visible = buttonData.wasVisible
            buttonData.button.Active = buttonData.wasActive
            
            debugPrint("Restored button:", buttonData.button.Name)
            buttonsRestored = buttonsRestored + 1
        end
    end
    
    -- Clear the table
    hiddenButtons = {}
    
    if buttonsRestored > 0 then
        debugPrint("Successfully restored", buttonsRestored, "buttons")
        debugLabel.Text = "Debug: " .. buttonsRestored .. " buttons restored"
    else
        debugPrint("No buttons were restored")
        debugLabel.Text = "Debug: No buttons restored"
    end
end

-- Function to show asset stats
local function showAssetStats(assetId, assetType)
    print("DEBUG: [AssetStatsViewer] showAssetStats called with assetId:", assetId, "assetType:", assetType)
    
    -- Set the asset ID and type
    assetIdLabel.Text = "Asset ID: " .. assetId
    assetTypeLabel.Text = "Type: " .. assetType
    
    print("DEBUG: [AssetStatsViewer] Calling server to get stats...")
    
    -- Fetch stats from server with error handling
    local stats = {totalSales = 0, recentSales = 0, tryOns = 0} -- default fallback
    local success, result = pcall(function()
        return getAssetStatsFunc:InvokeServer(assetId)
    end)
    
    if success and result then
        stats = result
        print("DEBUG: [AssetStatsViewer] Received stats from server:", stats.totalSales, stats.recentSales, stats.tryOns)
    else
        warn("DEBUG: [AssetStatsViewer] Failed to get stats from server. Success:", success, "Error:", result)
        print("DEBUG: [AssetStatsViewer] Using fallback stats:", stats.totalSales, stats.recentSales, stats.tryOns)
    end
    
    -- Update labels
    totalSalesLabel.Text = "Total Sales: " .. stats.totalSales
    recentSalesLabel.Text = "Recent Sales (24h): " .. stats.recentSales
    tryOnsLabel.Text = "Try Ons: " .. stats.tryOns
    
    print("DEBUG: [AssetStatsViewer] Updated labels, showing GUI...")
    
    -- Show the GUI with animation immediately
    statsGui.Enabled = true
    
    -- Animation
    mainFrame.Size = UDim2.new(0, 0, 0, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    -- Create animations
    local sizeTween = TweenService:Create(
        mainFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 350, 0, 240), Position = UDim2.new(0.5, -175, 0.5, -120)}
    )
    
    -- Play animations
    sizeTween:Play()
    
    print("DEBUG: [AssetStatsViewer] Animation started, GUI should be visible")
    
    -- Asynchronously hide interfering buttons
    task.spawn(function()
        -- Brief delay to make sure Roblox has time to render the UI
        task.wait(0.05)
        hideInterfereingButtons()
    end)
end

-- Function to hide the asset stats
local function hideAssetStats()
    -- First restore the buttons before starting the animation
    restoreInterfereingButtons()
    
    -- Hide with animation
    local sizeTween = TweenService:Create(
        mainFrame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}
    )
    
    sizeTween:Play()
    
    sizeTween.Completed:Connect(function()
        statsGui.Enabled = false
    end)
end

-- Connect close button
closeButton.MouseButton1Click:Connect(hideAssetStats)

-- Create remote event for opening stats
local openAssetStatsEvent = ReplicatedStorage:FindFirstChild("OpenAssetStatsEvent")
if not openAssetStatsEvent then
    print("DEBUG: [AssetStatsViewer] Waiting for OpenAssetStatsEvent from server...")
    openAssetStatsEvent = ReplicatedStorage:WaitForChild("OpenAssetStatsEvent", 10)
    if openAssetStatsEvent then
        print("DEBUG: [AssetStatsViewer] Found OpenAssetStatsEvent from server")
    else
        warn("DEBUG: [AssetStatsViewer] OpenAssetStatsEvent not found after 10 seconds - creating fallback")
        openAssetStatsEvent = Instance.new("RemoteEvent")
        openAssetStatsEvent.Name = "OpenAssetStatsEvent"
        openAssetStatsEvent.Parent = ReplicatedStorage
    end
else
    print("DEBUG: [AssetStatsViewer] Found existing OpenAssetStatsEvent")
end

-- Store the connection in a variable instead of as an attribute
-- This avoids the "Connection is not a supported attribute type" error
local eventConnection

-- Clean up any existing connections
if eventConnection then
    eventConnection:Disconnect()
end

-- Listen for the open stats event
eventConnection = openAssetStatsEvent.OnClientEvent:Connect(function(assetId, assetType)
    print("DEBUG: [AssetStatsViewer] Received openAssetStatsEvent from server! AssetId:", assetId, "AssetType:", assetType)
    showAssetStats(assetId, assetType)
end)

-- Make sure GUI is hidden on script load
statsGui.Enabled = false

-- Add hover effects to the close button
closeButton.MouseEnter:Connect(function()
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
end)

closeButton.MouseLeave:Connect(function()
    closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
end)

debugPrint("AssetStatsViewer initialized")

-- Export functions to make them available to other scripts
local module = {}
module.showAssetStats = showAssetStats
module.hideAssetStats = hideAssetStats
return module 