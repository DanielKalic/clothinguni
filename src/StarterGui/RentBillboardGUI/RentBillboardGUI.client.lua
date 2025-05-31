-- Rent Billboard GUI
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

-- Dev Product ID for billboard rental
local BILLBOARD_DEV_PRODUCT_ID = 3293434478

-- Wait for billboard events (will be created by server)
local billboardFolder = ReplicatedStorage:WaitForChild("RentBillboard")
if not billboardFolder then
    billboardFolder = Instance.new("Folder")
    billboardFolder.Name = "RentBillboard"
    billboardFolder.Parent = ReplicatedStorage
end

local rentBillboardEvent = billboardFolder:WaitForChild("RentBillboardEvent")
local getBillboardDataEvent = billboardFolder:WaitForChild("GetBillboardDataEvent")

-- Variables
local screenGui
local mainFrame
local toggleButton
local isGUIVisible = false
local currentPreviewAsset = nil
local pendingBillboardRequests = {}

-- Variables for auto-refresh
local currentListingsConnection = nil
local currentListingsGui = nil
local currentRefreshFunction = nil

-- Colors (matching Daily Objectives style)
local BACKGROUND_COLOR = Color3.fromRGB(40, 40, 40)
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local TITLE_COLOR = Color3.fromRGB(255, 215, 0) -- Gold
local BUTTON_COLOR = Color3.fromRGB(60, 120, 200)
local SUCCESS_COLOR = Color3.fromRGB(0, 255, 0)
local ERROR_COLOR = Color3.fromRGB(255, 100, 100)

-- Function to check if player has VIP gamepass
local function hasVIPGamepass()
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
    end)
    return success and ownsGamepass
end

-- Function to show notification
local function showNotification(message, color)
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 300, 0, 60)
    notification.Position = UDim2.new(0.5, -150, 0.1, 0)
    notification.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    notification.BackgroundTransparency = 0.2
    notification.BorderSizePixel = 0
    notification.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = notification
    
    local messageText = Instance.new("TextLabel")
    messageText.Size = UDim2.new(1, -20, 1, 0)
    messageText.Position = UDim2.new(0, 10, 0, 0)
    messageText.BackgroundTransparency = 1
    messageText.Text = message
    messageText.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageText.TextSize = 16
    messageText.Font = Enum.Font.GothamSemibold
    messageText.TextWrapped = true
    messageText.Parent = notification
    
    local colorBar = Instance.new("Frame")
    colorBar.Size = UDim2.new(0, 5, 1, -10)
    colorBar.Position = UDim2.new(0, 0, 0, 5)
    colorBar.BackgroundColor3 = color
    colorBar.BorderSizePixel = 0
    colorBar.Parent = notification
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 2)
    barCorner.Parent = colorBar
    
    -- Animate in
    local tweenIn = TweenService:Create(
        notification,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -150, 0.1, 30)}
    )
    tweenIn:Play()
    
    -- Remove after 3 seconds
    task.delay(3, function()
        local tweenOut = TweenService:Create(
            notification,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -150, 0, -70)}
        )
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            notification:Destroy()
        end)
    end)
end

-- Function to update asset preview
local function updateAssetPreview(assetId, previewFrame)
    if currentPreviewAsset then
        currentPreviewAsset:Destroy()
        currentPreviewAsset = nil
    end
    
    if not assetId or assetId == "" then
        return
    end
    
    -- Create preview asset
    currentPreviewAsset = Instance.new("ImageLabel")
    currentPreviewAsset.Name = "PreviewAsset"
    currentPreviewAsset.Size = UDim2.new(1, -10, 1, -10)
    currentPreviewAsset.Position = UDim2.new(0, 5, 0, 5)
    currentPreviewAsset.BackgroundTransparency = 1
    currentPreviewAsset.Image = "rbxassetid://" .. assetId
    currentPreviewAsset.ScaleType = Enum.ScaleType.Fit
    currentPreviewAsset.Parent = previewFrame
    
    -- Note: ImageLabel doesn't have ImageLoaded/ImageFailed events
    -- The image will load automatically when the Image property is set
end

-- Function to show billboard listings
local function showBillboardListings()
    print("DEBUG: showBillboardListings called")
    
    -- Close any existing listings GUI first
    if currentListingsGui then
        print("DEBUG: Closing existing listings GUI")
        if currentListingsConnection then
            currentListingsConnection:Disconnect()
            currentListingsConnection = nil
        end
        currentListingsGui:Destroy()
        currentListingsGui = nil
        currentRefreshFunction = nil
    end
    
    -- Create listings GUI
    local listingsGui = Instance.new("ScreenGui")
    listingsGui.Name = "BillboardListingsGUI"
    listingsGui.ResetOnSpawn = false
    listingsGui.Parent = playerGui
    
    currentListingsGui = listingsGui
    
    -- Create main frame
    local listingsFrame = Instance.new("Frame")
    listingsFrame.Name = "ListingsFrame"
    listingsFrame.Size = UDim2.new(0, 500, 0, 400)
    listingsFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
    listingsFrame.BackgroundColor3 = BACKGROUND_COLOR
    listingsFrame.BackgroundTransparency = 0.1
    listingsFrame.BorderSizePixel = 0
    listingsFrame.Parent = listingsGui
    
    local listingsCorner = Instance.new("UICorner")
    listingsCorner.CornerRadius = UDim.new(0, 12)
    listingsCorner.Parent = listingsFrame
    
    -- Add shadow
    local listingsShadow = Instance.new("Frame")
    listingsShadow.Name = "Shadow"
    listingsShadow.Size = UDim2.new(1, 10, 1, 10)
    listingsShadow.Position = UDim2.new(0, -5, 0, -5)
    listingsShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    listingsShadow.BackgroundTransparency = 0.7
    listingsShadow.BorderSizePixel = 0
    listingsShadow.ZIndex = listingsFrame.ZIndex - 1
    listingsShadow.Parent = listingsFrame
    
    local listingsShadowCorner = Instance.new("UICorner")
    listingsShadowCorner.CornerRadius = UDim.new(0, 12)
    listingsShadowCorner.Parent = listingsShadow
    
    -- Title
    local listingsTitle = Instance.new("TextLabel")
    listingsTitle.Name = "Title"
    listingsTitle.Size = UDim2.new(1, -50, 0, 30)
    listingsTitle.Position = UDim2.new(0, 0, 0, 10)
    listingsTitle.BackgroundTransparency = 1
    listingsTitle.Text = "My Billboard Rentals"
    listingsTitle.TextColor3 = TITLE_COLOR
    listingsTitle.TextSize = 18
    listingsTitle.Font = Enum.Font.GothamBold
    listingsTitle.TextXAlignment = Enum.TextXAlignment.Center
    listingsTitle.Parent = listingsFrame
    
    -- Close button
    local listingsCloseButton = Instance.new("TextButton")
    listingsCloseButton.Name = "CloseButton"
    listingsCloseButton.Size = UDim2.new(0, 30, 0, 30)
    listingsCloseButton.Position = UDim2.new(1, -40, 0, 10)
    listingsCloseButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    listingsCloseButton.BackgroundTransparency = 0.2
    listingsCloseButton.BorderSizePixel = 0
    listingsCloseButton.Text = "X"
    listingsCloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    listingsCloseButton.TextSize = 16
    listingsCloseButton.Font = Enum.Font.GothamBold
    listingsCloseButton.Parent = listingsFrame
    
    local listingsCloseCorner = Instance.new("UICorner")
    listingsCloseCorner.CornerRadius = UDim.new(0, 6)
    listingsCloseCorner.Parent = listingsCloseButton
    
    listingsCloseButton.MouseButton1Click:Connect(function()
        -- Clean up auto-refresh connection
        if currentListingsConnection then
            currentListingsConnection:Disconnect()
            currentListingsConnection = nil
        end
        currentListingsGui = nil
        currentRefreshFunction = nil
        listingsGui:Destroy()
    end)
    
    -- Scroll frame for listings
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, -20, 1, -60)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    scrollFrame.BackgroundTransparency = 0.3
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.Parent = listingsFrame
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 8)
    scrollCorner.Parent = scrollFrame
    
    -- Function to refresh billboard data
    local function refreshBillboardData(isManualRefresh)
        if isManualRefresh then
            print("DEBUG: refreshBillboardData called - Manual refresh, fetching fresh data from server")
        else
            print("DEBUG: refreshBillboardData called - Auto refresh due to expiration")
        end
        
        -- Clear existing entries
        for _, child in pairs(scrollFrame:GetChildren()) do
            if child.Name:match("BillboardEntry") then
                child:Destroy()
            end
        end
        
        -- Get fresh billboard data from server
    if getBillboardDataEvent then
        print("DEBUG: Calling getBillboardDataEvent:InvokeServer()...")
        local success, playerBillboards = pcall(function()
            return getBillboardDataEvent:InvokeServer()
        end)
        
        if not success then
            print("DEBUG: Error calling server:", playerBillboards)
            showNotification("Failed to get billboard data from server!", ERROR_COLOR)
            return
        end
        
        print("DEBUG: Server call successful. Received data type:", type(playerBillboards))
        if playerBillboards then
            print("DEBUG: Server returned", #playerBillboards, "billboards")
            for i, billboard in ipairs(playerBillboards) do
                print("DEBUG: Billboard", i, "- AssetId:", billboard.assetId, "Expires:", billboard.expiresAt, "Expired:", billboard.isExpired)
            end
        else
            print("DEBUG: Server returned nil/empty data")
        end
        
        if playerBillboards and #playerBillboards > 0 then
            local yOffset = 10
            
            for i, billboardData in ipairs(playerBillboards) do
                -- Create listing entry for each billboard
                local listingEntry = Instance.new("Frame")
                listingEntry.Name = "BillboardEntry" .. i
                listingEntry.Size = UDim2.new(1, -20, 0, 120)
                listingEntry.Position = UDim2.new(0, 10, 0, yOffset)
                listingEntry.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                listingEntry.BackgroundTransparency = 0.2
                listingEntry.BorderSizePixel = 0
                listingEntry.Parent = scrollFrame
                
                local entryCorner = Instance.new("UICorner")
                entryCorner.CornerRadius = UDim.new(0, 8)
                entryCorner.Parent = listingEntry
                    
                    -- Store billboard data in the entry for auto-refresh
                    listingEntry:SetAttribute("ExpiresAt", billboardData.expiresAt)
                    listingEntry:SetAttribute("AssetId", billboardData.assetId)
                    listingEntry:SetAttribute("BillboardIndex", i)
                
                -- Preview image
                local previewImage = Instance.new("ImageLabel")
                previewImage.Name = "PreviewImage"
                previewImage.Size = UDim2.new(0, 80, 0, 80)
                previewImage.Position = UDim2.new(0, 10, 0, 20)
                previewImage.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
                previewImage.BackgroundTransparency = 0.3
                previewImage.BorderSizePixel = 0
                previewImage.Image = "rbxassetid://" .. billboardData.assetId
                previewImage.ScaleType = Enum.ScaleType.Fit
                previewImage.Parent = listingEntry
                
                local previewCorner = Instance.new("UICorner")
                previewCorner.CornerRadius = UDim.new(0, 6)
                previewCorner.Parent = previewImage
                
                -- Info labels
                local assetIdLabel = Instance.new("TextLabel")
                assetIdLabel.Name = "AssetIdLabel"
                assetIdLabel.Size = UDim2.new(0.6, -20, 0, 20)
                assetIdLabel.Position = UDim2.new(0, 100, 0, 10)
                assetIdLabel.BackgroundTransparency = 1
                assetIdLabel.Text = "Asset ID: " .. billboardData.assetId
                assetIdLabel.TextColor3 = TEXT_COLOR
                assetIdLabel.TextSize = 14
                assetIdLabel.Font = Enum.Font.GothamSemibold
                assetIdLabel.TextXAlignment = Enum.TextXAlignment.Left
                assetIdLabel.Parent = listingEntry
                
                local timeLeft = billboardData.expiresAt - os.time()
                    local isExpired = billboardData.isExpired or timeLeft <= 0
                
                local timeLabel = Instance.new("TextLabel")
                timeLabel.Name = "TimeLabel"
                timeLabel.Size = UDim2.new(0.6, -20, 0, 20)
                timeLabel.Position = UDim2.new(0, 100, 0, 35)
                timeLabel.BackgroundTransparency = 1
                if isExpired then
                        timeLabel.Text = "Expired"
                    timeLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                else
                        -- Use server's formatted time display
                        timeLabel.Text = "Expires in: " .. (billboardData.timeDisplay or "Unknown")
                        timeLabel.TextColor3 = timeLeft > 3600 and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 165, 0) -- Green if >1 hour, orange if <1 hour
                end
                timeLabel.TextSize = 14
                timeLabel.Font = Enum.Font.GothamSemibold
                timeLabel.TextXAlignment = Enum.TextXAlignment.Left
                timeLabel.Parent = listingEntry
                
                -- Rotation status
                local rotationLabel = Instance.new("TextLabel")
                rotationLabel.Name = "RotationLabel"
                rotationLabel.Size = UDim2.new(0.6, -20, 0, 20)
                rotationLabel.Position = UDim2.new(0, 100, 0, 60)
                rotationLabel.BackgroundTransparency = 1
                rotationLabel.Text = "Status: In Rotation"
                rotationLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
                rotationLabel.TextSize = 12
                rotationLabel.Font = Enum.Font.GothamMedium
                rotationLabel.TextXAlignment = Enum.TextXAlignment.Left
                rotationLabel.Parent = listingEntry
                
                    if isExpired then
                        -- Show renewal button for expired billboards
                        local renewButton = Instance.new("TextButton")
                        renewButton.Name = "RenewButton"
                        renewButton.Size = UDim2.new(0, 80, 0, 30)
                        renewButton.Position = UDim2.new(1, -90, 0, 45)
                        renewButton.BackgroundColor3 = Color3.fromRGB(50, 180, 100)
                        renewButton.BackgroundTransparency = 0.2
                        renewButton.BorderSizePixel = 0
                        renewButton.Text = "Renew"
                        renewButton.TextColor3 = TEXT_COLOR
                        renewButton.TextSize = 12
                        renewButton.Font = Enum.Font.GothamBold
                        renewButton.Parent = listingEntry
                        
                        local renewCorner = Instance.new("UICorner")
                        renewCorner.CornerRadius = UDim.new(0, 6)
                        renewCorner.Parent = renewButton
                        
                        -- Renewal button functionality (copied from listings GUI logic)
                        renewButton.MouseButton1Click:Connect(function()
                            local renewBillboardEvent = billboardFolder:FindFirstChild("RenewBillboardEvent")
                            if renewBillboardEvent then
                                print("DEBUG: Renew button clicked for billboard index:", i)
                                
                                -- Save original button properties to restore later
                                local originalText = renewButton.Text
                                local originalColor = renewButton.BackgroundColor3
                                local originalActive = renewButton.Active
                                
                                -- Update button appearance
                                renewButton.Text = "Renewing..."
                                renewButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                                renewButton.Active = false
                                
                                -- Fire server event to handle renewal
                                print("DEBUG: Firing renewBillboardEvent to server with index:", i)
                                renewBillboardEvent:FireServer(i)
                                
                                -- Listen for success event
                                local successConnection
                                local failureConnection  
                                local timeoutThread
                                
                                -- Get the renewal success/failed events
                                local renewSuccessEvent = billboardFolder:FindFirstChild("RenewBillboardSuccessEvent")
                                local renewFailedEvent = billboardFolder:FindFirstChild("RenewBillboardFailedEvent")
                                
                                if renewSuccessEvent then
                                    successConnection = renewSuccessEvent.OnClientEvent:Connect(function(successBillboardIndex)
                                        print("DEBUG: Received renewal success for billboard:", successBillboardIndex)
                                        if successBillboardIndex == i then
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
                                            showNotification("Billboard renewed successfully!", SUCCESS_COLOR)
                                            
                                            -- Force refresh the billboard listings (same as listings GUI)
                                            if currentRefreshFunction then
                                                print("DEBUG: Force refreshing billboard data immediately")
                                                currentRefreshFunction()
                                            else
                                                print("DEBUG: No refresh function available, reopening GUI")
                                                -- Close and reopen as fallback
                                                if currentListingsGui then
                                                    if currentListingsConnection then
                                                        currentListingsConnection:Disconnect()
                                                        currentListingsConnection = nil
                                                    end
                                                    currentListingsGui:Destroy()
                                                    currentListingsGui = nil
                                                    currentRefreshFunction = nil
                                                end
                                                task.wait(0.5)
                                                showBillboardListings()
                                            end
                                        end
                                    end)
                                end
                                
                                if renewFailedEvent then
                                    -- Listen for failure event
                                    failureConnection = renewFailedEvent.OnClientEvent:Connect(function(failedBillboardIndex)
                                        print("DEBUG: Received renewal failure for billboard:", failedBillboardIndex)
                                        if failedBillboardIndex == i then
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
                                            showNotification("Failed to renew billboard. Please try again.", ERROR_COLOR)
                                            
                                            -- Reset button
                                            renewButton.Text = originalText
                                            renewButton.BackgroundColor3 = originalColor
                                            renewButton.Active = originalActive
                                        end
                                    end)
                                end
                                
                                -- Timeout after 10 seconds to prevent hanging (same as listings GUI)
                                timeoutThread = task.spawn(function()
                                    task.wait(10)
                                    print("DEBUG: Renewal response timed out for billboard:", i)
                                    
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
                            else
                                showNotification("Renewal service not available!", ERROR_COLOR)
                            end
                        end)
                        
                        -- Update rotation status for expired billboards
                        rotationLabel.Text = "Status: Not in Rotation"
                        rotationLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                    else
                        -- Show remove button for active billboards
                local removeButton = Instance.new("TextButton")
                removeButton.Name = "RemoveButton"
                removeButton.Size = UDim2.new(0, 80, 0, 30)
                removeButton.Position = UDim2.new(1, -90, 0, 45)
                removeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                removeButton.BackgroundTransparency = 0.2
                removeButton.BorderSizePixel = 0
                removeButton.Text = "Remove"
                removeButton.TextColor3 = TEXT_COLOR
                removeButton.TextSize = 12
                removeButton.Font = Enum.Font.GothamBold
                removeButton.Parent = listingEntry
                
                local removeCorner = Instance.new("UICorner")
                removeCorner.CornerRadius = UDim.new(0, 6)
                removeCorner.Parent = removeButton
                
                -- Remove button functionality
                removeButton.MouseButton1Click:Connect(function()
                    -- Create confirmation dialog
                    local confirmFrame = Instance.new("Frame")
                    confirmFrame.Name = "ConfirmFrame"
                    confirmFrame.Size = UDim2.new(0, 300, 0, 150)
                    confirmFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
                    confirmFrame.BackgroundColor3 = BACKGROUND_COLOR
                    confirmFrame.BackgroundTransparency = 0.1
                    confirmFrame.BorderSizePixel = 0
                    confirmFrame.Parent = listingsGui
                    
                    local confirmCorner = Instance.new("UICorner")
                    confirmCorner.CornerRadius = UDim.new(0, 8)
                    confirmCorner.Parent = confirmFrame
                    
                    local confirmText = Instance.new("TextLabel")
                    confirmText.Size = UDim2.new(1, -20, 0.6, 0)
                    confirmText.Position = UDim2.new(0, 10, 0, 10)
                    confirmText.BackgroundTransparency = 1
                    confirmText.Text = "Are you sure you want to remove this billboard from rotation?"
                    confirmText.TextColor3 = TEXT_COLOR
                    confirmText.TextSize = 14
                    confirmText.Font = Enum.Font.GothamSemibold
                    confirmText.TextWrapped = true
                    confirmText.Parent = confirmFrame
                    
                    local confirmYes = Instance.new("TextButton")
                    confirmYes.Size = UDim2.new(0.4, -10, 0, 30)
                    confirmYes.Position = UDim2.new(0.1, 0, 0.7, 0)
                    confirmYes.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                    confirmYes.BackgroundTransparency = 0.2
                    confirmYes.BorderSizePixel = 0
                    confirmYes.Text = "Yes, Remove"
                    confirmYes.TextColor3 = TEXT_COLOR
                    confirmYes.TextSize = 12
                    confirmYes.Font = Enum.Font.GothamBold
                    confirmYes.Parent = confirmFrame
                    
                    local confirmNo = Instance.new("TextButton")
                    confirmNo.Size = UDim2.new(0.4, -10, 0, 30)
                    confirmNo.Position = UDim2.new(0.5, 10, 0.7, 0)
                    confirmNo.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    confirmNo.BackgroundTransparency = 0.2
                    confirmNo.BorderSizePixel = 0
                    confirmNo.Text = "Cancel"
                    confirmNo.TextColor3 = TEXT_COLOR
                    confirmNo.TextSize = 12
                    confirmNo.Font = Enum.Font.GothamBold
                    confirmNo.Parent = confirmFrame
                    
                    local yesCorner = Instance.new("UICorner")
                    yesCorner.CornerRadius = UDim.new(0, 6)
                    yesCorner.Parent = confirmYes
                    
                    local noCorner = Instance.new("UICorner")
                    noCorner.CornerRadius = UDim.new(0, 6)
                    noCorner.Parent = confirmNo
                    
                    confirmYes.MouseButton1Click:Connect(function()
                        -- Remove billboard via server
                        local removeBillboardEvent = billboardFolder:FindFirstChild("RemoveBillboardEvent")
                        if removeBillboardEvent then
                            removeBillboardEvent:FireServer()
                            listingsGui:Destroy()
                        else
                            showNotification("Remove service not available!", ERROR_COLOR)
                        end
                    end)
                    
                    confirmNo.MouseButton1Click:Connect(function()
                        confirmFrame:Destroy()
                    end)
                end)
                        
                        -- Update rotation status for active billboards
                        rotationLabel.Text = "Status: In Rotation"
                        rotationLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
                    end
                
                yOffset = yOffset + 130  -- Space between entries
            end
            
            -- Update scroll canvas size
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)
        else
            -- No billboards found
            local noDataLabel = Instance.new("TextLabel")
            noDataLabel.Name = "NoDataLabel"
            noDataLabel.Size = UDim2.new(1, -20, 0, 50)
            noDataLabel.Position = UDim2.new(0, 10, 0, 10)
            noDataLabel.BackgroundTransparency = 1
            noDataLabel.Text = "You don't have any active billboard rentals."
            noDataLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            noDataLabel.TextSize = 14
            noDataLabel.Font = Enum.Font.GothamMedium
            noDataLabel.TextXAlignment = Enum.TextXAlignment.Center
            noDataLabel.Parent = scrollFrame
            
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 70)
        end
    else
        showNotification("Failed to get billboard data!", ERROR_COLOR)
        end
    end
    
    -- Initial data load
    refreshBillboardData(true) -- Manual refresh, no cooldown
    
    -- Store refresh function for external access (like renewal success)
    currentRefreshFunction = function()
        refreshBillboardData(true) -- Manual refresh when called externally
    end
    print("DEBUG: Refresh function stored for billboard GUI")
    
    -- Set up auto-refresh system with heartbeat
    local lastUpdateTime = os.time()
    local lastDataRefreshTime = os.time()
    local needsRefresh = false
    local DATA_REFRESH_COOLDOWN = 30 -- Only refresh data from server every 30 seconds maximum for AUTO-REFRESH
    
    currentListingsConnection = RunService.Heartbeat:Connect(function()
        local currentTime = os.time()
        
        -- Update time displays every second
        if currentTime - lastUpdateTime >= 1 then
            lastUpdateTime = currentTime
            
            -- Update time displays for each entry
            for _, child in pairs(scrollFrame:GetChildren()) do
                if child.Name:match("BillboardEntry") then
                    local expiresAt = child:GetAttribute("ExpiresAt")
                    local timeLabel = child:FindFirstChild("TimeLabel")
                    local rotationLabel = child:FindFirstChild("RotationLabel")
                    local renewButton = child:FindFirstChild("RenewButton")
                    local removeButton = child:FindFirstChild("RemoveButton")
                    
                    if expiresAt and timeLabel then
                        local timeLeft = expiresAt - currentTime
                        local wasExpired = timeLabel.Text:find("EXPIRED") ~= nil
                        local isExpired = timeLeft <= 0
                        
                        if isExpired and not wasExpired then
                            -- Billboard just expired, mark for refresh
                            needsRefresh = true
                        elseif not isExpired then
                            -- Update time display
                            local hours = math.floor(timeLeft / 3600)
                            local minutes = math.floor((timeLeft % 3600) / 60)
                            timeLabel.Text = "Expires in: " .. hours .. "h " .. minutes .. "m"
                            timeLabel.TextColor3 = timeLeft > 3600 and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 165, 0)
                        end
                    end
                end
            end
            
            -- Only apply cooldown to AUTO-REFRESH from expiration events, not manual refreshes
            if needsRefresh and (currentTime - lastDataRefreshTime >= DATA_REFRESH_COOLDOWN) then
                needsRefresh = false
                lastDataRefreshTime = currentTime
                print("DEBUG: Auto-refreshing billboard data due to expiration (cooldown applied)")
                refreshBillboardData(false) -- Auto refresh due to expiration
            end
        end
    end)
    
    -- Clean up connection when GUI is destroyed
    listingsGui.AncestryChanged:Connect(function()
        if not listingsGui.Parent then
            if currentListingsConnection then
                currentListingsConnection:Disconnect()
                currentListingsConnection = nil
            end
            currentListingsGui = nil
            currentRefreshFunction = nil
        end
    end)
    
    -- Animate in
    listingsFrame.Size = UDim2.new(0, 0, 0, 0)
    listingsFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    local tween = TweenService:Create(
        listingsFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Size = UDim2.new(0, 500, 0, 400),
            Position = UDim2.new(0.5, -250, 0.5, -200)
        }
    )
    tween:Play()
end

-- Function to toggle GUI visibility
local function toggleGUI()
    if not mainFrame then return end
    
    isGUIVisible = not isGUIVisible
    
    if isGUIVisible then
        mainFrame.Visible = true
        -- Animate in with scale effect
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        
        local tween = TweenService:Create(
            mainFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {
                Size = UDim2.new(0, 400, 0, 350),
                Position = UDim2.new(0.5, -200, 0.5, -175)
            }
        )
        tween:Play()
    else
        -- Animate out with scale effect
        local tween = TweenService:Create(
            mainFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            {
                Size = UDim2.new(0, 0, 0, 0),
                Position = UDim2.new(0.5, 0, 0.5, 0)
            }
        )
        tween:Play()
        tween.Completed:Connect(function()
            mainFrame.Visible = false
        end)
    end
end

-- Function to create the main GUI
local function createGUI()
    -- Remove existing GUI if it exists
    local existingGui = playerGui:FindFirstChild("RentBillboardGUI")
    if existingGui then
        existingGui:Destroy()
    end
    
    -- Create main ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RentBillboardGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Create main frame (centered on screen)
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "BillboardFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 350)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
    mainFrame.BackgroundColor3 = BACKGROUND_COLOR
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Add shadow effect
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(0, -5, 0, -5)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.7
    shadow.BorderSizePixel = 0
    shadow.ZIndex = mainFrame.ZIndex - 1
    shadow.Parent = mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow
    
    -- Add title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -50, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Rent Billboard"
    titleLabel.TextColor3 = TITLE_COLOR
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.Parent = mainFrame
    
    -- Add close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.BackgroundTransparency = 0.2
    closeButton.BorderSizePixel = 0
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = mainFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    -- Close button functionality
    closeButton.MouseButton1Click:Connect(function()
        toggleGUI()
    end)
    
    -- Asset ID input
    local inputLabel = Instance.new("TextLabel")
    inputLabel.Name = "InputLabel"
    inputLabel.Size = UDim2.new(1, -20, 0, 20)
    inputLabel.Position = UDim2.new(0, 10, 0, 50)
    inputLabel.BackgroundTransparency = 1
    inputLabel.Text = "Enter Asset ID:"
    inputLabel.TextColor3 = TEXT_COLOR
    inputLabel.TextSize = 14
    inputLabel.Font = Enum.Font.GothamSemibold
    inputLabel.TextXAlignment = Enum.TextXAlignment.Left
    inputLabel.Parent = mainFrame
    
    local assetInput = Instance.new("TextBox")
    assetInput.Name = "AssetInput"
    assetInput.Size = UDim2.new(1, -20, 0, 35)
    assetInput.Position = UDim2.new(0, 10, 0, 75)
    assetInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    assetInput.BackgroundTransparency = 0.3
    assetInput.BorderSizePixel = 0
    assetInput.Text = ""
    assetInput.PlaceholderText = "Enter asset ID (numbers only)"
    assetInput.TextColor3 = TEXT_COLOR
    assetInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    assetInput.TextSize = 14
    assetInput.Font = Enum.Font.Gotham
    assetInput.Parent = mainFrame
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = assetInput
    
    -- Preview frame
    local previewLabel = Instance.new("TextLabel")
    previewLabel.Name = "PreviewLabel"
    previewLabel.Size = UDim2.new(1, -20, 0, 20)
    previewLabel.Position = UDim2.new(0, 10, 0, 120)
    previewLabel.BackgroundTransparency = 1
    previewLabel.Text = "Preview:"
    previewLabel.TextColor3 = TEXT_COLOR
    previewLabel.TextSize = 14
    previewLabel.Font = Enum.Font.GothamSemibold
    previewLabel.TextXAlignment = Enum.TextXAlignment.Left
    previewLabel.Parent = mainFrame
    
    local previewFrame = Instance.new("Frame")
    previewFrame.Name = "PreviewFrame"
    previewFrame.Size = UDim2.new(1, -20, 0, 120)
    previewFrame.Position = UDim2.new(0, 10, 0, 145)
    previewFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    previewFrame.BackgroundTransparency = 0.3
    previewFrame.BorderSizePixel = 0
    previewFrame.Parent = mainFrame
    
    local previewCorner = Instance.new("UICorner")
    previewCorner.CornerRadius = UDim.new(0, 6)
    previewCorner.Parent = previewFrame
    
    -- Duration info
    local durationLabel = Instance.new("TextLabel")
    durationLabel.Name = "DurationLabel"
    durationLabel.Size = UDim2.new(1, -20, 0, 20)
    durationLabel.Position = UDim2.new(0, 10, 0, 275)
    durationLabel.BackgroundTransparency = 1
    durationLabel.Text = "Duration: " .. (hasVIPGamepass() and "7 days (VIP)" or "3 days")
    durationLabel.TextColor3 = hasVIPGamepass() and TITLE_COLOR or TEXT_COLOR
    durationLabel.TextSize = 12
    durationLabel.Font = Enum.Font.GothamMedium
    durationLabel.TextXAlignment = Enum.TextXAlignment.Left
    durationLabel.Parent = mainFrame
    
    -- Price info
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "PriceLabel"
    priceLabel.Size = UDim2.new(1, -20, 0, 15)
    priceLabel.Position = UDim2.new(0, 10, 0, 295)
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = "💰 Robux Purchase Required"
    priceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    priceLabel.TextSize = 11
    priceLabel.Font = Enum.Font.GothamMedium
    priceLabel.TextXAlignment = Enum.TextXAlignment.Left
    priceLabel.Parent = mainFrame
    
    -- Rent button
    local rentButton = Instance.new("TextButton")
    rentButton.Name = "RentButton"
    rentButton.Size = UDim2.new(0.48, -5, 0, 35)
    rentButton.Position = UDim2.new(0, 10, 0, 310)
    rentButton.BackgroundColor3 = BUTTON_COLOR
    rentButton.BackgroundTransparency = 0.2
    rentButton.BorderSizePixel = 0
    rentButton.Text = "Purchase Billboard Rental"
    rentButton.TextColor3 = TEXT_COLOR
    rentButton.TextSize = 14
    rentButton.Font = Enum.Font.GothamBold
    rentButton.Parent = mainFrame
    
    -- My Billboards button
    local myBillboardsButton = Instance.new("TextButton")
    myBillboardsButton.Name = "MyBillboardsButton"
    myBillboardsButton.Size = UDim2.new(0.48, -5, 0, 35)
    myBillboardsButton.Position = UDim2.new(0.52, 5, 0, 310)
    myBillboardsButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
    myBillboardsButton.BackgroundTransparency = 0.2
    myBillboardsButton.BorderSizePixel = 0
    myBillboardsButton.Text = "My Billboards"
    myBillboardsButton.TextColor3 = TEXT_COLOR
    myBillboardsButton.TextSize = 14
    myBillboardsButton.Font = Enum.Font.GothamBold
    myBillboardsButton.Parent = mainFrame
    
    local rentCorner = Instance.new("UICorner")
    rentCorner.CornerRadius = UDim.new(0, 8)
    rentCorner.Parent = rentButton
    
    local myBillboardsCorner = Instance.new("UICorner")
    myBillboardsCorner.CornerRadius = UDim.new(0, 8)
    myBillboardsCorner.Parent = myBillboardsButton
    
    -- Input change handler for preview
    assetInput.Changed:Connect(function(property)
        if property == "Text" then
            local assetId = assetInput.Text:match("%d+")
            if assetId then
                updateAssetPreview(assetId, previewFrame)
            else
                if currentPreviewAsset then
                    currentPreviewAsset:Destroy()
                    currentPreviewAsset = nil
                end
            end
        end
    end)
    
    -- Rent button functionality
    rentButton.MouseButton1Click:Connect(function()
        local assetId = assetInput.Text:match("%d+")
        if not assetId then
            showNotification("Please enter a valid asset ID!", ERROR_COLOR)
            return
        end
        
        if rentBillboardEvent then
            rentBillboardEvent:FireServer(assetId)
        else
            showNotification("Billboard service not available!", ERROR_COLOR)
        end
    end)
    
    -- Button hover effects
    rentButton.MouseEnter:Connect(function()
        TweenService:Create(
            rentButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.1}
        ):Play()
    end)
    
    rentButton.MouseLeave:Connect(function()
        TweenService:Create(
            rentButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.2}
        ):Play()
    end)
    
    -- My Billboards button hover effects
    myBillboardsButton.MouseEnter:Connect(function()
        TweenService:Create(
            myBillboardsButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.1}
        ):Play()
    end)
    
    myBillboardsButton.MouseLeave:Connect(function()
        TweenService:Create(
            myBillboardsButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.2}
        ):Play()
    end)
    
    -- My Billboards button functionality
    myBillboardsButton.MouseButton1Click:Connect(function()
        showBillboardListings()
    end)
end

-- Create toggle button (positioned in bottom right corner)
local function createToggleButton()
    toggleButton = Instance.new("TextButton")
    toggleButton.Name = "BillboardToggle"
    toggleButton.Size = UDim2.new(0, 50, 0, 50)
    toggleButton.Position = UDim2.new(1, -70, 1, -70) -- Bottom right corner
    toggleButton.BackgroundColor3 = BACKGROUND_COLOR
    toggleButton.BackgroundTransparency = 0.2
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = "📺"
    toggleButton.TextColor3 = TITLE_COLOR
    toggleButton.TextSize = 24
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Parent = screenGui
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 12)
    buttonCorner.Parent = toggleButton
    
    -- Button functionality
    toggleButton.MouseButton1Click:Connect(function()
        toggleGUI()
    end)
    
    -- Button hover effects
    toggleButton.MouseEnter:Connect(function()
        TweenService:Create(
            toggleButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Size = UDim2.new(0, 55, 0, 55),
                Position = UDim2.new(1, -72.5, 1, -72.5),
                BackgroundTransparency = 0.1
            }
        ):Play()
    end)
    
    toggleButton.MouseLeave:Connect(function()
        TweenService:Create(
            toggleButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Size = UDim2.new(0, 50, 0, 50),
                Position = UDim2.new(1, -70, 1, -70),
                BackgroundTransparency = 0.2
            }
        ):Play()
    end)
    
    toggleButton.MouseButton1Down:Connect(function()
        TweenService:Create(
            toggleButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(1, -69, 1, -69)}
        ):Play()
    end)
    
    toggleButton.MouseButton1Up:Connect(function()
        TweenService:Create(
            toggleButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 55, 0, 55), Position = UDim2.new(1, -72.5, 1, -72.5)}
        ):Play()
    end)
end

-- Function to initialize GUI
local function initializeGUI()
    createGUI()
    createToggleButton()
end

-- Connect to server events
if rentBillboardEvent then
    print("DEBUG: rentBillboardEvent found, setting up basic connections...")
    
    -- Use ReplicatedStorage directly for basic events
    local function connectToBasicEvents()
        print("DEBUG: Connecting to basic events...")
        
        -- Wait for the RentBillboard folder in ReplicatedStorage
        local rentBillboardFolder = ReplicatedStorage:WaitForChild("RentBillboard", 30)
        if not rentBillboardFolder then
            warn("DEBUG: Failed to find RentBillboard folder in ReplicatedStorage")
            return
        end
        
        print("DEBUG: Found RentBillboard folder in ReplicatedStorage")
        
        -- Handle server responses for billboard rental (success/failure)
        local billboardResponseEvent = rentBillboardFolder:WaitForChild("BillboardResponseEvent", 30)
    if billboardResponseEvent then
        billboardResponseEvent.OnClientEvent:Connect(function(success, message, shouldCloseGUI)
                print("DEBUG: BillboardResponseEvent received - Success:", success, "Message:", message)
            if success then
                showNotification(message, SUCCESS_COLOR)
                if shouldCloseGUI then
                        toggleGUI() -- Close main rental GUI on success
                end
            else
                showNotification(message, ERROR_COLOR)
            end
        end)
            print("DEBUG: Connected to BillboardResponseEvent")
        else
            warn("DEBUG: Failed to find BillboardResponseEvent")
        end
        
        -- NOTE: Renewal success/failure events are handled via auto-refresh solution
        -- instead of RemoteEvents due to communication issues. The renewal button
        -- automatically closes and reopens the billboard listings GUI after renewal.
        
        print("DEBUG: Basic event connections complete")
    end
    
    -- Connect to events in a separate thread
    task.spawn(connectToBasicEvents)
else
    warn("rentBillboardEvent not found - billboard system will not work")
end

-- Initialize the GUI
task.spawn(function()
    task.wait(2) -- Wait for other systems to load
    initializeGUI()
end)

print("Rent Billboard GUI initialized") 