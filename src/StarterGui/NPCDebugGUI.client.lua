local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local debugCommandEvent = ReplicatedStorage:WaitForChild("NPCDebugCommand")

-- Create the GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NPCDebugGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Create the main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 250, 0, 150)
mainFrame.Position = UDim2.new(1, -260, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

-- Add rounded corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Add title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "NPC Debug Stats"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- Add stats text
local statsText = Instance.new("TextLabel")
statsText.Name = "StatsText"
statsText.Size = UDim2.new(1, -20, 1, -80)
statsText.Position = UDim2.new(0, 10, 0, 35)
statsText.BackgroundTransparency = 1
statsText.Text = "Loading stats..."
statsText.TextColor3 = Color3.fromRGB(200, 200, 200)
statsText.TextSize = 14
statsText.Font = Enum.Font.Gotham
statsText.TextXAlignment = Enum.TextXAlignment.Left
statsText.TextYAlignment = Enum.TextYAlignment.Top
statsText.Parent = mainFrame

-- Add refresh button
local refreshButton = Instance.new("TextButton")
refreshButton.Name = "RefreshButton"
refreshButton.Size = UDim2.new(0.45, 0, 0, 25)
refreshButton.Position = UDim2.new(0.025, 0, 1, -35)
refreshButton.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
refreshButton.Text = "Refresh"
refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshButton.TextSize = 14
refreshButton.Font = Enum.Font.GothamBold
refreshButton.Parent = mainFrame

-- Add cleanup button
local cleanupButton = Instance.new("TextButton")
cleanupButton.Name = "CleanupButton"
cleanupButton.Size = UDim2.new(0.45, 0, 0, 25)
cleanupButton.Position = UDim2.new(0.525, 0, 1, -35)
cleanupButton.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
cleanupButton.Text = "Force Cleanup"
cleanupButton.TextColor3 = Color3.fromRGB(255, 255, 255)
cleanupButton.TextSize = 14
cleanupButton.Font = Enum.Font.GothamBold
cleanupButton.Parent = mainFrame

-- Add rounded corners to buttons
local buttonCorner1 = Instance.new("UICorner")
buttonCorner1.CornerRadius = UDim.new(0, 6)
buttonCorner1.Parent = refreshButton

local buttonCorner2 = Instance.new("UICorner")
buttonCorner2.CornerRadius = UDim.new(0, 6)
buttonCorner2.Parent = cleanupButton

-- Add toggle button
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 40, 0, 40)
toggleButton.Position = UDim2.new(1, -50, 0, 10)
toggleButton.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
toggleButton.Text = "🔍"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 18
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Parent = screenGui

-- Add rounded corners to toggle button
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleButton

-- Handle toggle button click
local function toggleGUI()
    mainFrame.Visible = not mainFrame.Visible
    if mainFrame.Visible then
        debugCommandEvent:FireServer("getStats")
    end
end

toggleButton.MouseButton1Click:Connect(toggleGUI)

-- Handle refresh button click
refreshButton.MouseButton1Click:Connect(function()
    debugCommandEvent:FireServer("getStats")
end)

-- Handle cleanup button click
cleanupButton.MouseButton1Click:Connect(function()
    debugCommandEvent:FireServer("forceCleanup")
end)

-- Handle button hover effects
local function buttonHoverEffect(button)
    local originalColor = button.BackgroundColor3
    
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = Color3.fromRGB(
                math.min(originalColor.R * 255 + 20, 255),
                math.min(originalColor.G * 255 + 20, 255),
                math.min(originalColor.B * 255 + 20, 255)
            )
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            BackgroundColor3 = originalColor
        }):Play()
    end)
end

buttonHoverEffect(refreshButton)
buttonHoverEffect(cleanupButton)
buttonHoverEffect(toggleButton)

-- Handle server responses
debugCommandEvent.OnClientEvent:Connect(function(responseType, message)
    if responseType == "stats" then
        statsText.Text = message
    elseif responseType == "cleanup" then
        statsText.Text = message .. "\n\nRefreshing stats..."
        wait(1)
        debugCommandEvent:FireServer("getStats")
    end
end)

-- Auto-refresh stats every 30 seconds if GUI is visible
spawn(function()
    while wait(30) do
        if mainFrame.Visible then
            debugCommandEvent:FireServer("getStats")
        end
    end
end) 