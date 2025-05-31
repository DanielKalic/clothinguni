-- Crate Opening Animation (Simple Version)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("CrateOpeningAnimation: Script starting")

-- Get the crate opening event
local crateOpeningEvent = ReplicatedStorage:WaitForChild("CrateOpeningEvent", 10)

if not crateOpeningEvent then
    warn("CrateOpeningAnimation: CrateOpeningEvent not found, exiting script")
    return
end

-- Create the crate opening GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CrateOpeningAnimation"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Create the background overlay
local backgroundOverlay = Instance.new("Frame")
backgroundOverlay.Name = "BackgroundOverlay"
backgroundOverlay.Size = UDim2.new(1, 0, 1, 0)
backgroundOverlay.Position = UDim2.new(0, 0, 0, 0)
backgroundOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backgroundOverlay.BackgroundTransparency = 0.7
backgroundOverlay.BorderSizePixel = 0
backgroundOverlay.Parent = screenGui

-- Create the main animation container
local mainContainer = Instance.new("Frame")
mainContainer.Name = "MainContainer"
mainContainer.Size = UDim2.new(0, 500, 0, 350)
mainContainer.Position = UDim2.new(0.5, -250, 0.5, -175)
mainContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainContainer.BorderSizePixel = 0
mainContainer.Parent = screenGui

-- Add rounded corners
local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 12)
containerCorner.Parent = mainContainer

-- Create the crate type label
local crateTypeLabel = Instance.new("TextLabel")
crateTypeLabel.Name = "CrateTypeLabel"
crateTypeLabel.Size = UDim2.new(1, 0, 0, 50)
crateTypeLabel.Position = UDim2.new(0, 0, 0, 10)
crateTypeLabel.BackgroundTransparency = 1
crateTypeLabel.Text = "Opening Crate..."
crateTypeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
crateTypeLabel.TextSize = 28
crateTypeLabel.Font = Enum.Font.GothamBold
crateTypeLabel.Parent = mainContainer

-- Create the spinning reel container (clip frame)
local reelClipFrame = Instance.new("Frame")
reelClipFrame.Name = "ReelClipFrame"
reelClipFrame.Size = UDim2.new(0, 440, 0, 180)
reelClipFrame.Position = UDim2.new(0.5, -220, 0, 70)
reelClipFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
reelClipFrame.BorderSizePixel = 0
reelClipFrame.ClipsDescendants = true
reelClipFrame.Parent = mainContainer

-- Add rounded corners to reel clip frame
local reelCorner = Instance.new("UICorner")
reelCorner.CornerRadius = UDim.new(0, 8)
reelCorner.Parent = reelClipFrame

-- Create the reel that will spin
local reel = Instance.new("Frame")
reel.Name = "Reel"
reel.Size = UDim2.new(0, 6000, 1, 0) -- Long reel for many items
reel.Position = UDim2.new(0, 0, 0, 0)
reel.BackgroundTransparency = 1
reel.Parent = reelClipFrame

-- Add highlight frame for selected item
local highlightFrame = Instance.new("Frame")
highlightFrame.Name = "HighlightFrame"
highlightFrame.Size = UDim2.new(0, 150, 0, 150)
highlightFrame.Position = UDim2.new(0.5, -75, 0.5, -75)
highlightFrame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
highlightFrame.BackgroundTransparency = 0.5
highlightFrame.BorderSizePixel = 0
highlightFrame.ZIndex = 1
highlightFrame.Parent = reelClipFrame

-- Add rounded corners to highlight frame
local highlightCorner = Instance.new("UICorner")
highlightCorner.CornerRadius = UDim.new(0, 8)
highlightCorner.Parent = highlightFrame

-- Create cinematic reveal container (full screen)
local cinematicContainer = Instance.new("Frame")
cinematicContainer.Name = "CinematicContainer"
cinematicContainer.Size = UDim2.new(1, 0, 1, 0)
cinematicContainer.Position = UDim2.new(0, 0, 0, 0)
cinematicContainer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
cinematicContainer.BackgroundTransparency = 0.8
cinematicContainer.BorderSizePixel = 0
cinematicContainer.Visible = false
cinematicContainer.ZIndex = 10
cinematicContainer.Parent = screenGui

-- Add "You received:" text at the top
local resultText = Instance.new("TextLabel")
resultText.Name = "ResultText"
resultText.Size = UDim2.new(1, 0, 0, 50)
resultText.Position = UDim2.new(0, 0, 0, 50) -- Higher up
resultText.BackgroundTransparency = 1
resultText.Text = "You received:"
resultText.TextColor3 = Color3.fromRGB(255, 255, 255)
resultText.TextSize = 32
resultText.Font = Enum.Font.GothamBold
resultText.TextXAlignment = Enum.TextXAlignment.Center
resultText.Parent = cinematicContainer

-- Add rarity text under "You received:"
local rarityText = Instance.new("TextLabel")
rarityText.Name = "RarityText"
rarityText.Size = UDim2.new(1, 0, 0, 40)
rarityText.Position = UDim2.new(0, 0, 0, 100) -- Under "You received:"
rarityText.BackgroundTransparency = 1
rarityText.Text = ""
rarityText.TextSize = 28
rarityText.Font = Enum.Font.GothamSemibold
rarityText.TextXAlignment = Enum.TextXAlignment.Center
rarityText.Parent = cinematicContainer

-- Add large 3D pet preview in center (with gap from rarity text)
local largePetPreview = Instance.new("ViewportFrame")
largePetPreview.Name = "LargePetPreview"
largePetPreview.Size = UDim2.new(0, 280, 0, 280)
largePetPreview.Position = UDim2.new(0.5, -140, 0, 170) -- Below rarity text with gap
largePetPreview.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
largePetPreview.BackgroundTransparency = 0.3
largePetPreview.BorderSizePixel = 0
largePetPreview.Parent = cinematicContainer

-- Add rounded corners to large preview
local largePreviewCorner = Instance.new("UICorner")
largePreviewCorner.CornerRadius = UDim.new(0, 20)
largePreviewCorner.Parent = largePetPreview

-- Add pet name text below the preview (with gap)
local petNameText = Instance.new("TextLabel")
petNameText.Name = "PetNameText"
petNameText.Size = UDim2.new(1, 0, 0, 50)
petNameText.Position = UDim2.new(0, 0, 0, 470) -- Below preview with gap
petNameText.BackgroundTransparency = 1
petNameText.Text = ""
petNameText.TextColor3 = Color3.fromRGB(255, 215, 0)
petNameText.TextSize = 36
petNameText.Font = Enum.Font.GothamBold
petNameText.TextXAlignment = Enum.TextXAlignment.Center
petNameText.Parent = cinematicContainer

-- Add continue button below pet name
local continueButton = Instance.new("TextButton")
continueButton.Name = "ContinueButton"
continueButton.Size = UDim2.new(0, 250, 0, 60)
continueButton.Position = UDim2.new(0.5, -125, 0, 540) -- Below pet name
continueButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
continueButton.BorderSizePixel = 0
continueButton.Text = "CONTINUE"
continueButton.TextColor3 = Color3.fromRGB(255, 255, 255)
continueButton.TextSize = 24
continueButton.Font = Enum.Font.GothamBold
continueButton.Visible = false
continueButton.Parent = cinematicContainer

-- Add rounded corners to button
local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = continueButton

-- Add sound effects
local spinSound = Instance.new("Sound")
spinSound.Name = "SpinSound" 
spinSound.SoundId = "rbxassetid://9120223723" -- Updated slot machine spin sound
spinSound.Volume = 0.5
spinSound.Parent = screenGui

local winSound = Instance.new("Sound")
winSound.Name = "WinSound"
winSound.SoundId = "rbxassetid://131323304" -- Winning sound
winSound.Volume = 0.7
winSound.Parent = screenGui

-- Define constants
local CARD_WIDTH = 150

-- Function to setup the large pet preview in cinematic mode
local function setupLargePetPreview(petName, rarity)
    -- Clear any existing content
    for _, child in pairs(largePetPreview:GetChildren()) do
        if child.Name ~= "UICorner" then
            child:Destroy()
        end
    end
    
    -- Setup camera for large preview
    local camera = Instance.new("Camera")
    camera.FieldOfView = 50
    largePetPreview.CurrentCamera = camera
    camera.Parent = largePetPreview
    
    -- Try to get the pet model from ReplicatedStorage
    local success, petModel = pcall(function()
        local petsFolder = ReplicatedStorage:FindFirstChild("Pets")
        if petsFolder then
            local rarityFolder = petsFolder:FindFirstChild(rarity)
            if rarityFolder then
                return rarityFolder:FindFirstChild(petName)
            end
        end
        return nil
    end)
    
    -- If we found the pet model, clone it for display
    if success and petModel then
        local displayModel = petModel:Clone()
        displayModel.Parent = largePetPreview
        
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
            local distance = modelSize * 2 -- Closer for large preview
            camera.CFrame = CFrame.new(modelCenter + Vector3.new(0, 0, -distance), modelCenter)
            
            -- Add rotation animation (faster for dramatic effect)
            local rotation = 0
            local runService = game:GetService("RunService")
			local rotationConnection
			rotationConnection = runService.RenderStepped:Connect(function(deltaTime)
				-- Prüfen, ob alle Objekte noch existieren
				if largePetPreview and largePetPreview.Parent
					and targetPart and targetPart.Parent
					and modelCenter
				then
					rotation = rotation + deltaTime * 1.2 -- Faster rotation
					targetPart.CFrame = CFrame.new(modelCenter) * CFrame.Angles(0, rotation, 0)
				else
					if rotationConnection then
						rotationConnection:Disconnect()
						rotationConnection = nil
					end
				end
			end)
            
            -- Store connection for cleanup
            largePetPreview:SetAttribute("RotationConnection", true)
            largePetPreview.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    rotationConnection:Disconnect()
                end
            end)
        end
    else
        -- If model not found, show large placeholder
        local placeholder = Instance.new("TextLabel")
        placeholder.Name = "Placeholder"
        placeholder.Size = UDim2.new(1, 0, 1, 0)
        placeholder.BackgroundTransparency = 1
        placeholder.Text = "?"
        placeholder.TextSize = 120
        placeholder.Font = Enum.Font.GothamBold
        placeholder.Parent = largePetPreview
        
        -- Set placeholder color based on rarity
        if rarity == "Common" then
            placeholder.TextColor3 = Color3.fromRGB(150, 150, 150)
        elseif rarity == "Rare" then
            placeholder.TextColor3 = Color3.fromRGB(30, 100, 200)
        elseif rarity == "Legendary" then
            placeholder.TextColor3 = Color3.fromRGB(170, 130, 20)
        elseif rarity == "VIP" then
            placeholder.TextColor3 = Color3.fromRGB(170, 30, 170)
        end
    end
end

-- Function to create a pet card for the reel
local function createPetCard(petName, rarity, position)
    local petCard = Instance.new("Frame")
    petCard.Name = petName .. "Card"
    petCard.Size = UDim2.new(0, 140, 0, 140)
    petCard.Position = position
    petCard.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    petCard.BorderSizePixel = 0
    
    -- Add rounded corners
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = petCard
    
    -- Add rarity border at the top
    local rarityBorder = Instance.new("Frame")
    rarityBorder.Name = "RarityBorder"
    rarityBorder.Size = UDim2.new(1, 0, 0, 3)
    rarityBorder.Position = UDim2.new(0, 0, 0, 0)
    rarityBorder.BorderSizePixel = 0
    
    -- Set border color based on rarity
    if rarity == "Common" then
        rarityBorder.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    elseif rarity == "Rare" then
        rarityBorder.BackgroundColor3 = Color3.fromRGB(30, 100, 200)
    elseif rarity == "Legendary" then
        rarityBorder.BackgroundColor3 = Color3.fromRGB(170, 130, 20)
    elseif rarity == "VIP" then
        rarityBorder.BackgroundColor3 = Color3.fromRGB(170, 30, 170)
    end
    
    rarityBorder.Parent = petCard
    
    -- Add rounded corners to border
    local borderCorner = Instance.new("UICorner")
    borderCorner.CornerRadius = UDim.new(0, 8)
    borderCorner.Parent = rarityBorder
    
    -- Add 3D pet preview
    local previewFrame = Instance.new("ViewportFrame")
    previewFrame.Name = "PreviewFrame"
    previewFrame.Size = UDim2.new(0, 80, 0, 80)
    previewFrame.Position = UDim2.new(0.5, -40, 0, 15)
    previewFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    previewFrame.BackgroundTransparency = 0.3
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
            local rarityFolder = petsFolder:FindFirstChild(rarity)
            if rarityFolder then
                return rarityFolder:FindFirstChild(petName)
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
			local runService = game:GetService("RunService")
			local rotationConnection
			rotationConnection = runService.RenderStepped:Connect(function(deltaTime)
				-- Prüfen, ob alle Objekte noch existieren
				if largePetPreview and largePetPreview.Parent
					and targetPart and targetPart.Parent
					and modelCenter
				then
					rotation = rotation + deltaTime * 1.2 -- Faster rotation
					targetPart.CFrame = CFrame.new(modelCenter) * CFrame.Angles(0, rotation, 0)
				else
					if rotationConnection then
						rotationConnection:Disconnect()
						rotationConnection = nil
					end
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
    else
        -- If model not found, show placeholder
        local placeholder = Instance.new("TextLabel")
        placeholder.Name = "Placeholder"
        placeholder.Size = UDim2.new(1, 0, 1, 0)
        placeholder.BackgroundTransparency = 1
        placeholder.Text = "?"
        placeholder.TextSize = 40
        placeholder.Font = Enum.Font.GothamBold
        placeholder.Parent = previewFrame
        
        -- Set placeholder color based on rarity
        if rarity == "Common" then
            placeholder.TextColor3 = Color3.fromRGB(150, 150, 150)
        elseif rarity == "Rare" then
            placeholder.TextColor3 = Color3.fromRGB(30, 100, 200)
        elseif rarity == "Legendary" then
            placeholder.TextColor3 = Color3.fromRGB(170, 130, 20)
        elseif rarity == "VIP" then
            placeholder.TextColor3 = Color3.fromRGB(170, 30, 170)
        end
    end
    
    -- Add pet name label (moved down to make room for preview)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -10, 0, 25)
    nameLabel.Position = UDim2.new(0, 5, 0, 100)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = petName
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextWrapped = true
    nameLabel.Parent = petCard
    
    -- Add rarity label with color coding (moved down)
    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Name = "RarityLabel"
    rarityLabel.Size = UDim2.new(1, -10, 0, 15)
    rarityLabel.Position = UDim2.new(0, 5, 1, -20)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = rarity
    
    -- Set color based on rarity
    if rarity == "Common" then
        rarityLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    elseif rarity == "Rare" then
        rarityLabel.TextColor3 = Color3.fromRGB(0, 112, 221)
    elseif rarity == "Legendary" then
        rarityLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    elseif rarity == "VIP" then
        rarityLabel.TextColor3 = Color3.fromRGB(170, 0, 170)
    end
    
    rarityLabel.TextSize = 12
    rarityLabel.Font = Enum.Font.GothamSemibold
    rarityLabel.Parent = petCard
    
    return petCard
end

-- Populate the reel with a mix of pets from all rarities
local function populateReel(winningPetName, winningRarity)
    print("Populating reel with winner: " .. winningPetName .. " (" .. winningRarity .. ")")
    
    -- Clear any existing children
    for _, child in pairs(reel:GetChildren()) do
        child:Destroy()
    end
    
    -- Sample pet data for the reel
    local petOptions = {
        {name = "BassBear", rarity = "Common"},
        {name = "Boxer", rarity = "Common"},
        {name = "Gnome", rarity = "Common"},
        {name = "Heart", rarity = "Common"},
        {name = "Mia", rarity = "Common"},
        {name = "WhiteCat", rarity = "Common"},
        {name = "Fox", rarity = "Rare"},
        {name = "Pirate", rarity = "Rare"},
        {name = "Sly", rarity = "Rare"},
        {name = "Zebra", rarity = "Rare"},
        {name = "ConfusedAstronaut", rarity = "Legendary"},
        {name = "FBIAgent", rarity = "Legendary"},
        {name = "Murray", rarity = "Legendary"},
        {name = "Sticky", rarity = "Legendary"},
        {name = "Cthulhu", rarity = "VIP"},
        {name = "DarthVader", rarity = "VIP"},
        {name = "ElephantShrew", rarity = "VIP"},
        {name = "Penguin", rarity = "VIP"}
    }
    
    -- For simplicity, place cards every CARD_WIDTH pixels
    local totalCards = 30
    
    -- We'll place the winning card at a specific position
    local winningCardIndex = 20 -- Fixed position
    
    for i = 1, totalCards do
        local petData
        
        if i == winningCardIndex then
            -- This is the winning card
            petData = {name = winningPetName, rarity = winningRarity}
        else
            -- Random pet card
            petData = petOptions[math.random(1, #petOptions)]
        end
        
        -- Create a card exactly CARD_WIDTH apart from others
        local card = createPetCard(petData.name, petData.rarity, UDim2.new(0, (i-1) * CARD_WIDTH, 0, 20))
        card.Parent = reel
    end
    
    -- Return the position we need to slide to
    return (winningCardIndex - 1) * CARD_WIDTH
end

-- Function to start the crate opening animation
local function startCrateOpening(crateType, petInfo)
    print("CrateOpeningAnimation: Starting animation for " .. crateType .. " crate")
    print("CrateOpeningAnimation: Pet received - " .. petInfo.name .. " (" .. petInfo.rarity .. ")")
	
	
    -- Show the GUI
    screenGui.Enabled = true
	mainContainer.Visible = true
    -- Set crate type text
    crateTypeLabel.Text = "Opening " .. crateType .. " Crate"
    
    -- Determine color for crate type
    if crateType == "Common" then
        crateTypeLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    elseif crateType == "Rare" then
        crateTypeLabel.TextColor3 = Color3.fromRGB(0, 112, 221)
    elseif crateType == "Legendary" then
        crateTypeLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    elseif crateType == "VIP" then
        crateTypeLabel.TextColor3 = Color3.fromRGB(170, 0, 170)
    end
    
    -- Hide cinematic container and continue button initially
    cinematicContainer.Visible = false
    continueButton.Visible = false
    
    -- Populate the reel and get the position we need to slide to
    local targetPos = populateReel(petInfo.name, petInfo.rarity)
    
    -- Reset reel position - start with the reel showing the beginning
    reel.Position = UDim2.new(0, 0, 0, 0)
    
    -- Play spin sound
    spinSound:Play()
    
    -- Start animation
    local finalPos = -targetPos + (reelClipFrame.AbsoluteSize.X / 2 - CARD_WIDTH/2) -- Center the winning card
    
    -- Simple, one-stage animation with proper deceleration
    local spinningTween = TweenService:Create(
        reel,
        TweenInfo.new(
            4, -- Duration
            Enum.EasingStyle.Quint, -- Gradual deceleration
            Enum.EasingDirection.Out -- Slow down towards end
        ),
        {Position = UDim2.new(0, finalPos, 0, 0)}
    )
    
    spinningTween:Play()
    
    -- Play win sound near the end
    task.delay(3.5, function()
        spinSound:Stop()
        winSound:Play()
    end)
    
    -- When animation completes
    spinningTween.Completed:Connect(function()
        -- Wait a moment, then transition to cinematic reveal
        task.delay(1, function()
            -- Hide the main container and show cinematic container
            mainContainer.Visible = false
            cinematicContainer.Visible = true
            
            -- Set up the large pet preview
            setupLargePetPreview(petInfo.name, petInfo.rarity)
            
            -- Set pet name and rarity text
            petNameText.Text = petInfo.name
            rarityText.Text = petInfo.rarity
            
            -- Set colors based on rarity
            if petInfo.rarity == "Common" then
                petNameText.TextColor3 = Color3.fromRGB(180, 180, 180)
                rarityText.TextColor3 = Color3.fromRGB(180, 180, 180)
            elseif petInfo.rarity == "Rare" then
                petNameText.TextColor3 = Color3.fromRGB(0, 112, 221)
                rarityText.TextColor3 = Color3.fromRGB(0, 112, 221)
            elseif petInfo.rarity == "Legendary" then
                petNameText.TextColor3 = Color3.fromRGB(255, 215, 0)
                rarityText.TextColor3 = Color3.fromRGB(255, 215, 0)
            elseif petInfo.rarity == "VIP" then
                petNameText.TextColor3 = Color3.fromRGB(170, 0, 170)
                rarityText.TextColor3 = Color3.fromRGB(170, 0, 170)
            end
            
            -- Show continue button with delay
            task.delay(1.5, function()
                continueButton.Visible = true
                
                -- Add button hover effects
                continueButton.MouseEnter:Connect(function()
                    TweenService:Create(continueButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(0, 140, 235)}):Play()
                end)
                
                continueButton.MouseLeave:Connect(function()
                    TweenService:Create(continueButton, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(0, 120, 215)}):Play()
                end)
            end)
        end)
    end)
end

-- Connect continue button
continueButton.MouseButton1Click:Connect(function()
    -- Hide the crate opening animation
    screenGui.Enabled = false
    
    -- No longer need to mess with toggle buttons - they should stay visible always
    -- since we removed the hiding logic from ListingsGUI showGUI function
    print("CrateOpeningAnimation: Continue clicked")
end)

-- Connect to crate opening event with error handling
print("CrateOpeningAnimation: Connecting to event...")
local connection
connection = crateOpeningEvent.OnClientEvent:Connect(function(crateType, petInfo)
    local success, err = pcall(function()
        print("CrateOpeningAnimation: Event received!")
        
        -- Debug info
        print("CrateOpeningAnimation: Crate Type: " .. tostring(crateType))
        if petInfo then
            print("CrateOpeningAnimation: Pet Info: " .. HttpService:JSONEncode(petInfo))
        else
            print("CrateOpeningAnimation: Pet Info is nil!")
        end
        
        if not crateType then
            warn("CrateOpeningAnimation: Missing crate type!")
            return
        end
        
        if not petInfo or not petInfo.name or not petInfo.rarity then
            warn("CrateOpeningAnimation: Incomplete pet info!")
            return
        end
        
        -- Start the animation
        startCrateOpening(crateType, petInfo)
    end)
    
    if not success then
        warn("CrateOpeningAnimation: Error in event handler: " .. tostring(err))
    end
end)

if connection then
    print("CrateOpeningAnimation: Successfully connected to event")
else
    warn("CrateOpeningAnimation: Failed to connect to event!")
end