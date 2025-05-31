-- VIP Player Inspector Client Script
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get the clothing template function
local getClothingTemplateFunc = ReplicatedStorage:WaitForChild("GetClothingTemplateFunc")

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

-- GUI variables
local inspectorGui = nil
local currentInspectedPlayer = nil

-- Function to check if player owns VIP gamepass
local function hasVIPGamepass()
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
    end)
    return success and ownsGamepass
end

-- Function to get active listings for a player (via server using ProfileStore)
local function getPlayerListings(userId)
    print("DEBUG: Client requesting listings for userId:", userId)
    
    -- Wait for the RemoteFunction to be available
    local getListingsEvent = ReplicatedStorage:WaitForChild("GetPlayerListingsEvent", 10)
    if not getListingsEvent then
        warn("GetPlayerListingsEvent not found in ReplicatedStorage")
        return {}
    end
    
    local success, result = pcall(function()
        return getListingsEvent:InvokeServer(userId)
    end)
    
    if not success then
        warn("Failed to get listings from server:", result)
        return {}
    end
    
    print("DEBUG: Client received", #result, "listings from server")
    return result or {}
end

-- Function to create the inspector GUI
local function createInspectorGui(targetPlayer, listings)
    -- Destroy existing GUI if it exists
    if inspectorGui then
        inspectorGui:Destroy()
    end
    
    -- Create main ScreenGui
    inspectorGui = Instance.new("ScreenGui")
    inspectorGui.Name = "VIPPlayerInspector"
    inspectorGui.Parent = playerGui
    inspectorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Create background frame (smaller, matching ListingsGUI style)
    local backgroundFrame = Instance.new("Frame")
    backgroundFrame.Name = "Background"
    backgroundFrame.Size = UDim2.new(0, 350, 0, 400)
    backgroundFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
    backgroundFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    backgroundFrame.BorderSizePixel = 0
    backgroundFrame.Parent = inspectorGui
    
    -- Add rounded corners (matching ListingsGUI)
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 12)
    uiCorner.Parent = backgroundFrame
    
    -- Add shadow effect (matching ListingsGUI)
    local shadowFrame = Instance.new("ImageLabel")
    shadowFrame.Name = "Shadow"
    shadowFrame.Size = UDim2.new(1, 30, 1, 30)
    shadowFrame.Position = UDim2.new(0, -15, 0, -15)
    shadowFrame.BackgroundTransparency = 1
    shadowFrame.Image = "rbxassetid://6014261993"
    shadowFrame.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadowFrame.ImageTransparency = 0.5
    shadowFrame.ScaleType = Enum.ScaleType.Slice
    shadowFrame.SliceCenter = Rect.new(49, 49, 450, 450)
    shadowFrame.ZIndex = -1
    shadowFrame.Parent = backgroundFrame
    
    -- Create header (matching ListingsGUI style)
    local headerFrame = Instance.new("Frame")
    headerFrame.Name = "Header"
    headerFrame.Size = UDim2.new(1, 0, 0, 50)
    headerFrame.Position = UDim2.new(0, 0, 0, 0)
    headerFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    headerFrame.BorderSizePixel = 0
    headerFrame.Parent = backgroundFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = headerFrame
    
    -- Fix header corners (only top corners rounded)
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 15)
    headerFix.Position = UDim2.new(0, 0, 1, -15)
    headerFix.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    headerFix.BorderSizePixel = 0
    headerFix.ZIndex = headerFrame.ZIndex
    headerFix.Parent = headerFrame
    
    -- Header title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -60, 1, 0)
    titleLabel.Position = UDim2.new(0, 20, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = targetPlayer.Name .. "'s Active Listings (" .. #listings .. ")"
    titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = headerFrame
    
    -- Close button (matching ListingsGUI style)
    local closeButton = Instance.new("ImageButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0.5, -15)
    closeButton.BackgroundTransparency = 1
    closeButton.Image = "rbxassetid://7743878857"
    closeButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Parent = headerFrame
    
    -- Create scrolling frame for listings
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ListingsScroll"
    scrollFrame.Size = UDim2.new(1, -20, 1, -70)
    scrollFrame.Position = UDim2.new(0, 10, 0, 60)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80)
    scrollFrame.Parent = backgroundFrame
    
    -- Add UIListLayout to scrolling frame
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = scrollFrame
    
    -- Function to create listing item
    local function createListingItem(listing, index)
        local itemFrame = Instance.new("Frame")
        itemFrame.Name = "ListingItem" .. index
        itemFrame.Size = UDim2.new(1, -10, 0, 120)
        itemFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        itemFrame.BorderSizePixel = 0
        itemFrame.LayoutOrder = index
        itemFrame.Parent = scrollFrame
        
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 8)
        itemCorner.Parent = itemFrame
        
        -- NPC Preview (like in ListingsGUI)
        local previewFrame = Instance.new("ViewportFrame")
        previewFrame.Name = "PreviewFrame"
        previewFrame.Size = UDim2.new(0, 80, 0, 100)
        previewFrame.Position = UDim2.new(0, 10, 0, 10)
        previewFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        previewFrame.BackgroundTransparency = 0.3
        previewFrame.BorderSizePixel = 0
        previewFrame.Parent = itemFrame
        
        local thumbCorner = Instance.new("UICorner")
        thumbCorner.CornerRadius = UDim.new(0, 8)
        thumbCorner.Parent = previewFrame
        
        -- Setup NPC preview
        local camera = Instance.new("Camera")
        camera.FieldOfView = 70
        previewFrame.CurrentCamera = camera
        camera.Parent = previewFrame
        
        -- Create NPC model
        local npcModel = Instance.new("Model")
        npcModel.Name = "PreviewNPC"
        
        local humanoid = Instance.new("Humanoid")
        humanoid.Parent = npcModel
        
        -- Create basic body parts
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
        
        -- Title
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "ItemTitle"
        titleLabel.Size = UDim2.new(1, -180, 0, 50)
        titleLabel.Position = UDim2.new(0, 100, 0, 20)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = listing.title
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextSize = 16
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        titleLabel.TextWrapped = true
        titleLabel.Parent = itemFrame
        
        -- Try On button
        local tryOnButton = Instance.new("TextButton")
        tryOnButton.Name = "TryOnButton"
        tryOnButton.Size = UDim2.new(0, 70, 0, 28)
        tryOnButton.Position = UDim2.new(0, 100, 1, -35)
        tryOnButton.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
        tryOnButton.BorderSizePixel = 0
        tryOnButton.Text = "Try On"
        tryOnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        tryOnButton.TextSize = 11
        tryOnButton.Font = Enum.Font.GothamBold
        tryOnButton.Parent = itemFrame
        
        local tryOnCorner = Instance.new("UICorner")
        tryOnCorner.CornerRadius = UDim.new(0, 6)
        tryOnCorner.Parent = tryOnButton
        
        -- Buy Now button (always show)
        local buyButton = Instance.new("TextButton")
        buyButton.Name = "BuyButton"
        buyButton.Size = UDim2.new(0, 70, 0, 28)
        buyButton.Position = UDim2.new(0, 180, 1, -35)
        buyButton.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
        buyButton.BorderSizePixel = 0
        buyButton.Text = "Buy Now"
        buyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        buyButton.TextSize = 11
        buyButton.Font = Enum.Font.GothamBold
        buyButton.Parent = itemFrame
        
        local buyCorner = Instance.new("UICorner")
        buyCorner.CornerRadius = UDim.new(0, 6)
        buyCorner.Parent = buyButton
        
        -- Buy button functionality
        buyButton.MouseButton1Click:Connect(function()
            -- Prompt purchase for the asset
            local MarketplaceService = game:GetService("MarketplaceService")
            local success, result = pcall(function()
                MarketplaceService:PromptPurchase(player, listing.assetId)
            end)
            
            if not success then
                local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
                if notificationEvent then
                    notificationEvent:FireServer("Failed to open purchase prompt: " .. tostring(result), Color3.fromRGB(255, 100, 100))
                end
            end
        end)
        
        -- Try On button functionality
        tryOnButton.MouseButton1Click:Connect(function()
            -- Get asset info to determine type
            local success, assetInfo = pcall(function()
                return game:GetService("MarketplaceService"):GetProductInfo(listing.assetId)
            end)
            
            if success and assetInfo then
                local character = player.Character
                if character then
                    if assetInfo.AssetTypeId == 11 then -- Shirt
                        spawn(function()
                            local success, template = pcall(function()
                                return getClothingTemplateFunc:InvokeServer(listing.assetId, "Shirt")
                            end)
                            
                        local shirt = character:FindFirstChild("Shirt")
                        if not shirt then
                            shirt = Instance.new("Shirt")
                            shirt.Parent = character
                        end
                            
                            if success and template then
                                shirt.ShirtTemplate = template
                            else
                        shirt.ShirtTemplate = "rbxassetid://" .. listing.assetId
                            end
                        end)
                    elseif assetInfo.AssetTypeId == 12 then -- Pants
                        spawn(function()
                            local success, template = pcall(function()
                                return getClothingTemplateFunc:InvokeServer(listing.assetId, "Pants")
                            end)
                            
                        local pants = character:FindFirstChild("Pants")
                        if not pants then
                            pants = Instance.new("Pants")
                            pants.Parent = character
                        end
                            
                            if success and template then
                                pants.PantsTemplate = template
                            else
                        pants.PantsTemplate = "rbxassetid://" .. listing.assetId
                            end
                        end)
                    end
                    
                    local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
                    if notificationEvent then
                        notificationEvent:FireServer("Trying on: " .. listing.title, Color3.fromRGB(100, 150, 255))
                    end
                    
                    -- Update daily objectives for clothing try-on
                    local objectivesFolder = ReplicatedStorage:FindFirstChild("DailyObjectives")
                    if objectivesFolder then
                        local clothingTryOnEvent = objectivesFolder:FindFirstChild("ClothingTryOnEvent")
                        if clothingTryOnEvent then
                            clothingTryOnEvent:FireServer()
                        end
                    end
                    
                    -- Close the GUI after trying on
                    if inspectorGui then
                        inspectorGui:Destroy()
                        inspectorGui = nil
                        currentInspectedPlayer = nil
                    end
                end
            end
        end)
    end
    
    -- Create listing items
    for i, listing in ipairs(listings) do
        createListingItem(listing, i)
    end
    
    -- Update scroll canvas size
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    
    -- Close button functionality
    closeButton.MouseButton1Click:Connect(function()
        if inspectorGui then
            inspectorGui:Destroy()
            inspectorGui = nil
            currentInspectedPlayer = nil
        end
    end)
    
    -- Animate GUI appearance
    backgroundFrame.Size = UDim2.new(0, 0, 0, 0)
    backgroundFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    local openTween = TweenService:Create(
        backgroundFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {
            Size = UDim2.new(0, 350, 0, 400),
            Position = UDim2.new(0.5, -175, 0.5, -200)
        }
    )
    openTween:Play()
end

-- Function to handle player clicking
local function onPlayerClick(targetPlayer)
    -- Check if local player has VIP
    if not hasVIPGamepass() then
        local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
        if notificationEvent then
            notificationEvent:FireServer("VIP required to inspect players!", Color3.fromRGB(255, 100, 100))
        end
        return
    end
    
    -- Don't open if already inspecting the same player
    if currentInspectedPlayer == targetPlayer then
        return
    end
    
    currentInspectedPlayer = targetPlayer
    
    -- Show loading notification
    local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
    if notificationEvent then
        notificationEvent:FireServer("Loading " .. targetPlayer.Name .. "'s listings...", Color3.fromRGB(255, 215, 0))
    end
    
    -- Get player's listings
    local listings = getPlayerListings(targetPlayer.UserId)
    
    -- Create and show GUI
    createInspectorGui(targetPlayer, listings)
end

-- Set up click detection
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Check for V key to open own listings
    if input.KeyCode == Enum.KeyCode.V then
        print("DEBUG: V key pressed - opening own listings")
        onPlayerClick(player)
        return
    end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mouse = player:GetMouse()
        local target = mouse.Target
        
        print("DEBUG: Mouse clicked on:", target and target:GetFullName() or "nil")
        
        if target then
            -- Try to find the character by going up the hierarchy
            local current = target
            local attempts = 0
            
            -- Search up the hierarchy to find a character
            while current and attempts < 10 do
                print("DEBUG: Checking object:", current:GetFullName())
                
                -- Check if this object IS a character
                local humanoid = current:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local targetPlayer = Players:GetPlayerFromCharacter(current)
                    if targetPlayer then
                        print("DEBUG: Found player:", targetPlayer.Name)
                        onPlayerClick(targetPlayer)
                        return
                    end
                end
                
                -- Check if this object's parent is a character
                if current.Parent then
                    local parentHumanoid = current.Parent:FindFirstChildOfClass("Humanoid")
                    if parentHumanoid then
                        local targetPlayer = Players:GetPlayerFromCharacter(current.Parent)
                        if targetPlayer then
                            print("DEBUG: Found player via parent:", targetPlayer.Name)
                            onPlayerClick(targetPlayer)
                            return
                        end
                    end
                end
                
                current = current.Parent
                attempts = attempts + 1
            end
            
            print("DEBUG: No player character found in hierarchy after", attempts, "attempts")
        end
    end
end)



print("VIP Player Inspector initialized") 