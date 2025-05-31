-- Simplified BoomBox Handler
print("=== SIMPLE BOOMBOX: Starting ===")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Function to check for existing BoomBox tools in character
local function checkExistingTools(character, playerName)
    print("SIMPLE BOOMBOX: Checking existing tools in character for:", playerName)
    for _, child in pairs(character:GetChildren()) do
        print("SIMPLE BOOMBOX: Found child in character:", child.Name, child.ClassName)
        if child:IsA("Tool") and child.Name == "BoomBox" then
            print("SIMPLE BOOMBOX: Found existing BoomBox tool!")
            -- Set up the tool
            local event = child:WaitForChild("BoomBoxEvent", 5)
            if event then
                print("SIMPLE BOOMBOX: Found BoomBoxEvent in existing tool, connecting...")
                
                event.OnServerEvent:Connect(function(plr, action, audioId)
                    print("SIMPLE BOOMBOX: Event received from existing tool!")
                    print("  Player:", plr.Name)
                    print("  Action:", action)
                    print("  Audio ID:", audioId)
                    
                    if action == "PlayMusic" then
                        local handle = child:FindFirstChild("Handle")
                        if handle then
                            local sound = handle:FindFirstChild("Sound")
                            if sound then
                                sound:Stop()
                                sound.SoundId = "rbxassetid://" .. tostring(audioId)
                                sound.Volume = 0.5
                                sound.Looped = true
                                sound:Play()
                                print("SIMPLE BOOMBOX: Playing audio from existing tool:", audioId)
                            else
                                print("SIMPLE BOOMBOX: No Sound found in Handle (existing tool)")
                            end
                        else
                            print("SIMPLE BOOMBOX: No Handle found in BoomBox (existing tool)")
                        end
                    end
                end)
            else
                print("SIMPLE BOOMBOX: No BoomBoxEvent found in existing tool")
            end
        end
    end
end

-- Monitor when players equip tools
Players.PlayerAdded:Connect(function(player)
    print("SIMPLE BOOMBOX: Player joined:", player.Name)
    
    player.CharacterAdded:Connect(function(character)
        print("SIMPLE BOOMBOX: Character spawned for:", player.Name)
        
        -- Check for existing tools immediately
        task.wait(1) -- Wait a moment for tools to load
        checkExistingTools(character, player.Name)
        
        character.ChildAdded:Connect(function(child)
            print("SIMPLE BOOMBOX: Child added to character:", child.Name, child.ClassName)
            
            if child:IsA("Tool") and child.Name == "BoomBox" then
                print("SIMPLE BOOMBOX: BoomBox tool detected!")
                
                -- Wait for BoomBoxEvent
                local event = child:WaitForChild("BoomBoxEvent", 5)
                if event then
                    print("SIMPLE BOOMBOX: Found BoomBoxEvent, connecting...")
                    
                    event.OnServerEvent:Connect(function(plr, action, audioId)
                        print("SIMPLE BOOMBOX: Event received!")
                        print("  Player:", plr.Name)
                        print("  Action:", action)
                        print("  Audio ID:", audioId)
                        
                        if action == "PlayMusic" then
                            local handle = child:FindFirstChild("Handle")
                            if handle then
                                local sound = handle:FindFirstChild("Sound")
                                if sound then
                                    sound:Stop()
                                    sound.SoundId = "rbxassetid://" .. tostring(audioId)
                                    sound.Volume = 0.5
                                    sound.Looped = true
                                    sound:Play()
                                    print("SIMPLE BOOMBOX: Playing audio:", audioId)
                                else
                                    print("SIMPLE BOOMBOX: No Sound found in Handle")
                                end
                            else
                                print("SIMPLE BOOMBOX: No Handle found in BoomBox")
                            end
                        end
                    end)
                else
                    print("SIMPLE BOOMBOX: No BoomBoxEvent found in tool")
                end
            end
        end)
    end)
end)

-- Handle existing players
for _, player in pairs(Players:GetPlayers()) do
    print("SIMPLE BOOMBOX: Setting up existing player:", player.Name)
    if player.Character then
        print("SIMPLE BOOMBOX: Player has character, setting up...")
        
        -- Check existing tools immediately
        checkExistingTools(player.Character, player.Name)
        
        -- Set up character monitoring for existing character
        player.Character.ChildAdded:Connect(function(child)
            print("SIMPLE BOOMBOX: Child added to existing character:", child.Name, child.ClassName)
            
            if child:IsA("Tool") and child.Name == "BoomBox" then
                print("SIMPLE BOOMBOX: BoomBox tool detected on existing character!")
                
                -- Wait for BoomBoxEvent
                local event = child:WaitForChild("BoomBoxEvent", 5)
                if event then
                    print("SIMPLE BOOMBOX: Found BoomBoxEvent on existing character, connecting...")
                    
                    event.OnServerEvent:Connect(function(plr, action, audioId)
                        print("SIMPLE BOOMBOX: Event received from existing character!")
                        print("  Player:", plr.Name)
                        print("  Action:", action)
                        print("  Audio ID:", audioId)
                        
                        if action == "PlayMusic" then
                            local handle = child:FindFirstChild("Handle")
                            if handle then
                                local sound = handle:FindFirstChild("Sound")
                                if sound then
                                    sound:Stop()
                                    sound.SoundId = "rbxassetid://" .. tostring(audioId)
                                    sound.Volume = 0.5
                                    sound.Looped = true
                                    sound:Play()
                                    print("SIMPLE BOOMBOX: Playing audio from existing character:", audioId)
                                else
                                    print("SIMPLE BOOMBOX: No Sound found in Handle (existing character)")
                                end
                            else
                                print("SIMPLE BOOMBOX: No Handle found in BoomBox (existing character)")
                            end
                        end
                    end)
                else
                    print("SIMPLE BOOMBOX: No BoomBoxEvent found in tool (existing character)")
                end
            end
        end)
    end
end

-- Also add a periodic check to see if BoomBox tools exist
task.spawn(function()
    while true do
        task.wait(5) -- Check every 5 seconds
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character then
                local boombox = player.Character:FindFirstChild("BoomBox")
                if boombox then
                    print("SIMPLE BOOMBOX: Periodic check found BoomBox in", player.Name, "'s character")
                end
            end
        end
    end
end)

print("=== SIMPLE BOOMBOX: Setup complete ===") 