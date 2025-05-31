-- Daily Objectives GUI
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for daily objectives events
local objectivesFolder = ReplicatedStorage:WaitForChild("DailyObjectives")
local getObjectivesEvent = objectivesFolder:WaitForChild("GetObjectivesFunc")
local objectivesUpdatedEvent = objectivesFolder:WaitForChild("ObjectivesUpdatedEvent")

-- Variables
local screenGui
local mainFrame
local toggleButton
local objectiveFrames = {}
local currentObjectives = {}
local isGUIVisible = false

-- Colors (matching Daily Bonus style)
local COMPLETED_COLOR = Color3.fromRGB(0, 255, 0) -- Green
local INCOMPLETE_COLOR = Color3.fromRGB(255, 100, 100) -- Red for incomplete
local BACKGROUND_COLOR = Color3.fromRGB(40, 40, 40) -- Same as Daily Bonus
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local TITLE_COLOR = Color3.fromRGB(255, 215, 0) -- Gold like Daily Bonus
local REWARD_COLOR = Color3.fromRGB(180, 180, 180) -- Grey instead of yellow

-- Function to create an objective frame (compact style like Daily Bonus)
local function createObjectiveFrame(objectiveData, objectiveType, parent)
    local frame = Instance.new("Frame")
    frame.Name = objectiveType .. "Frame"
    frame.Size = UDim2.new(1, -10, 0, 55)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 6)
    frameCorner.Parent = frame
    
    -- Objective description (main text)
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(1, -60, 0, 20)
    description.Position = UDim2.new(0, 8, 0, 5)
    description.BackgroundTransparency = 1
    description.Text = objectiveData.description
    description.TextColor3 = TEXT_COLOR
    description.TextSize = 12
    description.Font = Enum.Font.GothamSemibold
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextTruncate = Enum.TextTruncate.AtEnd
    description.Parent = frame
    
    -- Progress text (red if incomplete, green if complete)
    local progressText = Instance.new("TextLabel")
    progressText.Name = "ProgressText"
    progressText.Size = UDim2.new(0, 80, 0, 15)
    progressText.Position = UDim2.new(0, 8, 0, 25)
    progressText.BackgroundTransparency = 1
    progressText.Text = objectiveData.current .. "/" .. objectiveData.target
    progressText.TextColor3 = objectiveData.completed and COMPLETED_COLOR or INCOMPLETE_COLOR
    progressText.TextSize = 11
    progressText.Font = Enum.Font.GothamMedium
    progressText.TextXAlignment = Enum.TextXAlignment.Left
    progressText.Parent = frame
    
    -- Reward text (grey instead of yellow)
    local rewardText = Instance.new("TextLabel")
    rewardText.Name = "RewardText"
    rewardText.Size = UDim2.new(1, -95, 0, 15)
    rewardText.Position = UDim2.new(0, 90, 0, 25)
    rewardText.BackgroundTransparency = 1
    rewardText.Text = "+" .. objectiveData.xp .. " XP, +" .. objectiveData.coins .. " Coins"
    rewardText.TextColor3 = REWARD_COLOR
    rewardText.TextSize = 10
    rewardText.Font = Enum.Font.Gotham
    rewardText.TextXAlignment = Enum.TextXAlignment.Left
    rewardText.Parent = frame
    
    -- Completion checkmark
    if objectiveData.completed then
        local checkmark = Instance.new("TextLabel")
        checkmark.Name = "Checkmark"
        checkmark.Size = UDim2.new(0, 25, 0, 25)
        checkmark.Position = UDim2.new(1, -30, 0.5, -12.5)
        checkmark.BackgroundTransparency = 1
        checkmark.Text = "✓"
        checkmark.TextColor3 = COMPLETED_COLOR
        checkmark.TextSize = 16
        checkmark.Font = Enum.Font.GothamBold
        checkmark.TextXAlignment = Enum.TextXAlignment.Center
        checkmark.Parent = frame
    end
    
    return frame
end

-- Function to update objectives display
updateObjectivesDisplay = function()
    print("DEBUG: updateObjectivesDisplay called")
    
    if not currentObjectives then 
        print("DEBUG: No current objectives")
        return 
    end
    
    if not mainFrame then 
        print("DEBUG: No main frame")
        return 
    end
    
    local scrollFrame = mainFrame:FindFirstChild("ObjectivesScroll")
    if not scrollFrame then 
        print("DEBUG: No scroll frame")
        return 
    end
    
    print("DEBUG: Clearing existing objective frames")
    -- Clear existing objective frames
    for _, frame in pairs(objectiveFrames) do
        if frame and frame.Parent then
            frame:Destroy()
        end
    end
    objectiveFrames = {}
    
    print("DEBUG: Creating new objective frames")
    -- Create new objective frames
    local yOffset = 0
    for objectiveType, objectiveData in pairs(currentObjectives) do
        print("DEBUG: Creating frame for " .. objectiveType .. " - " .. objectiveData.current .. "/" .. objectiveData.target)
        local frame = createObjectiveFrame(objectiveData, objectiveType, scrollFrame)
        frame.LayoutOrder = yOffset
        objectiveFrames[objectiveType] = frame
        yOffset = yOffset + 1
    end
    
    -- Update scroll frame canvas size
    local layout = scrollFrame:FindFirstChild("UIListLayout")
    if layout then
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
        print("DEBUG: Updated canvas size to " .. layout.AbsoluteContentSize.Y)
    end
    
    print("DEBUG: Objectives display updated successfully")
end

-- Function to load objectives from server
local function loadObjectives()
    print("DEBUG: Loading objectives from server...")
    
    local success, objectives, lastReset = pcall(function()
        return getObjectivesEvent:InvokeServer()
    end)
    
    if success and objectives then
        print("DEBUG: Successfully received objectives from server:")
        for objType, objData in pairs(objectives) do
            print("  " .. objType .. ": " .. objData.current .. "/" .. objData.target .. " (completed: " .. tostring(objData.completed) .. ")")
        end
        
        currentObjectives = objectives
        updateObjectivesDisplay()
        print("DEBUG: Loaded daily objectives successfully")
    else
        warn("DEBUG: Failed to load daily objectives - Success: " .. tostring(success) .. ", Objectives: " .. tostring(objectives))
    end
end

-- Function to toggle GUI visibility
local function toggleGUI()
    if not mainFrame then return end
    
    isGUIVisible = not isGUIVisible
    
    if isGUIVisible then
        -- Refresh the display when opening the GUI (REAL-TIME like ListingsGUI)
        print("DEBUG: Opening GUI, refreshing objectives display IMMEDIATELY")
        loadObjectives() -- Force fresh data from server like ListingsGUI
        updateObjectivesDisplay()
        
        mainFrame.Visible = true
        -- Animate in with scale effect
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        
        local tween = TweenService:Create(
            mainFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {
                Size = UDim2.new(0, 350, 0, 250),
                Position = UDim2.new(0.5, -175, 0.5, -125)
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
    local existingGui = playerGui:FindFirstChild("DailyObjectivesGUI")
    if existingGui then
        existingGui:Destroy()
    end
    
    -- Create main ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DailyObjectivesGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Create main frame (centered on screen)
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "ObjectivesFrame"
    mainFrame.Size = UDim2.new(0, 350, 0, 250) -- Larger size for center display
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -125) -- Centered on screen
    mainFrame.BackgroundColor3 = BACKGROUND_COLOR
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false -- Start hidden
    mainFrame.Parent = screenGui
    
    -- Add corner radius (same as Daily Bonus)
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
    
    -- Add title (same style as Daily Bonus)
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -50, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Daily Objectives"
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
    
    -- Close button hover effects
    closeButton.MouseEnter:Connect(function()
        TweenService:Create(
            closeButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.1}
        ):Play()
    end)
    
    closeButton.MouseLeave:Connect(function()
        TweenService:Create(
            closeButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.2}
        ):Play()
    end)
    
    -- Create scroll frame for objectives
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ObjectivesScroll"
    scrollFrame.Size = UDim2.new(1, -20, 1, -60)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.Parent = mainFrame
    
    -- Create layout for objectives
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = scrollFrame
    
    return scrollFrame
end

-- Create toggle button (positioned next to Daily Bonus)
local function createToggleButton()
    toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ObjectivesToggle"
    toggleButton.Size = UDim2.new(0, 40, 0, 40) -- Same height as Daily Bonus
    toggleButton.Position = UDim2.new(0, 200, 1, -50) -- Next to Daily Bonus (180 + 10 gap + 10 padding)
    toggleButton.BackgroundColor3 = BACKGROUND_COLOR
    toggleButton.BackgroundTransparency = 0.2
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = "📋"
    toggleButton.TextColor3 = TITLE_COLOR
    toggleButton.TextSize = 20
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Parent = screenGui
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = toggleButton
    
    -- Hover effects (similar to Daily Bonus style)
    toggleButton.MouseEnter:Connect(function()
        TweenService:Create(
            toggleButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.1}
        ):Play()
    end)
    
    toggleButton.MouseLeave:Connect(function()
        TweenService:Create(
            toggleButton,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {BackgroundTransparency = 0.2}
        ):Play()
    end)
    
    -- Click effects
    toggleButton.MouseButton1Down:Connect(function()
        TweenService:Create(
            toggleButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(0, 201, 1, -49)}
        ):Play()
    end)
    
    toggleButton.MouseButton1Up:Connect(function()
        TweenService:Create(
            toggleButton,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 40, 0, 40), Position = UDim2.new(0, 200, 1, -50)}
        ):Play()
    end)
    
    toggleButton.MouseButton1Click:Connect(function()
        toggleGUI()
    end)
    
    return toggleButton
end

-- Initialize GUI
local function initializeGUI()
    createGUI()
    createToggleButton()
    loadObjectives()
end

-- Connect to objectives updated event for IMMEDIATE real-time updates
objectivesUpdatedEvent.OnClientEvent:Connect(function(objectives)
    print("DEBUG: Client received REAL-TIME objectives update:")
    for objType, objData in pairs(objectives) do
        print("  " .. objType .. ": " .. objData.current .. "/" .. objData.target .. " (completed: " .. tostring(objData.completed) .. ")")
    end
    currentObjectives = objectives
    
    -- IMMEDIATE update - no delay
    updateObjectivesDisplay()
    print("DEBUG: Client objectives display updated IMMEDIATELY")
end)

-- Function to start real-time monitoring (like ListingsGUI)
local function startRealTimeUpdates()
    -- Periodic refresh every 10 seconds (like ListingsGUI) when GUI is visible
    task.spawn(function()
        while true do
            task.wait(10) -- More frequent updates like ListingsGUI
            if isGUIVisible and currentObjectives then
                print("DEBUG: Periodic refresh - requesting latest objectives from server")
                loadObjectives()
            end
        end
    end)
    
    -- Also refresh every 30 seconds regardless of GUI visibility for background updates
    task.spawn(function()
        while true do
            task.wait(30)
            if currentObjectives then
                print("DEBUG: Background refresh - requesting latest objectives from server")
                loadObjectives()
            end
        end
    end)
end

-- Initialize when player joins
task.wait(2) -- Wait for other systems to load
initializeGUI()
-- Start real-time updates (like ListingsGUI)
startRealTimeUpdates()

print("Daily Objectives GUI initialized with REAL-TIME updates") 