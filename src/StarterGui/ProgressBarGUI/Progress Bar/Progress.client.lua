local Players = game:GetService("Players")
local player = Players.LocalPlayer
local leaderstats = player:WaitForChild("leaderstats")
local xp = leaderstats:WaitForChild("XP")
local level = leaderstats:WaitForChild("Level")
local progressBar = script.Parent
local foreground = progressBar:WaitForChild("Foreground")
local levelLabel = progressBar:FindFirstChild("LevelLabel")

local function updateProgress()
	local requiredXP = level.Value * 100
	local percent = xp.Value / requiredXP
	percent = math.clamp(percent, 0, 1)
	foreground.Size = UDim2.new(percent, 0, 1, 0)
	if levelLabel then
		levelLabel.Text = "Level " .. tostring(level.Value)
	end
end

xp.Changed:Connect(updateProgress)
level.Changed:Connect(updateProgress)
updateProgress()
