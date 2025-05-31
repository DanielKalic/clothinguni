-- BonusTimerDisplay.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for the remote event
local updateBonusTimerEvent = ReplicatedStorage:WaitForChild("UpdateBonusTimerEvent")

-- Create the GUI
local timerGui = Instance.new("ScreenGui")
timerGui.Name = "BonusTimerGui"
timerGui.ResetOnSpawn = false
timerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
timerGui.Parent = playerGui

-- Create main frame
local timerFrame = Instance.new("Frame")
timerFrame.Name = "TimerFrame"
timerFrame.Size = UDim2.new(0, 180, 0, 40)
timerFrame.Position = UDim2.new(0, 10, 1, -50)
timerFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
timerFrame.BackgroundTransparency = 0.2
timerFrame.BorderSizePixel = 0
timerFrame.Parent = timerGui

-- Add corner radius
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = timerFrame

-- Add title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0, 20)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Daily Bonus"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = timerFrame

-- Add timer label
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(1, 0, 0, 20)
timerLabel.Position = UDim2.new(0, 0, 0, 20)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "Checking..."
timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
timerLabel.TextSize = 14
timerLabel.Font = Enum.Font.GothamSemibold
timerLabel.Parent = timerFrame

-- Create a remote function to request timer data immediately
local requestTimerDataFunc = ReplicatedStorage:FindFirstChild("RequestTimerDataFunc")
if not requestTimerDataFunc then
    requestTimerDataFunc = Instance.new("RemoteFunction")
    requestTimerDataFunc.Name = "RequestTimerDataFunc"
    requestTimerDataFunc.Parent = ReplicatedStorage
end

-- Format time as HH:MM:SS
local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Variables to track timer state
local timeLeft = 86400 -- Default to 24 hours until we get real data
local isActive = true
local lastUpdateTime = os.time()
local dataReceived = false

-- Update timer display
local function updateDisplay()
    -- If we haven't received data yet, show loading state
    if not dataReceived then
        timerLabel.Text = "Checking..."
        timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        return
    end
    
    if timeLeft <= 0 then
        timerLabel.Text = "Ready to Claim!"
        timerLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        
        -- Add a pulsing animation
        local function pulse()
            if not isActive then return end
            
            local growTween = TweenService:Create(
                timerFrame,
                TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 190, 0, 45)}
            )
            
            local shrinkTween = TweenService:Create(
                timerFrame,
                TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
                {Size = UDim2.new(0, 180, 0, 40)}
            )
            
            growTween:Play()
            growTween.Completed:Connect(function()
                if isActive then
                    shrinkTween:Play()
                    shrinkTween.Completed:Connect(function()
                        if isActive then
                            pulse()
                        end
                    end)
                end
            end)
        end
        
        pulse()
    else
        timerLabel.Text = formatTime(timeLeft)
        timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

-- Listen for timer updates from server
updateBonusTimerEvent.OnClientEvent:Connect(function(secondsLeft)
    timeLeft = secondsLeft
    lastUpdateTime = os.time()
    isActive = true
    dataReceived = true
    updateDisplay()
end)

-- Count down the timer locally
spawn(function()
    while wait(1) do
        if isActive and timeLeft > 0 and dataReceived then
            local currentTime = os.time()
            local elapsed = currentTime - lastUpdateTime
            lastUpdateTime = currentTime
            
            timeLeft = math.max(0, timeLeft - elapsed)
            updateDisplay()
        end
    end
end)

-- Try to get initial timer data directly
spawn(function()
    -- Wait a short time for leaderstats to be ready
    wait(1)
    
    -- Request timer data from the server
    local success, result = pcall(function()
        return requestTimerDataFunc:InvokeServer()
    end)
    
    if success and result then
        timeLeft = result
        lastUpdateTime = os.time()
        dataReceived = true
        updateDisplay()
    else
        -- If direct request fails, wait for the server to send an update
        -- The server should be sending updates shortly after player joins
        wait(2)
        if not dataReceived then
            -- After 2 more seconds, show a better message if still no data
            timerLabel.Text = "Waiting for server..."
        end
    end
end)

-- Initial display
updateDisplay() 