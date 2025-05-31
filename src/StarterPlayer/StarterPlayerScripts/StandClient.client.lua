-- StandClient.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Get the clothing template function
local getClothingTemplateFunc = ReplicatedStorage:WaitForChild("GetClothingTemplateFunc")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Variables
local currentStand = nil
local clothingGui = nil -- Will store the GUI instance
local listingsGui = nil -- Will store the listings selection GUI
local clothingSelection = {
    Platform1 = nil,
    Platform2 = nil,
    Platform3 = nil,
    Platform4 = nil
}

-- Remote events (will be initialized when needed)
local standEvents = nil
local claimStandEvent = nil
local releaseStandEvent = nil
local updateStandDisplayEvent = nil
local updateTextSignEvent = nil
local notificationEvent = nil
local ListingsData = nil

-- Cache for player listings to improve loading speed
local cachedListings = nil
local cacheTime = 0
local CACHE_DURATION = 30 -- Cache for 30 seconds



-- Initialize remote events (lazy loading)
local function getStandEvents()
    if not standEvents then
        standEvents = ReplicatedStorage:WaitForChild("StandEvents", 10)
        if standEvents then
            claimStandEvent = standEvents:WaitForChild("ClaimStandEvent", 5)
            releaseStandEvent = standEvents:WaitForChild("ReleaseStandEvent", 5)
            updateStandDisplayEvent = standEvents:WaitForChild("UpdateStandDisplayEvent", 5)
            updateTextSignEvent = standEvents:WaitForChild("UpdateTextSignEvent", 5)
        else
            warn("StandEvents folder not found!")
        end
    end
    return standEvents ~= nil
end

-- Get the real listings data using RemoteFunction
local function getListingsData()
    local getListingsDataRemote = ReplicatedStorage:WaitForChild("GetListingsData", 10)
    if getListingsDataRemote then
        return getListingsDataRemote
    else
        warn("GetListingsData RemoteFunction not found!")
        return nil
    end
end

-- Function to get player's listings
local function getPlayerListings()
    -- Check if we have cached data that's still valid
    local currentTime = tick()
    if cachedListings and (currentTime - cacheTime) < CACHE_DURATION then
        return cachedListings
    end
    
    local getListingsDataRemote = getListingsData()
    if getListingsDataRemote then
        local success, result = pcall(function()
            return getListingsDataRemote:InvokeServer()
        end)
        
        if success and result then
            -- Convert the ProfileStore data format to our expected format
            local listings = {}
            for key, listing in pairs(result) do
                -- Check for shirt
                if listing.shirtID and listing.shirtID ~= "" then
                    local shirtListing = {
                        id = key .. "_shirt",
                        assetId = listing.shirtID,
                        assetType = "Shirt",
                        price = listing.price or 0,
                        expired = false,
                        thumbnail = "rbxassetid://0"
                    }
                    table.insert(listings, shirtListing)
                end
                
                -- Check for pants
                if listing.pantsID and listing.pantsID ~= "" then
                    local pantsListing = {
                        id = key .. "_pants",
                        assetId = listing.pantsID,
                        assetType = "Pants",
                        price = listing.price or 0,
                        expired = false,
                        thumbnail = "rbxassetid://0"
                    }
                    table.insert(listings, pantsListing)
                end
            end
            
            -- Cache the results
            cachedListings = listings
            cacheTime = currentTime
            
            return listings
        else
            warn("Failed to get listings from server:", result)
        end
    end
    
    -- Fallback: return empty array
    return {}
end

-- Function to update the clothing display on the stand
local function updateClothingDisplay()
    if not currentStand then
        return
    end
    
    if not getStandEvents() then
        warn("Failed to get stand events for updating display")
        return
    end
    
    -- Send update to server
    updateStandDisplayEvent:FireServer(currentStand, clothingSelection)
end

-- Function to update platform status in the main GUI
local function updatePlatformStatus(platformKey, text)
    if not clothingGui then 
        return 
    end
    
    local mainFrame = clothingGui:FindFirstChild("MainFrame")
    if not mainFrame then 
        return 
    end
    
    local platformSection = mainFrame:FindFirstChild(platformKey .. "Section")
    if not platformSection then 
        return 
    end
    
    local statusLabel = platformSection:FindFirstChild("StatusLabel")
    if statusLabel then
        statusLabel.Text = text
    end
    
    -- Update the select button to show "Change Clothing" and make it green
    local selectButton = platformSection:FindFirstChild("SelectButton")
    if selectButton then
        selectButton.Text = "Change Clothing"
        selectButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40) -- Green color
    end
end

-- Function to create listings selection GUI
local function createListingsSelectionGui(platformKey)
    -- Destroy existing GUI if it exists
    if listingsGui then
        listingsGui:Destroy()
    end
    listingsGui = Instance.new("ScreenGui")
    listingsGui.Name = "ListingsSelectionGui"
    listingsGui.ResetOnSpawn = false
    listingsGui.DisplayOrder = 11 -- Above clothing selection GUI
    listingsGui.Parent = player.PlayerGui
    
    -- Main frame
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 600, 0, 400)
    frame.Position = UDim2.new(0.5, -300, 0.5, -200)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = listingsGui
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    -- Title label
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -100, 0, 40)
    titleLabel.Position = UDim2.new(0, 20, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 24
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = "Select Clothing for " .. platformKey
    titleLabel.Parent = frame
    
    -- Close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.Text = "X"
    closeButton.Parent = frame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    -- Listings scroll frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ListingsScrollFrame"
    scrollFrame.Size = UDim2.new(1, -40, 1, -70)
    scrollFrame.Position = UDim2.new(0, 20, 0, 60)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be updated based on content
    scrollFrame.Parent = frame
    
    -- Grid layout for listings
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 120, 0, 150)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame
    
    -- Get player's listings
    local listings = getPlayerListings()
    
    -- Populate listings
    for i, listing in ipairs(listings) do
        local listingFrame = Instance.new("Frame")
        listingFrame.Name = "Listing_" .. i
        listingFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        listingFrame.BorderSizePixel = 0
        listingFrame.LayoutOrder = i
        listingFrame.Parent = scrollFrame
        
        local listingCorner = Instance.new("UICorner")
        listingCorner.CornerRadius = UDim.new(0, 6)
        listingCorner.Parent = listingFrame
        
        -- NPC Preview (like in ListingsGUI)
        local previewFrame = Instance.new("ViewportFrame")
        previewFrame.Name = "PreviewFrame"
        previewFrame.Size = UDim2.new(1, -20, 0, 80)
        previewFrame.Position = UDim2.new(0, 10, 0, 10)
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
        if listing.assetType == "Shirt" then
            spawn(function()
                local success, template = pcall(function()
                    return getClothingTemplateFunc:InvokeServer(listing.assetId, "Shirt")
                end)
                
                if success and template then
                    local shirt = Instance.new("Shirt")
                    shirt.ShirtTemplate = template
                    shirt.Parent = npcModel
                else
                    -- Fallback
            local shirt = Instance.new("Shirt")
            shirt.ShirtTemplate = "rbxassetid://" .. listing.assetId
            shirt.Parent = npcModel
                end
            end)
        elseif listing.assetType == "Pants" then
            spawn(function()
                local success, template = pcall(function()
                    return getClothingTemplateFunc:InvokeServer(listing.assetId, "Pants")
                end)
                
                if success and template then
                    local pants = Instance.new("Pants")
                    pants.PantsTemplate = template
                    pants.Parent = npcModel
                else
                    -- Fallback
            local pants = Instance.new("Pants")
            pants.PantsTemplate = "rbxassetid://" .. listing.assetId
            pants.Parent = npcModel
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
        camera.CFrame = CFrame.new(head.Position + Vector3.new(0, -1.2, -5.2), head.Position + Vector3.new(0, -1.2, 0))
        
        -- Rotate the model slowly
        local RunService = game:GetService("RunService")
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
        
        -- Status indicator removed - not needed for stand selection
        
        -- Asset info
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Name = "InfoLabel"
        infoLabel.Size = UDim2.new(1, -10, 0, 18)
        infoLabel.Position = UDim2.new(0, 5, 0, 95)
        infoLabel.BackgroundTransparency = 1
        infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        infoLabel.TextSize = 12
        infoLabel.Font = Enum.Font.GothamSemibold
        infoLabel.Text = listing.assetType .. " #" .. listing.assetId
        infoLabel.TextScaled = false
        infoLabel.TextWrapped = true
        infoLabel.Parent = listingFrame
        
        -- Select button
        local selectButton = Instance.new("TextButton")
        selectButton.Name = "SelectButton"
        selectButton.Size = UDim2.new(1, -20, 0, 22)
        selectButton.Position = UDim2.new(0, 10, 1, -30)
        selectButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
        selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        selectButton.Font = Enum.Font.GothamSemibold
        selectButton.TextSize = 12
        selectButton.Text = "Select"
        selectButton.Parent = listingFrame
        
        local selectCorner = Instance.new("UICorner")
        selectCorner.CornerRadius = UDim.new(0, 4)
        selectCorner.Parent = selectButton
        
        -- Button press effect
        selectButton.MouseButton1Down:Connect(function()
            selectButton:TweenSize(
                UDim2.new(1, -24, 0, 20),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.1,
                true
            )
        end)
        
        selectButton.MouseButton1Up:Connect(function()
            -- Safety check to ensure button still exists and has a parent
            if selectButton and selectButton.Parent then
                selectButton:TweenSize(
                    UDim2.new(1, -20, 0, 22),
                    Enum.EasingDirection.Out,
                    Enum.EasingStyle.Quad,
                    0.1,
                    true
                )
            end
        end)
        
        -- Connect selection logic
        selectButton.MouseButton1Click:Connect(function()
            -- Store the selection data
            clothingSelection[platformKey] = {
                id = listing.id,
                assetId = listing.assetId,
                assetType = listing.assetType
            }
            
            -- Update the platform status in the main clothing GUI
            updatePlatformStatus(platformKey, listing.assetType .. " #" .. listing.assetId)
            
            -- Close the listings selection GUI
            listingsGui:Destroy()
            listingsGui = nil
            
            -- Show the Stand Manager GUI again
            if clothingGui then
                clothingGui.Enabled = true
            end
            
            -- Update the display on the stand
            updateClothingDisplay()
        end)
    end
    
    -- Update canvas size based on content
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.ceil(#listings / 4) * 160)
    
    -- Close button event
    closeButton.MouseButton1Click:Connect(function()
        listingsGui:Destroy()
        listingsGui = nil
        
        -- Show the Stand Manager GUI again when closing without selection
        if clothingGui then
            clothingGui.Enabled = true
        end
    end)
    
    return listingsGui
end

-- Create GUI for clothing selection
local function createClothingSelectionGui()
    -- Check if the GUI already exists
    if player.PlayerGui:FindFirstChild("ClothingSelectionGui") then
        player.PlayerGui:FindFirstChild("ClothingSelectionGui"):Destroy()
    end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ClothingSelectionGui"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false -- Hidden by default
    screenGui.DisplayOrder = 10 -- Ensure it's on top
    screenGui.Parent = player.PlayerGui
    
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 400, 0, 380) -- Increased height for TextSign section
    frame.Position = UDim2.new(0.5, -200, 0.5, -190) -- Adjusted position
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = frame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 20
    titleLabel.Text = "Stand Management"
    titleLabel.Parent = frame
    
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Text = "X"
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.Parent = frame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    -- Add platform selection sections
    for i = 1, 4 do
        local platformKey = "Platform" .. i
        
        local platformSection = Instance.new("Frame")
        platformSection.Name = platformKey .. "Section"
        platformSection.Size = UDim2.new(0.5, -20, 0, 100)
        platformSection.Position = UDim2.new(i % 2 == 0 and 0.5 or 0, 10, i <= 2 and 0.15 or 0.45, 0)
        platformSection.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        platformSection.BackgroundTransparency = 0.5
        platformSection.BorderSizePixel = 0
        platformSection.Parent = frame
        
        local platformCorner = Instance.new("UICorner")
        platformCorner.CornerRadius = UDim.new(0, 6)
        platformCorner.Parent = platformSection
        
        local platformLabel = Instance.new("TextLabel")
        platformLabel.Name = "Label"
        platformLabel.Size = UDim2.new(1, 0, 0, 30)
        platformLabel.Position = UDim2.new(0, 0, 0, 0)
        platformLabel.BackgroundTransparency = 1
        platformLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        platformLabel.Font = Enum.Font.GothamSemibold
        platformLabel.TextSize = 16
        platformLabel.Text = "Platform " .. i
        platformLabel.Parent = platformSection
        
        local selectButton = Instance.new("TextButton")
        selectButton.Name = "SelectButton"
        selectButton.Size = UDim2.new(0.8, 0, 0, 30)
        selectButton.Position = UDim2.new(0.1, 0, 0, 40)
        selectButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
        selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        selectButton.Font = Enum.Font.GothamSemibold
        selectButton.TextSize = 14
        selectButton.Text = "Select Clothing"
        selectButton.Parent = platformSection
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 4)
        buttonCorner.Parent = selectButton
        
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Name = "StatusLabel"
        statusLabel.Size = UDim2.new(1, 0, 0, 20)
        statusLabel.Position = UDim2.new(0, 0, 0, 75)
        statusLabel.BackgroundTransparency = 1
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.TextSize = 12
        statusLabel.Text = "Empty"
        statusLabel.Parent = platformSection
        
        -- Connect button events
        selectButton.MouseButton1Click:Connect(function()
            -- Hide the Stand Manager GUI to prevent overlap
            if clothingGui then
                clothingGui.Enabled = false
            end
            
            -- Open the listings selection GUI
            createListingsSelectionGui(platformKey)
        end)
    end
    
    -- Close button event
    closeButton.MouseButton1Click:Connect(function()
        screenGui.Enabled = false
    end)
    
    -- Add TextSign section
    local textSignSection = Instance.new("Frame")
    textSignSection.Name = "TextSignSection"
    textSignSection.Size = UDim2.new(1, -20, 0, 80)
    textSignSection.Position = UDim2.new(0, 10, 0, 280) -- Position after platform sections with more spacing
    textSignSection.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    textSignSection.BorderSizePixel = 0
    textSignSection.Parent = frame
    
    local textSignCorner = Instance.new("UICorner")
    textSignCorner.CornerRadius = UDim.new(0, 6)
    textSignCorner.Parent = textSignSection
    
    local textSignLabel = Instance.new("TextLabel")
    textSignLabel.Name = "TextSignLabel"
    textSignLabel.Size = UDim2.new(1, 0, 0, 25)
    textSignLabel.Position = UDim2.new(0, 0, 0, 5)
    textSignLabel.BackgroundTransparency = 1
    textSignLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textSignLabel.Font = Enum.Font.GothamBold
    textSignLabel.TextSize = 16
    textSignLabel.Text = "Sign Message"
    textSignLabel.Parent = textSignSection
    
    local textInput = Instance.new("TextBox")
    textInput.Name = "TextInput"
    textInput.Size = UDim2.new(1, -80, 0, 30) -- Made smaller to fit the button
    textInput.Position = UDim2.new(0, 10, 0, 30)
    textInput.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    textInput.BorderSizePixel = 0
    textInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    textInput.Font = Enum.Font.Gotham
    textInput.TextSize = 14
    textInput.PlaceholderText = "Enter your message here (max 100 characters)"
    textInput.Text = ""
    textInput.ClearTextOnFocus = false
    textInput.Parent = textSignSection
    
    local textInputCorner = Instance.new("UICorner")
    textInputCorner.CornerRadius = UDim.new(0, 4)
    textInputCorner.Parent = textInput
    
    -- Add Enter button
    local enterButton = Instance.new("TextButton")
    enterButton.Name = "EnterButton"
    enterButton.Size = UDim2.new(0, 60, 0, 30)
    enterButton.Position = UDim2.new(1, -70, 0, 30) -- Position next to the text input
    enterButton.BackgroundColor3 = Color3.fromRGB(40, 180, 40) -- Green color
    enterButton.BorderSizePixel = 0
    enterButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    enterButton.Font = Enum.Font.GothamBold
    enterButton.TextSize = 14
    enterButton.Text = "Enter"
    enterButton.Parent = textSignSection
    
    local enterButtonCorner = Instance.new("UICorner")
    enterButtonCorner.CornerRadius = UDim.new(0, 4)
    enterButtonCorner.Parent = enterButton
    
    -- Function to update the sign
    local function updateSign()
        if getStandEvents() and updateTextSignEvent then
            local text = textInput.Text
            updateTextSignEvent:FireServer(text)
        end
    end
    
    -- Connect TextInput to update TextSign (keyboard Enter)
    textInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            updateSign()
        end
    end)
    
    -- Connect Enter button to update TextSign (mouse click)
    enterButton.MouseButton1Click:Connect(function()
        updateSign()
    end)
    
    -- Add key guide label
    local keyGuideLabel = Instance.new("TextLabel")
    keyGuideLabel.Name = "KeyGuideLabel"
    keyGuideLabel.Size = UDim2.new(1, 0, 0, 20)
    keyGuideLabel.Position = UDim2.new(0, 0, 1, -20)
    keyGuideLabel.BackgroundTransparency = 1
    keyGuideLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    keyGuideLabel.Font = Enum.Font.Gotham
    keyGuideLabel.TextSize = 12
    keyGuideLabel.Text = "Press F to toggle this menu"
    keyGuideLabel.Parent = frame

    return screenGui
end

-- Handle keypress for opening clothing selection
local function handleInput(input, gameProcessed)
    if gameProcessed then 
        return 
    end
    
    if input.KeyCode == Enum.KeyCode.F then
        if currentStand then
            -- Toggle clothing selection GUI
            if clothingGui then
                clothingGui.Enabled = not clothingGui.Enabled
            else
                -- Recreate GUI if it doesn't exist
                clothingGui = createClothingSelectionGui()
                clothingGui.Enabled = true
            end
        end
    end
end

-- Setup events and input handling
local function setupStandSystem()
    -- Connect input events first
    UserInputService.InputBegan:Connect(handleInput)
    
    -- Wait for and connect to stand events
    task.spawn(function()
        if getStandEvents() then
            -- Connect to ClaimStandEvent
            claimStandEvent.OnClientEvent:Connect(function(standName)
                currentStand = standName
                
                -- Create clothing selection GUI if it doesn't exist
                clothingGui = createClothingSelectionGui()
                
                -- Reset clothing selection
                for key, _ in pairs(clothingSelection) do
                    clothingSelection[key] = nil
                end
                
                -- Update GUI labels
                if clothingGui then
                    local mainFrame = clothingGui:FindFirstChild("MainFrame")
                    if mainFrame then
                        for i = 1, 4 do
                            local section = mainFrame:FindFirstChild("Platform" .. i .. "Section")
                            if section then
                                local statusLabel = section:FindFirstChild("StatusLabel")
                                if statusLabel then
                                    statusLabel.Text = "Empty"
                                end
                                
                                -- Reset button to default state
                                local selectButton = section:FindFirstChild("SelectButton")
                                if selectButton then
                                    selectButton.Text = "Select Clothing"
                                    selectButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215) -- Blue color
                                end
                            end
                        end
                    end
                end
            end)
            
            -- Connect to ReleaseStandEvent
            releaseStandEvent.OnClientEvent:Connect(function()
                currentStand = nil
                
                -- Hide and destroy clothing selection GUI
                if clothingGui then
                    clothingGui.Enabled = false
                    clothingGui:Destroy()
                    clothingGui = nil
                end
                
                -- Also destroy listings GUI if open
                if listingsGui then
                    listingsGui:Destroy()
                    listingsGui = nil
                end
            end)
        else
            warn("Failed to initialize stand events, will retry in 2 seconds")
            task.wait(2)
            setupStandSystem()
        end
    end)
end

-- Start the setup
setupStandSystem() 