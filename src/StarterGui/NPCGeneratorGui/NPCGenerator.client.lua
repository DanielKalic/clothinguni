-- Modern NPC Generator GUI
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Load the GUIManager module
local GUIManager = require(ReplicatedStorage:WaitForChild("GUIManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove any existing GUI with same name
local existingGui = playerGui:FindFirstChild("NPCGeneratorGui")
if existingGui and existingGui:IsA("ScreenGui") then
    existingGui:Destroy()
end

-- Create the remote event if it doesn't exist
local submitEvent = ReplicatedStorage:FindFirstChild("SubmitAdEvent")
if not submitEvent then
    submitEvent = Instance.new("RemoteEvent")
    submitEvent.Name = "SubmitAdEvent"
    submitEvent.Parent = ReplicatedStorage
end

-- Wait for purchase success event from server (don't create it)
local purchaseSuccessEvent = ReplicatedStorage:WaitForChild("PurchaseSuccessEvent", 10)
if not purchaseSuccessEvent then
    warn("NPCGenerator: Could not find PurchaseSuccessEvent - notifications may not work")
    purchaseSuccessEvent = Instance.new("RemoteEvent")
    purchaseSuccessEvent.Name = "PurchaseSuccessEvent"
    purchaseSuccessEvent.Parent = ReplicatedStorage
end

-- Wait for purchase failure event from server (don't create it) 
local purchaseFailedEvent = ReplicatedStorage:WaitForChild("PurchaseFailedEvent", 10)
if not purchaseFailedEvent then
    warn("NPCGenerator: Could not find PurchaseFailedEvent - notifications may not work")
    purchaseFailedEvent = Instance.new("RemoteEvent")
    purchaseFailedEvent.Name = "PurchaseFailedEvent"
    purchaseFailedEvent.Parent = ReplicatedStorage
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NPCGeneratorGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Create background frame with modern styling
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 600, 0, 350) -- Increased height to accommodate skin tone selector
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -175) -- Adjusted position for the increased height
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

-- Fix the rounded corners for the title bar (add a frame to cover the bottom corners)
local fixCorners = Instance.new("Frame")
fixCorners.Name = "FixCorners"
fixCorners.Size = UDim2.new(1, 0, 0, 15)
fixCorners.Position = UDim2.new(0, 0, 1, -15)
fixCorners.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
fixCorners.BorderSizePixel = 0
fixCorners.ZIndex = titleBar.ZIndex
fixCorners.Parent = titleBar

-- Add title text
local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Size = UDim2.new(1, -20, 1, 0)
titleText.Position = UDim2.new(0, 20, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "NPC Generator"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.TextSize = 22
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Center
titleText.Parent = titleBar

-- Add close button
local closeButton = Instance.new("ImageButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -40, 0, 10)
closeButton.BackgroundTransparency = 1
closeButton.Image = "rbxassetid://7743878857"
closeButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = titleBar

-- Create content container with adjusted position
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(0, 320, 0, 190) -- Increased height for skin tone selector
contentFrame.Position = UDim2.new(0, 40, 0, 100)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Create shirt ID input with modern styling
local shirtFrame = Instance.new("Frame")
shirtFrame.Name = "ShirtFrame"
shirtFrame.Size = UDim2.new(1, 0, 0, 45)
shirtFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
shirtFrame.BorderSizePixel = 0
shirtFrame.Parent = contentFrame

-- Add rounded corners to shirt frame
local shirtCorner = Instance.new("UICorner")
shirtCorner.CornerRadius = UDim.new(0, 8)
shirtCorner.Parent = shirtFrame

-- Add shirt input label
local shirtLabel = Instance.new("TextLabel")
shirtLabel.Name = "ShirtLabel"
shirtLabel.Size = UDim2.new(0, 100, 0, 25)
shirtLabel.Position = UDim2.new(0, 50, 0, 10)
shirtLabel.BackgroundTransparency = 1
shirtLabel.Text = "Shirt ID"
shirtLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
shirtLabel.TextSize = 16
shirtLabel.Font = Enum.Font.GothamMedium
shirtLabel.TextXAlignment = Enum.TextXAlignment.Left
shirtLabel.Parent = shirtFrame

-- Create the shirt ID text box with transparent background
local shirtInput = Instance.new("TextBox")
shirtInput.Name = "ShirtInput"
shirtInput.Size = UDim2.new(0, 200, 0, 30)
shirtInput.Position = UDim2.new(1, -220, 0, 8)
shirtInput.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
shirtInput.BackgroundTransparency = 1
shirtInput.TextColor3 = Color3.fromRGB(255, 255, 255)
shirtInput.PlaceholderText = "Enter Shirt ID (optional)"
shirtInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
shirtInput.Text = ""
shirtInput.TextSize = 16
shirtInput.Font = Enum.Font.Gotham
shirtInput.BorderSizePixel = 0
shirtInput.ClearTextOnFocus = false
shirtInput.Parent = shirtFrame

-- Add rounded corners to shirt input
local shirtInputCorner = Instance.new("UICorner")
shirtInputCorner.CornerRadius = UDim.new(0, 6)
shirtInputCorner.Parent = shirtInput

-- Create pants ID input with similar styling (positioned below shirt input)
local pantsFrame = Instance.new("Frame")
pantsFrame.Name = "PantsFrame"
pantsFrame.Size = UDim2.new(1, 0, 0, 45)
pantsFrame.Position = UDim2.new(0, 0, 0, 55)
pantsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
pantsFrame.BorderSizePixel = 0
pantsFrame.Parent = contentFrame

-- Add rounded corners to pants frame
local pantsCorner = Instance.new("UICorner")
pantsCorner.CornerRadius = UDim.new(0, 8)
pantsCorner.Parent = pantsFrame

-- Add pants input label
local pantsLabel = Instance.new("TextLabel")
pantsLabel.Name = "PantsLabel"
pantsLabel.Size = UDim2.new(0, 100, 0, 25)
pantsLabel.Position = UDim2.new(0, 50, 0, 10)
pantsLabel.BackgroundTransparency = 1
pantsLabel.Text = "Pants ID"
pantsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
pantsLabel.TextSize = 16
pantsLabel.Font = Enum.Font.GothamMedium
pantsLabel.TextXAlignment = Enum.TextXAlignment.Left
pantsLabel.Parent = pantsFrame

-- Create the pants ID text box with transparent background
local pantsInput = Instance.new("TextBox")
pantsInput.Name = "PantsInput"
pantsInput.Size = UDim2.new(0, 200, 0, 30)
pantsInput.Position = UDim2.new(1, -220, 0, 8)
pantsInput.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
pantsInput.BackgroundTransparency = 1
pantsInput.TextColor3 = Color3.fromRGB(255, 255, 255)
pantsInput.PlaceholderText = "Enter Pants ID (optional)"
pantsInput.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
pantsInput.Text = ""
pantsInput.TextSize = 16
pantsInput.Font = Enum.Font.Gotham
pantsInput.BorderSizePixel = 0
pantsInput.ClearTextOnFocus = false
pantsInput.Parent = pantsFrame

-- Add rounded corners to pants input
local pantsInputCorner = Instance.new("UICorner")
pantsInputCorner.CornerRadius = UDim.new(0, 6)
pantsInputCorner.Parent = pantsInput

-- Create Skin Tone input with similar styling (positioned below pants input)
local skinToneFrame = Instance.new("Frame")
skinToneFrame.Name = "SkinToneFrame"
skinToneFrame.Size = UDim2.new(1, 0, 0, 45)
skinToneFrame.Position = UDim2.new(0, 0, 0, 110)
skinToneFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
skinToneFrame.BorderSizePixel = 0
skinToneFrame.Parent = contentFrame

-- Add rounded corners to skin tone frame
local skinToneCorner = Instance.new("UICorner")
skinToneCorner.CornerRadius = UDim.new(0, 8)
skinToneCorner.Parent = skinToneFrame

-- Add skin tone input label
local skinToneLabel = Instance.new("TextLabel")
skinToneLabel.Name = "SkinToneLabel"
skinToneLabel.Size = UDim2.new(0, 100, 0, 25)
skinToneLabel.Position = UDim2.new(0, 10, 0, 10)
skinToneLabel.BackgroundTransparency = 1
skinToneLabel.Text = "Skin Tone"
skinToneLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
skinToneLabel.TextSize = 16
skinToneLabel.Font = Enum.Font.GothamMedium
skinToneLabel.TextXAlignment = Enum.TextXAlignment.Left
skinToneLabel.Parent = skinToneFrame

-- Create skin tone selector
-- We'll create a row of preset skin tone colors to choose from
local skinToneContainer = Instance.new("Frame")
skinToneContainer.Name = "SkinToneContainer"
skinToneContainer.Size = UDim2.new(0, 200, 0, 30)
skinToneContainer.Position = UDim2.new(1, -220, 0, 8)
skinToneContainer.BackgroundTransparency = 1
skinToneContainer.Parent = skinToneFrame

-- Define skin tone presets (common Roblox skin tones)
local skinTones = {
    Color3.fromRGB(255, 204, 153), -- Light
    Color3.fromRGB(255, 175, 125), -- Tan
    Color3.fromRGB(217, 134, 80),  -- Medium
    Color3.fromRGB(160, 95, 53),   -- Dark
    Color3.fromRGB(115, 62, 29),   -- Darker
    Color3.fromRGB(238, 238, 238)  -- Pale
}

-- Track the currently selected skin tone
local selectedSkinTone = skinTones[1]
local skinToneButtons = {}

-- Create the skin tone buttons
for i, toneColor in ipairs(skinTones) do
    local buttonSize = 25
    local spacing = 5
    local posX = (i - 1) * (buttonSize + spacing)
    
    local toneButton = Instance.new("TextButton")
    toneButton.Name = "ToneButton" .. i
    toneButton.Size = UDim2.new(0, buttonSize, 0, buttonSize)
    toneButton.Position = UDim2.new(0, posX, 0, 0)
    toneButton.BackgroundColor3 = toneColor
    toneButton.Text = ""
    toneButton.BorderSizePixel = 0
    toneButton.Parent = skinToneContainer
    
    -- Add rounded corners
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = toneButton
    
    -- Add selection indicator
    local selectionIndicator = Instance.new("UIStroke")
    selectionIndicator.Name = "SelectionIndicator"
    selectionIndicator.Color = Color3.fromRGB(255, 255, 255)
    selectionIndicator.Thickness = 2
    selectionIndicator.Transparency = 1 -- Initially transparent
    selectionIndicator.Parent = toneButton
    
    -- Store the button for later reference
    skinToneButtons[i] = {
        button = toneButton,
        indicator = selectionIndicator,
        color = toneColor
    }
    
    -- Set up click event
    toneButton.MouseButton1Click:Connect(function()
        print("DEBUG: Skin tone button " .. i .. " clicked")
        
        -- Update selection visuals first
        for _, buttonData in ipairs(skinToneButtons) do
            buttonData.indicator.Transparency = 1
        end
        selectionIndicator.Transparency = 0
        selectedSkinTone = toneColor
        print("DEBUG: Selected new skin tone: " .. tostring(toneColor))
        
        -- The key fix: Use a global flag to indicate skin tone was changed
        -- This will be checked when the GUI is visible and model is created
        _G.SkinToneNeedsUpdate = true
        
        -- If the GUI is visible and model exists, apply the change immediately
        if mainFrame and mainFrame.Visible then
            -- Allow a small delay for viewportFrame to initialize if needed
            spawn(function()
                for attempt = 1, 5 do -- Try up to 5 times
                    if viewportFrame and viewportFrame:IsA("ViewportFrame") then
                        local npcModel = viewportFrame:FindFirstChildOfClass("Model")
                        if npcModel then
                            applySkinColor(npcModel, toneColor)
                            print("DEBUG: Applied skin tone directly after button click, attempt " .. attempt)
                            _G.SkinToneNeedsUpdate = false
                            break
                        end
                    end
                    wait(0.1) -- Wait and try again
                end
            end)
        end
    end)
end

-- Mark the first tone as selected by default
skinToneButtons[1].indicator.Transparency = 0

-- Helper function to apply skin color to a model (with error handling)
function applySkinColor(model, color3)
    print("DEBUG: applySkinColor called - Model: " .. (model and model.Name or "nil") .. ", Color: " .. tostring(color3))
    if not model or typeof(model) ~= "Instance" then
        print("DEBUG: applySkinColor - Invalid model")
        return -- Safety check
    end
    
    -- Find or create the Body Colors instance
    local bodyColors = model:FindFirstChild("Body Colors")
    if not bodyColors then
        print("DEBUG: applySkinColor - Creating new BodyColors")
        bodyColors = Instance.new("BodyColors")
        bodyColors.Parent = model
    end
    
    -- Apply the color to all body parts
    local brickColor = BrickColor.new(color3)
    print("DEBUG: applySkinColor - Setting BrickColor: " .. tostring(brickColor))
    bodyColors.HeadColor = brickColor
    bodyColors.TorsoColor = brickColor
    bodyColors.LeftArmColor = brickColor
    bodyColors.RightArmColor = brickColor
    bodyColors.LeftLegColor = brickColor
    bodyColors.RightLegColor = brickColor
    print("DEBUG: applySkinColor - Colors applied")
end

-- Create NPC Preview section (right side of the GUI)
local previewFrame = Instance.new("Frame")
previewFrame.Name = "PreviewFrame"
previewFrame.Size = UDim2.new(0, 200, 0, 200)
previewFrame.Position = UDim2.new(1, -240, 0, 70)
previewFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
previewFrame.BorderSizePixel = 0
previewFrame.Parent = mainFrame

-- Add rounded corners to preview frame
local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(0, 8)
previewCorner.Parent = previewFrame

-- Add preview title
local previewTitle = Instance.new("TextLabel")
previewTitle.Name = "PreviewTitle"
previewTitle.Size = UDim2.new(1, 0, 0, 30)
previewTitle.Position = UDim2.new(0, 0, 0, -35)
previewTitle.BackgroundTransparency = 1
previewTitle.Text = "NPC Preview"
previewTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
previewTitle.TextSize = 16
previewTitle.Font = Enum.Font.GothamMedium
previewTitle.Parent = previewFrame

-- Add preview instruction
local previewInstruction = Instance.new("TextLabel")
previewInstruction.Name = "PreviewInstruction"
previewInstruction.Size = UDim2.new(1, 0, 0, 20)
previewInstruction.Position = UDim2.new(0, 0, 0, -15)
previewInstruction.BackgroundTransparency = 1
previewInstruction.Text = "See how your clothing will look"
previewInstruction.TextColor3 = Color3.fromRGB(150, 150, 150)
previewInstruction.TextSize = 12
previewInstruction.Font = Enum.Font.Gotham
previewInstruction.Parent = previewFrame

-- Create ViewportFrame for the NPC model preview
local viewportFrame = Instance.new("ViewportFrame")
viewportFrame.Name = "ViewportFrame"
viewportFrame.Size = UDim2.new(1, -20, 1, -20)
viewportFrame.Position = UDim2.new(0, 10, 0, 10)
viewportFrame.BackgroundTransparency = 1
viewportFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
viewportFrame.Parent = previewFrame

-- Add rounded corners to viewport frame
local viewportCorner = Instance.new("UICorner")
viewportCorner.CornerRadius = UDim.new(0, 6)
viewportCorner.Parent = viewportFrame

-- Create generate button with beautiful gradient
local generateButton = Instance.new("TextButton")
generateButton.Name = "GenerateButton"
generateButton.Size = UDim2.new(1, 0, 0, 40)
generateButton.Position = UDim2.new(0, 0, 0, 165) -- Position below skin tone input
generateButton.BackgroundColor3 = Color3.fromRGB(30, 90, 200)
generateButton.BorderSizePixel = 0
generateButton.Text = "Generate NPC"
generateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
generateButton.TextSize = 18
generateButton.Font = Enum.Font.GothamBold
generateButton.Parent = contentFrame

-- Add rounded corners to generate button
local generateCorner = Instance.new("UICorner")
generateCorner.CornerRadius = UDim.new(0, 8)
generateCorner.Parent = generateButton

-- Add gradient to generate button
local generateGradient = Instance.new("UIGradient")
generateGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 170, 240)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 120, 200))
})
generateGradient.Rotation = 90
generateGradient.Parent = generateButton

-- Create validation message label (initially invisible)
local validationLabel = Instance.new("TextLabel")
validationLabel.Name = "ValidationLabel"
validationLabel.Size = UDim2.new(1, 0, 0, 30)
validationLabel.Position = UDim2.new(0, 0, 0, 45)
validationLabel.BackgroundTransparency = 1
validationLabel.Text = "Please enter at least one ID!"
validationLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
validationLabel.TextSize = 16
validationLabel.Font = Enum.Font.GothamSemibold
validationLabel.Visible = false
validationLabel.Parent = generateButton

-- Create success message label (initially invisible)
local successLabel = Instance.new("TextLabel")
successLabel.Name = "SuccessLabel"
successLabel.Size = UDim2.new(1, 0, 0, 30)
successLabel.Position = UDim2.new(0, 0, 0, -35)
successLabel.BackgroundTransparency = 1
successLabel.Text = "NPC generated successfully!"
successLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
successLabel.TextSize = 16
successLabel.Font = Enum.Font.GothamSemibold
successLabel.Visible = false
successLabel.Parent = generateButton

-- Create result dialog frame for success/failure messages
local resultDialog = Instance.new("Frame")
resultDialog.Name = "ResultDialog"
resultDialog.Size = UDim2.new(0, 300, 0, 150)
resultDialog.Position = UDim2.new(0.5, -150, 0.5, -75)
resultDialog.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
resultDialog.BorderSizePixel = 0
resultDialog.Visible = false
resultDialog.ZIndex = 10
resultDialog.Parent = screenGui

-- Add rounded corners to dialog
local dialogCorner = Instance.new("UICorner")
dialogCorner.CornerRadius = UDim.new(0, 8)
dialogCorner.Parent = resultDialog

-- Add message label
local dialogMessage = Instance.new("TextLabel")
dialogMessage.Name = "DialogMessage"
dialogMessage.Size = UDim2.new(1, -40, 0, 60)
dialogMessage.Position = UDim2.new(0, 20, 0, 20)
dialogMessage.BackgroundTransparency = 1
dialogMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
dialogMessage.TextSize = 18
dialogMessage.Font = Enum.Font.GothamBold
dialogMessage.TextWrapped = true
dialogMessage.ZIndex = 11
dialogMessage.Parent = resultDialog

-- Add OK button
local okButton = Instance.new("TextButton")
okButton.Name = "OKButton"
okButton.Size = UDim2.new(0, 120, 0, 40)
okButton.Position = UDim2.new(0.5, -60, 1, -60)
okButton.BackgroundColor3 = Color3.fromRGB(30, 90, 200)
okButton.BorderSizePixel = 0
okButton.Text = "OK"
okButton.TextColor3 = Color3.fromRGB(255, 255, 255)
okButton.TextSize = 16
okButton.Font = Enum.Font.GothamBold
okButton.ZIndex = 11
okButton.Parent = resultDialog

-- Add rounded corners to button
local okButtonCorner = Instance.new("UICorner")
okButtonCorner.CornerRadius = UDim.new(0, 8)
okButtonCorner.Parent = okButton

-- Add gradient to button
local okButtonGradient = Instance.new("UIGradient")
okButtonGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 170, 240)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 120, 200))
})
okButtonGradient.Rotation = 90
okButtonGradient.Parent = okButton

-- Add button hover effect
okButton.MouseEnter:Connect(function()
    TweenService:Create(
        okButton,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(70, 140, 220)}
    ):Play()
end)

okButton.MouseLeave:Connect(function()
    TweenService:Create(
        okButton,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(30, 90, 200)}
    ):Play()
end)

-- Button press effect
okButton.MouseButton1Down:Connect(function()
    TweenService:Create(
        okButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 115, 0, 38), Position = UDim2.new(0.5, -57.5, 1, -59)}
    ):Play()
end)

okButton.MouseButton1Up:Connect(function()
    TweenService:Create(
        okButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 120, 0, 40), Position = UDim2.new(0.5, -60, 1, -60)}
    ):Play()
end)

-- Handle OK button click
okButton.MouseButton1Click:Connect(function()
    resultDialog.Visible = false
    -- No need to close the main GUI here as it should close before showing the dialog
end)

-- Function to show dialog with message
local function showDialog(message, isSuccess)
    dialogMessage.Text = message
    dialogMessage.TextColor3 = isSuccess and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 100, 100)
    resultDialog.Visible = true
end

-- Status animation function
local function showStatus(isSuccess, text)
    local statusLabel = isSuccess and successLabel or validationLabel
    local otherLabel = isSuccess and validationLabel or successLabel
    
    otherLabel.Visible = false
    statusLabel.Text = text or statusLabel.Text
    statusLabel.Visible = true
    statusLabel.TextTransparency = 0
    
    -- Fade out after 3 seconds
    delay(3, function()
        local fadeOut = TweenService:Create(
            statusLabel,
            TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {TextTransparency = 1}
        )
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            statusLabel.Visible = false
        end)
    end)
end

-- Add hover effect to generate button
generateButton.MouseEnter:Connect(function()
    TweenService:Create(
        generateButton,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(70, 140, 220)}
    ):Play()
end)

generateButton.MouseLeave:Connect(function()
    TweenService:Create(
        generateButton,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(30, 90, 200)}
    ):Play()
end)

-- Button-down effect
generateButton.MouseButton1Down:Connect(function()
    TweenService:Create(
        generateButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(50, 110, 180), Size = UDim2.new(0.98, 0, 0, 38), Position = UDim2.new(0.01, 0, 0, 166)}
    ):Play()
end)

generateButton.MouseButton1Up:Connect(function()
    TweenService:Create(
        generateButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(70, 140, 220), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 165)}
    ):Play()
end)

-- Create the toggle button
local toggleButton = Instance.new("ImageButton")
toggleButton.Name = "NPCGeneratorToggle"
toggleButton.Size = UDim2.new(0, 50, 0, 50)
toggleButton.Position = UDim2.new(0, 80, 1, -110) -- Position next to ListingsGUI toggle, above daily bonus GUI
toggleButton.BackgroundColor3 = Color3.fromRGB(173, 173, 173)
toggleButton.BorderSizePixel = 0
toggleButton.Image = "rbxassetid://136200156916120"
toggleButton.ImageColor3 = Color3.fromRGB(220, 220, 255)
toggleButton.Parent = screenGui

-- Register the toggle button with the GUIManager
-- COMMENTED OUT: Don't use GUIManager for toggle buttons - it causes issues during crate opening
-- GUIManager:RegisterToggleButton("NPCGenerator", toggleButton)

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

-- Function to ensure toggle buttons stay visible always (ignore visible parameter)
local function setToggleButtonsVisible(visible)
    -- ALWAYS keep both toggle buttons visible, ignore the visible parameter
    toggleButton.Visible = true
    
    -- Find and keep the ListingsGUIToggle button visible as well
    local listingsGUI = playerGui:FindFirstChild("ListingsGUI")
    if listingsGUI then
        local listingsToggle = listingsGUI:FindFirstChild("ListingsGUIToggle")
        if listingsToggle then
            listingsToggle.Visible = true
        end
    end
end

-- Setup the NPC preview model
local function setupPreviewModel()
    -- Clear the ViewportFrame first
    for _, child in pairs(viewportFrame:GetChildren()) do
        if child:IsA("Model") or child:IsA("Camera") then
            child:Destroy()
        end
    end
    
    -- Create a camera for the ViewportFrame
    local camera = Instance.new("Camera")
    camera.FieldOfView = 70
    viewportFrame.CurrentCamera = camera
    camera.Parent = viewportFrame
    
    -- Add a light to improve visibility
    local light = Instance.new("PointLight")
    light.Brightness = 1
    light.Range = 10
    light.Parent = viewportFrame
    
    local npcModel = nil
    
    -- First try to find NPCModel in ReplicatedStorage
    local replModel = ReplicatedStorage:FindFirstChild("NPCModel")
    if replModel and replModel:IsA("Model") then
        npcModel = replModel:Clone()
    else
        -- Create a basic humanoid model
        npcModel = Instance.new("Model")
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
    end
    
    -- Position the model and add it to the ViewportFrame
    npcModel.Parent = viewportFrame
    
    -- Position the camera to show the full NPC including feet
    local head = npcModel:FindFirstChild("Head")
    if head then
        -- Move the camera in front of the character so it faces forward
        camera.CFrame = CFrame.new(head.Position + Vector3.new(0, -1, -5.5), head.Position + Vector3.new(0, -1, 0))
    else
        local primaryPart = npcModel.PrimaryPart or npcModel:FindFirstChild("HumanoidRootPart")
        if primaryPart then
            -- Position the camera in front of the model
            camera.CFrame = CFrame.new(primaryPart.Position + Vector3.new(0, -1, -5.5), primaryPart.Position + Vector3.new(0, -1, 0))
        end
    end
    
    -- Rotate the model slowly
    local rotation = 0
    local rotationConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if npcModel and npcModel.Parent then
            local primaryPart = npcModel.PrimaryPart or npcModel:FindFirstChild("HumanoidRootPart") or npcModel:FindFirstChild("Torso")
            if primaryPart then
                rotation = rotation + deltaTime * 0.5
                primaryPart.CFrame = CFrame.new(primaryPart.Position) * CFrame.Angles(0, rotation, 0)
            end
        else
            if rotationConnection then -- Add nil check
                rotationConnection:Disconnect()
            end
        end
    end)
    
    -- Store the connection in the ViewportFrame
    viewportFrame:SetAttribute("RotationConnection", true)
    viewportFrame.AncestryChanged:Connect(function(_, parent)
        if not parent then
            if rotationConnection then -- Add nil check
                rotationConnection:Disconnect()
            end
        end
    end)
    
    -- Apply default skin tone
    applySkinColor(npcModel, selectedSkinTone)
    
    return npcModel
end

-- Get the remote function for fetching clothing templates
local getClothingTemplateFunc = ReplicatedStorage:WaitForChild("GetClothingTemplateFunc")

-- Function to apply clothing to the model using server-side template fetching
local function applyClothingToModel(model, assetId, assetType)
    if not model or not assetId or assetId == "" then return end
    
    spawn(function()
        print("DEBUG: Requesting " .. assetType .. " template for ID: " .. assetId)
        
        -- Get the actual template from the server
        local success, template = pcall(function()
            return getClothingTemplateFunc:InvokeServer(assetId, assetType)
        end)
        
        if success and template then
            print("DEBUG: Received template: " .. template)
            
            -- Apply the template to the model
            local clothing = model:FindFirstChildOfClass(assetType)
            if not clothing then
                clothing = Instance.new(assetType)
                clothing.Parent = model
            end
            
            if assetType == "Shirt" then
                clothing.ShirtTemplate = template
            elseif assetType == "Pants" then
                clothing.PantsTemplate = template
            end
            
            print("DEBUG: Successfully applied " .. assetType .. " template to preview model")
        else
            print("DEBUG: Failed to get " .. assetType .. " template for ID: " .. assetId)
            
            -- Fallback to direct asset ID
            local clothing = model:FindFirstChildOfClass(assetType)
            if not clothing then
                clothing = Instance.new(assetType)
                clothing.Parent = model
            end
            
            local fallbackUrl = "rbxassetid://" .. assetId
            if assetType == "Shirt" then
                clothing.ShirtTemplate = fallbackUrl
            elseif assetType == "Pants" then
                clothing.PantsTemplate = fallbackUrl
            end
            
            print("DEBUG: Applied fallback URL: " .. fallbackUrl)
        end
    end)
end

-- Function to update the preview model with the entered IDs
local function updatePreview()
    print("DEBUG: updatePreview called")
    pcall(function()
        if not viewportFrame then 
            print("DEBUG: updatePreview - viewportFrame is nil")
            return 
        end
        
        local npcModel = viewportFrame:FindFirstChildOfClass("Model")
        print("DEBUG: updatePreview - Existing model: " .. (npcModel and npcModel.Name or "nil"))
        
        if not npcModel then
            print("DEBUG: updatePreview - Creating new model")
            npcModel = setupPreviewModel()
            if not npcModel then 
                print("DEBUG: updatePreview - Failed to create model")
                return 
            end
        end
        
        -- Update shirt
        local shirtId = shirtInput.Text
        if shirtId and shirtId ~= "" then
            print("DEBUG: updatePreview - Setting shirt: " .. shirtId)
            applyClothingToModel(npcModel, shirtId, "Shirt")
        end
        
        -- Update pants
        local pantsId = pantsInput.Text
        if pantsId and pantsId ~= "" then
            print("DEBUG: updatePreview - Setting pants: " .. pantsId)
            applyClothingToModel(npcModel, pantsId, "Pants")
        end
        
        -- Apply current skin tone
        print("DEBUG: updatePreview - Applying saved skin tone: " .. tostring(selectedSkinTone))
        applySkinColor(npcModel, selectedSkinTone)
    end)
end

-- Setup the preview model when the GUI opens
local function initializePreview()
    print("DEBUG: initializePreview called")
    
    local model = setupPreviewModel()
    
    -- Apply the currently selected skin tone
    if model then
        applySkinColor(model, selectedSkinTone)
        _G.SkinToneNeedsUpdate = false -- Clear the update flag
    end
    
    -- Set up a visibility change watcher to ensure skin tones take effect
    spawn(function()
        wait(0.5) -- Initial delay to let everything settle
        while wait(0.2) do -- Check periodically
            if not mainFrame then break end -- Exit if the frame is gone
            
            -- If the frame is visible and a skin tone update is pending
            if mainFrame.Visible and _G.SkinToneNeedsUpdate then
                if viewportFrame and viewportFrame:FindFirstChildOfClass("Model") then
                    local npcModel = viewportFrame:FindFirstChildOfClass("Model")
                    applySkinColor(npcModel, selectedSkinTone)
                    print("DEBUG: Applied pending skin tone update from visibility watcher")
                    _G.SkinToneNeedsUpdate = false
                end
            end
        end
    end)
end

-- Connect input change events to update the preview
shirtInput.Changed:Connect(function(property)
    if property == "Text" then
        print("DEBUG: ShirtInput changed: " .. shirtInput.Text)
        updatePreview()
    end
end)

pantsInput.Changed:Connect(function(property)
    if property == "Text" then
        print("DEBUG: PantsInput changed: " .. pantsInput.Text)
        updatePreview()
    end
end)

-- Opening animation with deferred initialization
local function showGUI()
    -- Clear input fields when opening the GUI
    shirtInput.Text = ""
    pantsInput.Text = ""
    
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
        {Size = UDim2.new(0, 600, 0, 350), Position = UDim2.new(0.5, -300, 0.5, -175), BackgroundTransparency = 0}
    )
    
    local shadowTween = TweenService:Create(
        shadow,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {ImageTransparency = 0.5}
    )
    
    openTween:Play()
    shadowTween:Play()
    
    -- Update the GUI state in the manager
    GUIManager:SetGUIState("NPCGeneratorOpen", true)
    -- COMMENTED OUT: Don't hide toggle button anymore - let it stay visible always
    -- toggleButton.Visible = false
    
    -- Check if we have a pending skin tone update
    if _G.SkinToneNeedsUpdate then
        print("DEBUG: Pending skin tone update detected during GUI open")
    end
    
    -- Wait for the animation to complete, then initialize the preview
    spawn(function()
        wait(0.6) -- Wait slightly longer than animation
        initializePreview()
        
        -- Ensure any pending skin tone updates are applied
        if _G.SkinToneNeedsUpdate then
            wait(0.2) -- Small additional delay
            if viewportFrame and viewportFrame:FindFirstChildOfClass("Model") then
                local npcModel = viewportFrame:FindFirstChildOfClass("Model")
                applySkinColor(npcModel, selectedSkinTone)
                print("DEBUG: Applied skin tone after GUI open")
                _G.SkinToneNeedsUpdate = false
            end
        end
    end)
end

-- Connect to visibility changes to handle skin tone updates
mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    if mainFrame.Visible and _G.SkinToneNeedsUpdate then
        spawn(function()
            wait(0.3) -- Wait for things to initialize
            if viewportFrame and viewportFrame:FindFirstChildOfClass("Model") then
                local npcModel = viewportFrame:FindFirstChildOfClass("Model")
                applySkinColor(npcModel, selectedSkinTone)
                print("DEBUG: Applied skin tone after visibility change")
                _G.SkinToneNeedsUpdate = false
            end
        end)
    end
end)

-- Closing animation
local function hideGUI()
    -- Create and play the closing animation
    local closeTween = TweenService:Create(
        mainFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1}
    )
    
    local shadowTween = TweenService:Create(
        shadow,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {ImageTransparency = 1}
    )
    
    closeTween.Completed:Connect(function()
        mainFrame.Visible = false
        -- Update the GUI state in the manager
        GUIManager:SetGUIState("NPCGeneratorOpen", false)
        -- COMMENTED OUT: Toggle button should stay visible always
        -- toggleButton.Visible = true
    end)
    
    closeTween:Play()
    shadowTween:Play()
end

-- Connect the close button
closeButton.MouseButton1Click:Connect(hideGUI)

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
        {BackgroundColor3 = Color3.fromRGB(173, 173, 173), Size = UDim2.new(0, 55, 0, 55), Position = UDim2.new(0, 77.5, 1, -112.5)}
    ):Play()
end)

toggleButton.MouseLeave:Connect(function()
    TweenService:Create(
        toggleButton,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundColor3 = Color3.fromRGB(173, 173, 173), Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 80, 1, -110)}
    ):Play()
end)

-- Button-down effect
toggleButton.MouseButton1Down:Connect(function()
    TweenService:Create(
        toggleButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 45, 0, 45), Position = UDim2.new(0, 82.5, 1, -107.5)}
    ):Play()
end)

toggleButton.MouseButton1Up:Connect(function()
    TweenService:Create(
        toggleButton,
        TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(0, 80, 1, -110)}
    ):Play()
end)

-- Function to show a notification on screen
local function showNotification(message, isSuccess)
    print("DEBUG: [NPCGenerator] showNotification called with message:", message, "isSuccess:", isSuccess)
    
    -- Create notification frame
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 400, 0, 60)
    notification.Position = UDim2.new(0.5, -200, 0.08, 0) -- Moved to a safer middle position
    notification.BackgroundColor3 = isSuccess and Color3.fromRGB(40, 120, 40) or Color3.fromRGB(120, 40, 40)
    notification.BorderSizePixel = 0
    notification.ZIndex = 100
    notification.Parent = screenGui
    
    print("DEBUG: [NPCGenerator] Notification frame created and parented to screenGui")
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    -- Add message text
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Name = "MessageLabel"
    messageLabel.Size = UDim2.new(1, -20, 1, 0)
    messageLabel.Position = UDim2.new(0, 10, 0, 0)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageLabel.TextSize = 18
    messageLabel.Font = Enum.Font.GothamBold
    messageLabel.TextXAlignment = Enum.TextXAlignment.Center
    messageLabel.TextYAlignment = Enum.TextYAlignment.Center
    messageLabel.TextWrapped = true
    messageLabel.ZIndex = 101
    messageLabel.Parent = notification
    
    -- Add icon
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 30, 0, 30)
    icon.Position = UDim2.new(0, 10, 0.5, -15)
    icon.BackgroundTransparency = 1
    icon.Text = isSuccess and "✓" or "✗"
    icon.TextColor3 = Color3.fromRGB(255, 255, 255)
    icon.TextSize = 24
    icon.Font = Enum.Font.GothamBold
    icon.TextXAlignment = Enum.TextXAlignment.Center
    icon.TextYAlignment = Enum.TextYAlignment.Center
    icon.ZIndex = 101
    icon.Parent = notification
    
    -- Adjust message position to account for icon
    messageLabel.Position = UDim2.new(0, 45, 0, 0)
    messageLabel.Size = UDim2.new(1, -55, 1, 0)
    
    -- Animate in
    notification.Position = UDim2.new(0.5, -200, 0, -70) -- Start above screen
    local tweenIn = TweenService:Create(
        notification,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -200, 0.08, 0)} -- Animate to safer middle position
    )
    tweenIn:Play()
    
    -- Auto-remove after 4 seconds
    spawn(function()
        wait(4)
        local tweenOut = TweenService:Create(
            notification,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -200, 0, -70)} -- Exit upward
        )
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            notification:Destroy()
        end)
    end)
end

-- Listen for purchase success
purchaseSuccessEvent.OnClientEvent:Connect(function()
    print("DEBUG: [NPCGenerator] Received purchase success event!")
    
    -- Clear the input fields
    shirtInput.Text = ""
    pantsInput.Text = ""
    
    -- Show success notification
    print("DEBUG: [NPCGenerator] About to show success notification")
    showNotification("NPC has been added to the Clothing Universe", true)
    print("DEBUG: [NPCGenerator] Success notification should be visible now")
end)

-- Listen for purchase failure
purchaseFailedEvent.OnClientEvent:Connect(function()
    print("DEBUG: [NPCGenerator] Received purchase failure event!")
    
    -- Show failure notification
    print("DEBUG: [NPCGenerator] About to show failure notification")
    showNotification("Purchase failed", false)
    print("DEBUG: [NPCGenerator] Failure notification should be visible now")
end)

-- Function to handle the generate button click
generateButton.MouseButton1Click:Connect(function()
    local shirtId = shirtInput.Text
    local pantsId = pantsInput.Text

    if shirtId == "" and pantsId == "" then
        showStatus(false, "Please enter at least one ID!")
        return
    end

    local adData = {
        shirt = shirtId ~= "" and shirtId or nil,
        pants = pantsId ~= "" and pantsId or nil,
        skinTone = selectedSkinTone, -- Include the selected skin tone
        creationDate = os.time() -- Add creation timestamp
    }

    -- Close the main GUI before submitting
    hideGUI()
    
    -- Submit the ad data to the server.
    submitEvent:FireServer(adData)
    
    -- No processing dialog - server will send success/failure events directly
end)

-- Handle numbers-only input
local function validateNumbersOnly(textBox)
    textBox:GetPropertyChangedSignal("Text"):Connect(function()
        local text = textBox.Text
        local filteredText = text:gsub("[^0-9]", "")
        
        if text ~= filteredText then
            textBox.Text = filteredText
        end
    end)
end

validateNumbersOnly(shirtInput)
validateNumbersOnly(pantsInput)

-- Initialize GUI visibility (don't open it on startup)
mainFrame.Visible = false  -- Ensure it's hidden initially
GUIManager:SetGUIState("NPCGeneratorOpen", false)

-- Make sure toggle buttons are visible at startup
toggleButton.Visible = true
print("DEBUG: [NPCGenerator] Toggle button set to visible at position:", toggleButton.Position)
print("DEBUG: [NPCGenerator] Toggle button size:", toggleButton.Size)
print("DEBUG: [NPCGenerator] Toggle button parent:", toggleButton.Parent and toggleButton.Parent.Name or "nil")

print("NPC Generator GUI initialized")

-- Listen for the ListingsGUI being closed
spawn(function()
    local listingsGUIClosed = ReplicatedStorage:FindFirstChild("ListingsGUIClosed")
    if not listingsGUIClosed then
        listingsGUIClosed = ReplicatedStorage:WaitForChild("ListingsGUIClosed", 10)
    end
    
    if listingsGUIClosed then
        listingsGUIClosed.Event:Connect(function()
            -- If our GUI is also closed, show the toggle buttons
            if not mainFrame.Visible then
                setToggleButtonsVisible(true)
            end
        end)
    end
end)

-- Let's use a small timer to check if the model is being overwritten after skin tone selection
spawn(function()
    local lastModelCheckTime = tick()
    local function checkModelSkinTone()
        if not viewportFrame then return end
        
        local npcModel = viewportFrame:FindFirstChildOfClass("Model")
        if npcModel then
            local bodyColors = npcModel:FindFirstChild("Body Colors") 
            if bodyColors then
                local currentHeadColor = bodyColors.HeadColor
                print("DEBUG: Current model skin tone: " .. tostring(currentHeadColor))
                
                -- Verify if it matches selected tone (approximately)
                local selectedBrickColor = BrickColor.new(selectedSkinTone)
                print("DEBUG: Selected skin tone: " .. tostring(selectedBrickColor))
                
                if currentHeadColor ~= selectedBrickColor then
                    print("DEBUG: WARNING! Skin tone mismatch detected. Current: " .. tostring(currentHeadColor) .. " vs Selected: " .. tostring(selectedBrickColor))
                end
            end
        end
        
        lastModelCheckTime = tick()
    end
    
    while wait(1) do
        if tick() - lastModelCheckTime >= 1 then
            checkModelSkinTone()
        end
    end
end) 