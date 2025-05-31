-- Pet Command Output Client Script
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Create the command output GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetCommandOutput"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local outputFrame = Instance.new("Frame")
outputFrame.Name = "OutputFrame"
outputFrame.Size = UDim2.new(0, 400, 0, 50)
outputFrame.Position = UDim2.new(0.5, -200, 0, -60)
outputFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
outputFrame.BorderSizePixel = 0
outputFrame.Visible = false
outputFrame.Parent = screenGui

-- Add rounded corners
local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 8)
cornerRadius.Parent = outputFrame

-- Add text output label
local outputText = Instance.new("TextLabel")
outputText.Name = "OutputText"
outputText.Size = UDim2.new(1, -20, 1, 0)
outputText.Position = UDim2.new(0, 10, 0, 0)
outputText.BackgroundTransparency = 1
outputText.Text = ""
outputText.TextColor3 = Color3.fromRGB(255, 255, 255)
outputText.TextSize = 16
outputText.Font = Enum.Font.GothamSemibold
outputText.TextWrapped = true
outputText.TextXAlignment = Enum.TextXAlignment.Left
outputText.Parent = outputFrame

-- Watch for command attributes
local lastCommandTime = 0

while true do
    -- Check if there's a new command
    local currentCommandTime = player:GetAttribute("LastPetCommandTime") or 0
    if currentCommandTime > lastCommandTime then
        lastCommandTime = currentCommandTime
        
        -- Show the output
        local commandOutput = player:GetAttribute("LastPetCommand") or "No command output"
        outputText.Text = commandOutput
        
        -- Animate the frame in
        outputFrame.Visible = true
        outputFrame.Position = UDim2.new(0.5, -200, 0, -60)
        
        local tweenIn = TweenService:Create(
            outputFrame,
            TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, -200, 0, 20)}
        )
        
        tweenIn:Play()
        
        -- Wait and then animate out
        task.delay(4, function()
            local tweenOut = TweenService:Create(
                outputFrame,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Position = UDim2.new(0.5, -200, 0, -60)}
            )
            
            tweenOut:Play()
            
            tweenOut.Completed:Connect(function()
                outputFrame.Visible = false
            end)
        end)
    end
    
    task.wait(0.1)
end 