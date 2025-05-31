-- BoomBox Handler Server Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("=== BoomBox Handler: Server script starting ===")

-- Keep track of all BoomBox tools we've set up
local setupTools = {}

-- Function to handle BoomBox events for any BoomBox tool
local function setupBoomBoxTool(tool)
    print("BoomBox Handler: setupBoomBoxTool called with:", tool.Name, tool.ClassName)
    
    if tool.Name ~= "BoomBox" then 
        print("BoomBox Handler: Ignoring tool", tool.Name, "(not BoomBox)")
        return 
    end
    
    -- Check if we already set up this tool
    if setupTools[tool] then
        print("BoomBox Handler: Tool already set up, skipping")
        return
    end
    
    print("BoomBox Handler: Setting up BoomBox tool:", tool:GetFullName())
    
    local Handle = tool:WaitForChild("Handle", 5)
    if not Handle then
        warn("BoomBox Handler: No Handle found in BoomBox tool")
        return
    end
    print("BoomBox Handler: Found Handle")
    
    local Sound = Handle:WaitForChild("Sound", 5)
    if not Sound then
        warn("BoomBox Handler: No Sound found in Handle")
        return
    end
    print("BoomBox Handler: Found Sound")
    
    print("BoomBox Handler: Looking for BoomBoxEvent...")
    print("BoomBox Handler: Current children of tool:")
    for _, child in pairs(tool:GetChildren()) do
        print("  -", child.Name, "(" .. child.ClassName .. ")")
    end
    
    local BoomBoxEvent = tool:FindFirstChild("BoomBoxEvent")
    if not BoomBoxEvent then
        print("BoomBox Handler: BoomBoxEvent not found immediately, waiting...")
        BoomBoxEvent = tool:WaitForChild("BoomBoxEvent", 10)
    end
    
    if not BoomBoxEvent then
        warn("BoomBox Handler: No BoomBoxEvent found in BoomBox tool after waiting")
        return
    end
    print("BoomBox Handler: Found BoomBoxEvent:", BoomBoxEvent:GetFullName())
    
    -- Function to get the player who owns this tool
    local function getPlayer()
        return Players:GetPlayerFromCharacter(tool.Parent)
    end
    
    -- Function to play music
    local function playMusic(audioId)
        print("BoomBox Handler: playMusic called with audioId:", audioId)
        if audioId and audioId ~= "" then
            -- Stop current sound
            Sound:Stop()
            
            -- Set new sound ID with proper formatting
            local soundId = "rbxassetid://" .. tostring(audioId)
            Sound.SoundId = soundId
            Sound.Volume = 0.5
            Sound.Looped = true
            Sound.EmitterSize = 50 -- Make it audible from further away
            
            print("BoomBox Handler: Set sound properties, waiting before play...")
            -- Wait a moment for the sound to load, then play
            task.wait(0.1)
            Sound:Play()
            
            print("BoomBox Handler: Playing audio ID:", audioId, "Full ID:", soundId)
            print("BoomBox Handler: Sound IsPlaying:", Sound.IsPlaying)
            print("BoomBox Handler: Sound Volume:", Sound.Volume)
            print("BoomBox Handler: Sound Parent:", Sound.Parent and Sound.Parent:GetFullName())
        else
            -- Stop music if no ID provided
            Sound:Stop()
            Sound.SoundId = ""
            print("BoomBox Handler: Stopped playing music")
        end
    end
    
    -- Handle remote events
    print("BoomBox Handler: Connecting to BoomBoxEvent.OnServerEvent...")
    BoomBoxEvent.OnServerEvent:Connect(function(player, action, ...)
        print("BoomBox Handler: *** RECEIVED EVENT ***")
        print("BoomBox Handler: Player:", player.Name)
        print("BoomBox Handler: Action:", action)
        print("BoomBox Handler: Additional args:", ...)
        
        -- Verify the player owns this tool
        local toolOwner = getPlayer()
        print("BoomBox Handler: Tool owner:", toolOwner and toolOwner.Name or "nobody")
        print("BoomBox Handler: Tool parent:", tool.Parent and tool.Parent:GetFullName() or "no parent")
        
        if player ~= toolOwner then
            print("BoomBox Handler: Player", player.Name, "tried to control BoomBox owned by", toolOwner and toolOwner.Name or "nobody")
            return
        end
        
        print("BoomBox Handler: Player verified, processing action:", action)
        
        if action == "PlayMusic" then
            local audioId = ...
            print("BoomBox Handler: Playing music with ID:", audioId)
            playMusic(audioId)
        else
            print("BoomBox Handler: Unknown action:", action)
        end
    end)
    
    -- Stop music when tool is unequipped
    tool.Unequipped:Connect(function()
        print("BoomBox Handler: BoomBox unequipped, stopping music")
        Sound:Stop()
        Sound.SoundId = ""
    end)
    
    -- Mark this tool as set up
    setupTools[tool] = true
    
    print("BoomBox Handler: BoomBox tool setup complete for:", tool:GetFullName())
end

-- Monitor for BoomBox tools being added to characters
local function onCharacterAdded(character)
    print("BoomBox Handler: Character added:", character.Name)
    
    -- Check existing tools
    print("BoomBox Handler: Checking existing tools in character...")
    for _, tool in pairs(character:GetChildren()) do
        print("BoomBox Handler: Found child:", tool.Name, tool.ClassName)
        if tool:IsA("Tool") then
            print("BoomBox Handler: Found existing tool:", tool.Name)
            setupBoomBoxTool(tool)
        end
    end
    
    -- Monitor for new tools being added
    print("BoomBox Handler: Setting up ChildAdded listener for character:", character.Name)
    character.ChildAdded:Connect(function(child)
        print("BoomBox Handler: Child added to character:", child.Name, child.ClassName)
        if child:IsA("Tool") then
            print("BoomBox Handler: New tool added to character:", child.Name)
            setupBoomBoxTool(child)
        end
    end)
end

-- Monitor all players
Players.PlayerAdded:Connect(function(player)
    print("BoomBox Handler: Player added:", player.Name)
    player.CharacterAdded:Connect(onCharacterAdded)
    
    -- If character already exists
    if player.Character then
        print("BoomBox Handler: Player", player.Name, "already has character, setting up...")
        onCharacterAdded(player.Character)
    end
end)

-- Handle existing players
print("BoomBox Handler: Setting up existing players...")
for _, player in pairs(Players:GetPlayers()) do
    print("BoomBox Handler: Setting up existing player:", player.Name)
    player.CharacterAdded:Connect(onCharacterAdded)
    
    if player.Character then
        print("BoomBox Handler: Existing player", player.Name, "has character, setting up...")
        onCharacterAdded(player.Character)
    end
end

print("=== BoomBox Handler: Server script loaded and monitoring for BoomBox tools! ===") 