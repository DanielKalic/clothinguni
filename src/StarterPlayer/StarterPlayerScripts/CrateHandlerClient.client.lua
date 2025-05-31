-- Crate Handler Client Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Connect to events
local notificationEvent = ReplicatedStorage:WaitForChild("NotificationEvent")

-- Function to display a notification
local function showNotification(message, color)
    color = color or Color3.fromRGB(60, 200, 60)
    
    -- Create notification frame if it doesn't exist in PlayerGui
    local notifications = playerGui:FindFirstChild("Notifications")
    if not notifications then
        notifications = Instance.new("ScreenGui")
        notifications.Name = "Notifications"
        notifications.Parent = playerGui
    end
    
    -- Create notification frame
    local notification = Instance.new("Frame")
    notification.Name = "Notification"
    notification.Size = UDim2.new(0, 300, 0, 60)
    notification.Position = UDim2.new(0.5, 0, 0, -70) -- Start off-screen, centered
    notification.AnchorPoint = Vector2.new(0.5, 0.5)
    notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    notification.BorderSizePixel = 0
    notification.Parent = notifications
    
    -- Add rounded corners
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = notification
    
    -- Add text label for message
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 1, -20)
    textLabel.Position = UDim2.new(0, 10, 0, 10)
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.GothamSemibold
    textLabel.TextColor3 = color
    textLabel.TextSize = 16
    textLabel.Text = message
    textLabel.TextWrapped = true
    textLabel.Parent = notification
    
    -- Create animations for notification
    local showTween = TweenService:Create(
        notification,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0.1, 30)}
    )
    
    local hideTween = TweenService:Create(
        notification,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(0.5, 0, 0, -70)}
    )
    
    -- Show notification
    showTween:Play()
    
    -- Hide after 4 seconds
    task.delay(4, function()
        hideTween:Play()
        hideTween.Completed:Connect(function()
            notification:Destroy()
        end)
    end)
end

-- Connect to notification event
notificationEvent.OnClientEvent:Connect(function(message, color)
    print("DEBUG: CrateHandlerClient received notification:", message)
    showNotification(message, color)
end)

print("Crate Handler Client initialized") 