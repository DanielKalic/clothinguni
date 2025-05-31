-- Test Script to verify server scripts are working
print("=== TEST SCRIPT: Server scripts are working! ===")

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    print("TEST SCRIPT: Player joined:", player.Name)
end)

for _, player in pairs(Players:GetPlayers()) do
    print("TEST SCRIPT: Existing player:", player.Name)
end

print("=== TEST SCRIPT: Setup complete ===") 