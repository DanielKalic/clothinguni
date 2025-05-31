local Players = game:GetService("Players")

local function assignCollisionGroup(character)
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Player"
		end
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(assignCollisionGroup)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(assignCollisionGroup)
end)
