local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local leaderstats = player:WaitForChild("leaderstats")
local xp = leaderstats:WaitForChild("XP")
local level = leaderstats:WaitForChild("Level")
local progressBarContainer = script.Parent
local foreground = progressBarContainer:WaitForChild("Foreground")
local levelLabel = progressBarContainer:FindFirstChild("LevelLabel")

-- Flag to determine if this is the initial load
local isInitialLoad = true
local initialLoadTime = tick()
local INITIAL_LOAD_GRACE_PERIOD = 5  -- 5 seconds grace period to ignore initial XP changes

-- Store the initial XP value when the UI first loads
local initialXPValue = xp.Value

local function xpRequiredForLevel(lvl)
	return lvl * 100
end

local function updateProgressBar()
	local reqXP = xpRequiredForLevel(level.Value)
	local percent = xp.Value / reqXP
	percent = math.clamp(percent, 0, 1)
	foreground.Size = UDim2.new(percent, 0, 1, 0)
	if levelLabel then
		levelLabel.Text = "Level " .. tostring(level.Value)
	end
end

-- Initialize progress bar with current values
updateProgressBar()
local previousXP = xp.Value

-- Wait for the game to fully load before considering XP changes as actual gains
wait(3)
isInitialLoad = false

xp.Changed:Connect(function(newXP)
	updateProgressBar()
	local diff = newXP - previousXP
	if diff > 0 and not isInitialLoad then
		-- Skip any XP notifications during the initial grace period after joining
		if tick() - initialLoadTime < INITIAL_LOAD_GRACE_PERIOD then
			previousXP = newXP
			return
		end
		
		local xpLabel = Instance.new("TextLabel")
		xpLabel.BackgroundTransparency = 1
		xpLabel.Text = "+" .. tostring(diff) .. " XP"
		xpLabel.TextColor3 = Color3.new(0, 1, 0)
		xpLabel.Font = Enum.Font.SourceSansBold
		xpLabel.TextScaled = true
		xpLabel.Size = UDim2.new(0, 200, 0, 50)
		xpLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		xpLabel.Position = UDim2.new(0.5, 0, 0.2, 0)
		xpLabel.Parent = progressBarContainer

		local tweenInfo = TweenService:Create(xpLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
		local fadeOut = TweenService:Create(xpLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 1})
		xpLabel.TextTransparency = 1
		tweenInfo:Play()
		tweenInfo.Completed:Connect(function()
			fadeOut:Play()
		end)
		fadeOut.Completed:Connect(function()
			xpLabel:Destroy()
		end)
	end
	previousXP = newXP
end)

level.Changed:Connect(function()
	updateProgressBar()
end)
