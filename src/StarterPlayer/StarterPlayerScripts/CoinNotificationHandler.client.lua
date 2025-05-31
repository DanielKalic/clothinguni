-- Coin Notification Handler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for the coin notification event
local coinNotificationEvent = ReplicatedStorage:WaitForChild("CoinNotificationEvent")

-- Function to display coin notification
local function showCoinNotification(message, color)
    color = color or Color3.fromRGB(255, 215, 0) -- Default gold color for coins
    
    -- Create notification container if it doesn't exist
    local notifications = playerGui:FindFirstChild("CoinNotifications")
    if not notifications then
        notifications = Instance.new("ScreenGui")
        notifications.Name = "CoinNotifications"
        notifications.ResetOnSpawn = false
        notifications.Parent = playerGui
    end
    
    -- Create text label directly (no background frame)
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "CoinNotification"
    textLabel.Size = UDim2.new(0, 200, 0, 40)
    textLabel.Position = UDim2.new(0.5, 0, 0, -50) -- Start off-screen, centered
    textLabel.AnchorPoint = Vector2.new(0.5, 0.5) -- Center anchor point
    textLabel.BackgroundTransparency = 1 -- No background
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextColor3 = color
    textLabel.TextSize = 18
    textLabel.Text = message
    textLabel.TextWrapped = true
    textLabel.TextStrokeTransparency = 0.5 -- Add text stroke for better visibility
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.Parent = notifications
    
    -- Create animations for text label - adjusted for centered position
    local showTween = TweenService:Create(
        textLabel,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0.1, 30)} -- Upper middle, same as other notifications
    )
    
    local hideTween = TweenService:Create(
        textLabel,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {
            Position = UDim2.new(0.5, 0, 0, -50), -- Move up off screen
            TextTransparency = 1, -- Fade out text
            TextStrokeTransparency = 1 -- Fade out stroke
        }
    )
    
    -- Show notification
    showTween:Play()
    
    -- Hide after 3 seconds
    task.delay(3, function()
        hideTween:Play()
        hideTween.Completed:Connect(function()
            textLabel:Destroy()
        end)
    end)
end

-- Connect to coin notification event
coinNotificationEvent.OnClientEvent:Connect(function(message, color)
    showCoinNotification(message, color)
end)

print("Coin Notification Handler initialized") 