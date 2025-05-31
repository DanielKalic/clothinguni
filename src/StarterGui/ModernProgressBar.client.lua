-- Modern Progress Bar
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load the GUIManager module if available
local GUIManager
if ReplicatedStorage:FindFirstChild("GUIManager") then
    GUIManager = require(ReplicatedStorage:WaitForChild("GUIManager"))
end

-- Remove any existing modern progress bar
local existingGui = playerGui:FindFirstChild("ModernProgressBar")
if existingGui and existingGui:IsA("ScreenGui") then
    existingGui:Destroy()
end

-- Wait for leaderstats
local leaderstats = player:WaitForChild("leaderstats")
local xp = leaderstats:WaitForChild("XP")
local level = leaderstats:WaitForChild("Level")
local coins = leaderstats:FindFirstChild("Coins") -- Using FindFirstChild since it might not exist yet

-- Flag to determine if this is the initial load and if XP notifications should be shown
local isInitialLoad = true
local initialLoadTime = tick()
local INITIAL_LOAD_GRACE_PERIOD = 2  -- Reduced from 5 to 2 seconds to ensure daily bonus updates are visible

-- Store the initial XP value when the UI first loads
local initialXPValue = xp.Value

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModernProgressBar"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Create progress bar container
local progressContainer = Instance.new("Frame")
progressContainer.Name = "ProgressContainer"
progressContainer.Size = UDim2.new(0, 250, 0, 40) -- Smaller than the original
progressContainer.Position = UDim2.new(1, -260, 0, 10) -- Positioned at the top right corner
progressContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
progressContainer.BorderSizePixel = 0
progressContainer.Parent = screenGui

-- Add rounded corners
local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 8)
cornerRadius.Parent = progressContainer

-- Add shadow effect
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0, -10, 0, -10)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://6014261993"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.5
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(49, 49, 450, 450)
shadow.ZIndex = progressContainer.ZIndex - 1
shadow.Parent = progressContainer

-- Create the progress bar background
local progressBackground = Instance.new("Frame")
progressBackground.Name = "Background"
progressBackground.Size = UDim2.new(1, -16, 0, 12)
progressBackground.Position = UDim2.new(0, 8, 0.5, -4)
progressBackground.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
progressBackground.BorderSizePixel = 0
progressBackground.Parent = progressContainer

-- Add rounded corners to background
local backgroundCorner = Instance.new("UICorner")
backgroundCorner.CornerRadius = UDim.new(0, 6)
backgroundCorner.Parent = progressBackground

-- Create progress bar fill
local progressFill = Instance.new("Frame")
progressFill.Name = "Fill"
progressFill.Size = UDim2.new(0, 0, 1, 0) -- Will be updated dynamically
progressFill.BackgroundColor3 = Color3.fromRGB(30, 120, 255) -- Blue color
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBackground

-- Add rounded corners to fill
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 6)
fillCorner.Parent = progressFill

-- Add gradient to fill for better appearance
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 150, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 100, 200))
})
gradient.Rotation = 90
gradient.Parent = progressFill

-- Create level label
local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.Size = UDim2.new(0, 80, 0, 20)
levelLabel.Position = UDim2.new(0, 10, 0, -25)
levelLabel.BackgroundTransparency = 1
levelLabel.Text = "Level 1"
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
levelLabel.TextSize = 14
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
levelLabel.Parent = progressContainer

-- Create XP display
local xpDisplay = Instance.new("TextLabel")
xpDisplay.Name = "XPDisplay"
xpDisplay.Size = UDim2.new(0, 100, 0, 20)
xpDisplay.Position = UDim2.new(1, -110, 0, -25)
xpDisplay.BackgroundTransparency = 1
xpDisplay.Text = "0/100 XP"
xpDisplay.TextColor3 = Color3.fromRGB(200, 200, 200)
xpDisplay.TextSize = 12
xpDisplay.Font = Enum.Font.GothamSemibold
xpDisplay.TextXAlignment = Enum.TextXAlignment.Right
xpDisplay.Parent = progressContainer

-- Create XP gain animation container
local xpAnimationContainer = Instance.new("Frame")
xpAnimationContainer.Name = "XPAnimationContainer"
xpAnimationContainer.Size = UDim2.new(1, 0, 0, 60)
xpAnimationContainer.Position = UDim2.new(0, 0, 0, -40)
xpAnimationContainer.BackgroundTransparency = 1
xpAnimationContainer.Parent = progressContainer

-- Create coin display container
local coinContainer = Instance.new("Frame")
coinContainer.Name = "CoinContainer"
coinContainer.Size = UDim2.new(0, 100, 0, 25)
coinContainer.Position = UDim2.new(0, 0, 1, 5) -- Position below the progress bar
coinContainer.BackgroundTransparency = 1
coinContainer.Parent = progressContainer

-- Create coin icon
local coinIcon = Instance.new("ImageLabel")
coinIcon.Name = "CoinIcon"
coinIcon.Size = UDim2.new(0, 20, 0, 20)
coinIcon.Position = UDim2.new(0, 8, 0, 2)
coinIcon.BackgroundTransparency = 1
coinIcon.Image = "rbxassetid://85328818138281" -- Updated coin icon
coinIcon.ImageColor3 = Color3.fromRGB(255, 215, 0) -- Gold color
coinIcon.Parent = coinContainer

-- Create coin amount text
local coinAmountText = Instance.new("TextLabel")
coinAmountText.Name = "CoinAmountText"
coinAmountText.Size = UDim2.new(0, 70, 0, 20)
coinAmountText.Position = UDim2.new(0, 32, 0, 2)
coinAmountText.BackgroundTransparency = 1
coinAmountText.Text = "0"
coinAmountText.TextColor3 = Color3.fromRGB(255, 255, 255)
coinAmountText.TextSize = 14
coinAmountText.Font = Enum.Font.GothamBold
coinAmountText.TextXAlignment = Enum.TextXAlignment.Left
coinAmountText.Parent = coinContainer

-- Function to calculate XP required for level
local function xpRequiredForLevel(lvl)
    return lvl * 100
end

-- Function to update coin display
local function updateCoins(coinValue)
    if coinAmountText then
        local formattedCoins = tostring(coinValue or 0)
        
        -- Format with commas for thousands
        if coinValue and coinValue >= 1000 then
            formattedCoins = tostring(math.floor(coinValue/1000)) .. "," .. string.format("%03d", coinValue % 1000)
        end
        
        coinAmountText.Text = formattedCoins
    end
end

-- Function to create particle effect
local function createParticle(parent, position)
    local particle = Instance.new("Frame")
    particle.Size = UDim2.new(0, math.random(3, 6), 0, math.random(3, 6))
    particle.Position = position
    particle.AnchorPoint = Vector2.new(0.5, 0.5)
    particle.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
    particle.BorderSizePixel = 0
    particle.Rotation = math.random(0, 360)
    particle.Parent = parent
    
    -- Add rounded corners
    local particleCorner = Instance.new("UICorner")
    particleCorner.CornerRadius = UDim.new(1, 0)
    particleCorner.Parent = particle
    
    -- Animate the particle
    local startPosition = particle.Position
    local endPosition = UDim2.new(
        startPosition.X.Scale + (math.random(-30, 30) / 100),
        startPosition.X.Offset,
        startPosition.Y.Scale - (math.random(10, 30) / 100),
        startPosition.Y.Offset
    )
    
    local fadeIn = TweenService:Create(
        particle,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.2}
    )
    
    local move = TweenService:Create(
        particle,
        TweenInfo.new(math.random(8, 15) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = endPosition, Rotation = math.random(180, 540)}
    )
    
    local fadeOut = TweenService:Create(
        particle,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency = 1, Size = UDim2.new(0, 1, 0, 1)}
    )
    
    fadeIn:Play()
    move:Play()
    
    delay(math.random(6, 10) / 10, function()
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            particle:Destroy()
        end)
    end)
    
    return particle
end

-- Function to update the progress bar
local function updateProgressBar(instant)
    local requiredXP = xpRequiredForLevel(level.Value)
    local percent = xp.Value / requiredXP
    percent = math.clamp(percent, 0, 1)
    
    if instant then
        progressFill.Size = UDim2.new(percent, 0, 1, 0)
    else
        -- Tween the fill size for smooth animation
        local fillTween = TweenService:Create(
            progressFill, 
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(percent, 0, 1, 0)}
        )
        fillTween:Play()
    end
    
    -- Update text displays
    levelLabel.Text = "Level " .. tostring(level.Value)
    xpDisplay.Text = tostring(xp.Value) .. "/" .. tostring(requiredXP) .. " XP"
end

-- Create a shine effect for the progress bar
local function createShineEffect()
    local shine = Instance.new("Frame")
    shine.Name = "Shine"
    shine.Size = UDim2.new(0, 10, 1, 0)
    shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    shine.BackgroundTransparency = 0.8
    shine.BorderSizePixel = 0
    shine.ZIndex = progressFill.ZIndex + 1
    shine.Parent = progressFill
    
    -- Add gradient
    local shineGradient = Instance.new("UIGradient")
    shineGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    })
    shineGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.4, 0.8),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(0.6, 0.8),
        NumberSequenceKeypoint.new(1, 1)
    })
    shineGradient.Parent = shine
    
    -- Animate the shine
    shine.Position = UDim2.new(-0.5, 0, 0, 0)
    local shineTween = TweenService:Create(
        shine,
        TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
        {Position = UDim2.new(1.5, 0, 0, 0)}
    )
    shineTween:Play()
    
    shineTween.Completed:Connect(function()
        shine:Destroy()
    end)
end

-- Connect events
local previousXP = xp.Value
local previousPercent = 0

-- Calculate initial percent
local function calculatePercent(xpValue)
    local requiredXP = xpRequiredForLevel(level.Value)
    return math.clamp(xpValue / requiredXP, 0, 1)
end

previousPercent = calculatePercent(previousXP)

xp.Changed:Connect(function(newXP)
    local diff = newXP - previousXP
    if diff > 0 and not isInitialLoad then
        -- Skip any XP notifications during the initial grace period after joining
        -- This grace period is short enough to allow daily bonus to be visible
        -- However, always show daily bonus XP (20 points)
        if tick() - initialLoadTime < INITIAL_LOAD_GRACE_PERIOD and diff ~= 20 then
            previousPercent = calculatePercent(newXP)
            previousXP = newXP
            return
        end
        
        -- Create a green segment showing new XP
        local requiredXP = xpRequiredForLevel(level.Value)
        local newPercent = calculatePercent(newXP)
        local oldPercent = calculatePercent(previousXP)
        
        -- Create green progress segment
        local newXPSegment = Instance.new("Frame")
        newXPSegment.Name = "NewXPSegment"
        newXPSegment.Position = UDim2.new(oldPercent, 0, 0, 0)
        newXPSegment.Size = UDim2.new(newPercent - oldPercent, 0, 1, 0)
        newXPSegment.BackgroundColor3 = Color3.fromRGB(80, 255, 120) -- Green color
        newXPSegment.BorderSizePixel = 0
        newXPSegment.ZIndex = progressFill.ZIndex
        newXPSegment.Parent = progressBackground
        
        -- Add rounded corners if it's at the end
        if oldPercent == 0 then
            local leftCorner = Instance.new("UICorner")
            leftCorner.CornerRadius = UDim.new(0, 6)
            leftCorner.Parent = newXPSegment
        end
        
        -- Green to blue gradient for the new XP segment
        local segmentGradient = Instance.new("UIGradient")
        segmentGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 120)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 220, 100))
        })
        segmentGradient.Rotation = 90
        segmentGradient.Parent = newXPSegment
        
        -- Create shine effect
        createShineEffect()
        
        -- Animate the progress bar fill to show new XP
        updateProgressBar(true) -- Update the main fill instantly
        
        -- Animate the new XP segment to match the blue color
        local colorTween = TweenService:Create(
            newXPSegment,
            TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundColor3 = Color3.fromRGB(30, 120, 255)}
        )
        
        colorTween:Play()
        colorTween.Completed:Connect(function()
            newXPSegment:Destroy()
        end)
        
        -- Play shine effect on the progress bar
        createShineEffect()
        
        -- Create animated XP gain text with bounce effect
        local xpGainLabel = Instance.new("TextLabel")
        xpGainLabel.BackgroundTransparency = 1
        xpGainLabel.Text = "+" .. tostring(diff) .. " XP"
        xpGainLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
        xpGainLabel.Font = Enum.Font.GothamBold
        xpGainLabel.TextSize = 20
        xpGainLabel.Size = UDim2.new(0, 120, 0, 30)
        xpGainLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        xpGainLabel.Position = UDim2.new(0.5, 0, 0.5, 0) -- Centered initially
        xpGainLabel.TextTransparency = 1
        xpGainLabel.TextStrokeTransparency = 0.7
        xpGainLabel.TextStrokeColor3 = Color3.fromRGB(0, 80, 0)
        xpGainLabel.Parent = xpAnimationContainer
        
        -- Create glow effect
        local glow = Instance.new("ImageLabel")
        glow.Name = "Glow"
        glow.Size = UDim2.new(1.5, 0, 1.5, 0)
        glow.Position = UDim2.new(0.5, 0, 0.5, 0)
        glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.BackgroundTransparency = 1
        glow.Image = "rbxassetid://6014261993"
        glow.ImageColor3 = Color3.fromRGB(80, 255, 120)
        glow.ImageTransparency = 1
        glow.Parent = xpGainLabel
        
        -- Animation sequence with bounce effect
        -- Initial appear with bounce
        local initialScale = TweenService:Create(
            xpGainLabel,
            TweenInfo.new(0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
            {TextTransparency = 0, Size = UDim2.new(0, 150, 0, 40)}
        )
        
        local glowFadeIn = TweenService:Create(
            glow,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {ImageTransparency = 0.7}
        )
        
        -- Small bounce effect
        local bounceDown = TweenService:Create(
            xpGainLabel,
            TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 140, 0, 35)}
        )
        
        local bounceUp = TweenService:Create(
            xpGainLabel,
            TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 150, 0, 40)}
        )
        
        -- Float up and fade out
        local floatUp = TweenService:Create(
            xpGainLabel,
            TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, 0, 0, -20), TextTransparency = 1, TextStrokeTransparency = 1}
        )
        
        local glowFadeOut = TweenService:Create(
            glow,
            TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {ImageTransparency = 1}
        )
        
        -- Create particles
        for i = 1, math.min(diff, 15) do
            delay(math.random(0, 20) / 100, function()
                createParticle(
                    xpAnimationContainer, 
                    UDim2.new(0.5, math.random(-60, 60), 0.5, math.random(-10, 10))
                )
            end)
        end
        
        -- Play the animation sequence
        initialScale:Play()
        glowFadeIn:Play()
        
        initialScale.Completed:Connect(function()
            bounceDown:Play()
            bounceDown.Completed:Connect(function()
                bounceUp:Play()
                bounceUp.Completed:Connect(function()
                    wait(0.2)
                    floatUp:Play()
                    glowFadeOut:Play()
                    floatUp.Completed:Connect(function()
                        xpGainLabel:Destroy()
                    end)
                end)
            end)
        end)
        
        -- Create a temporary flash effect on the bar
        local flash = Instance.new("Frame")
        flash.Size = UDim2.new(1, 0, 1, 0)
        flash.BackgroundColor3 = Color3.fromRGB(120, 255, 180)
        flash.BorderSizePixel = 0
        flash.ZIndex = progressFill.ZIndex + 2
        flash.BackgroundTransparency = 1
        flash.Parent = progressFill
        
        local flashCorner = Instance.new("UICorner")
        flashCorner.CornerRadius = UDim.new(0, 6)
        flashCorner.Parent = flash
        
        -- Flash animation
        local flashIn = TweenService:Create(
            flash,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.6}
        )
        
        local flashOut = TweenService:Create(
            flash,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 1}
        )
        
        flashIn:Play()
        flashIn.Completed:Connect(function()
            flashOut:Play()
            flashOut.Completed:Connect(function()
                flash:Destroy()
            end)
        end)
    else
        -- Just update progress bar normally for XP loss or reset
        updateProgressBar()
    end
    
    previousPercent = calculatePercent(newXP)
    previousXP = newXP
end)

level.Changed:Connect(function()
    previousPercent = 0
    updateProgressBar()
end)

-- Initial update
updateProgressBar(true)

-- Initialize coins display
if coins then
    updateCoins(coins.Value)
    
    -- Connect to coins value change
    coins.Changed:Connect(function(newValue)
        updateCoins(newValue)
    end)
else
    -- If Coins stat doesn't exist yet, wait for it to be created
    updateCoins(0) -- Initial display with 0
    
    -- Watch for Coins to be added to leaderstats
    leaderstats.ChildAdded:Connect(function(child)
        if child.Name == "Coins" then
            coins = child
            updateCoins(coins.Value)
            
            -- Connect to coins value change
            coins.Changed:Connect(function(newValue)
                updateCoins(newValue)
            end)
        end
    end)
end

-- Set initial load flag to false after everything is set up
isInitialLoad = false

-- Make the bar draggable
local isDragging = false
local dragInput
local dragStart
local startPos

local function update(input)
    local delta = input.Position - dragStart
    progressContainer.Position = UDim2.new(
        startPos.X.Scale,
        startPos.X.Offset + delta.X,
        startPos.Y.Scale,
        startPos.Y.Offset + delta.Y
    )
end

progressContainer.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStart = input.Position
        startPos = progressContainer.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                isDragging = false
            end
        end)
    end
end)

progressContainer.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and isDragging then
        update(input)
    end
end)

print("Modern Progress Bar initialized") 