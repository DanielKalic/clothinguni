-- VIPRunSystem.client.lua
-- Hidden "Hold Shift to Run" feature for VIP gamepass owners only

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Speed settings
local NORMAL_WALKSPEED = 16
local RUN_WALKSPEED = 30

-- State tracking
local isRunning = false
local hasVIPGamepass = false
local currentCharacter = nil
local humanoid = nil
local vipCheckEvent = nil

-- Debug function (always shows for now to help debug)
local function debugPrint(message)
    print("[VIPRunSystem] " .. message)
end

-- Wait for and get the VIP check event
local function getVIPCheckEvent()
    debugPrint("Looking for VIPCheckEvent...")
    
    -- Wait up to 10 seconds for the event to be created by server
    local timeWaited = 0
    while not vipCheckEvent and timeWaited < 10 do
        vipCheckEvent = ReplicatedStorage:FindFirstChild("VIPCheckEvent")
        if not vipCheckEvent then
            task.wait(0.5)
            timeWaited = timeWaited + 0.5
            debugPrint("Still waiting for VIPCheckEvent... (" .. timeWaited .. "s)")
        end
    end
    
    if vipCheckEvent then
        debugPrint("Found VIPCheckEvent!")
        return true
    else
        warn("[VIPRunSystem] VIPCheckEvent not found after 10 seconds!")
        return false
    end
end

-- Check VIP status via server
local function checkVIPGamepass()
    if not vipCheckEvent then
        debugPrint("VIPCheckEvent not available, cannot check VIP status")
        return
    end
    
    debugPrint("Checking VIP gamepass ownership via server...")
    
    local success, result = pcall(function()
        return vipCheckEvent:InvokeServer()
    end)
    
    if success then
        hasVIPGamepass = result
        debugPrint("VIP check successful - Has VIP: " .. tostring(hasVIPGamepass))
        
        -- If player just got VIP and they're holding shift, start running
        if hasVIPGamepass and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
            startRunning()
        end
    else
        warn("[VIPRunSystem] Failed to check VIP gamepass ownership via server: " .. tostring(result))
        hasVIPGamepass = false
    end
end

-- Set up character references
local function setupCharacter()
    currentCharacter = player.Character
    if currentCharacter then
        humanoid = currentCharacter:WaitForChild("Humanoid", 5)
        if humanoid then
            -- Reset to normal speed when character spawns
            humanoid.WalkSpeed = NORMAL_WALKSPEED
            debugPrint("Character setup complete - WalkSpeed reset to " .. NORMAL_WALKSPEED)
        else
            warn("[VIPRunSystem] Failed to find Humanoid")
        end
    end
end

-- Start running
local function startRunning()
    if not hasVIPGamepass then
        debugPrint("Cannot run - No VIP gamepass (hasVIPGamepass = " .. tostring(hasVIPGamepass) .. ")")
        return
    end
    
    if not humanoid then
        debugPrint("Cannot run - No humanoid")
        return
    end
    
    if isRunning then
        return -- Already running
    end
    
    isRunning = true
    humanoid.WalkSpeed = RUN_WALKSPEED
    debugPrint("Started running - WalkSpeed set to " .. RUN_WALKSPEED)
end

-- Stop running
local function stopRunning()
    if not humanoid then
        return
    end
    
    if not isRunning then
        return -- Not running
    end
    
    isRunning = false
    humanoid.WalkSpeed = NORMAL_WALKSPEED
    debugPrint("Stopped running - WalkSpeed set to " .. NORMAL_WALKSPEED)
end

-- Handle input
local function onInputBegan(input, gameProcessed)
    -- Don't process if the input is being used by GUI or chat
    if gameProcessed then return end
    
    -- Check for both shift keys AND handle shift lock mode
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        debugPrint("Shift pressed - attempting to start running (VIP: " .. tostring(hasVIPGamepass) .. ")")
        startRunning()
    end
end

local function onInputEnded(input, gameProcessed)
    -- Don't process if the input was being used by GUI or chat
    if gameProcessed then return end
    
    -- Check for both shift keys
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        debugPrint("Shift released - stopping running")
        stopRunning()
    end
end

-- Alternative method for shift lock compatibility
local function onInputChanged(input, gameProcessed)
    -- This catches input state changes that might be missed when shift lock is on
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        if input.UserInputState == Enum.UserInputState.Begin then
            debugPrint("Shift state changed to pressed (shift lock compatible)")
            startRunning()
        elseif input.UserInputState == Enum.UserInputState.End then
            debugPrint("Shift state changed to released (shift lock compatible)")
            stopRunning()
        end
    end
end

-- Handle character respawning
local function onCharacterAdded(character)
    debugPrint("Character added - setting up character")
    setupCharacter()
    
    -- Re-check VIP status when character spawns (in case it changed)
    task.wait(2) -- Wait for character to fully load
    checkVIPGamepass()
end

-- Initialize system
local function initialize()
    debugPrint("Initializing VIP Run System...")
    
    -- Wait for VIPCheckEvent to be available
    if not getVIPCheckEvent() then
        warn("[VIPRunSystem] Cannot initialize - VIPCheckEvent not found")
        return
    end
    
    -- Set up current character if it exists
    if player.Character then
        setupCharacter()
    end
    
    -- Connect events (always connect, VIP check happens in the functions)
    player.CharacterAdded:Connect(onCharacterAdded)
    UserInputService.InputBegan:Connect(onInputBegan)
    UserInputService.InputEnded:Connect(onInputEnded)
    UserInputService.InputChanged:Connect(onInputChanged) -- For shift lock compatibility
    
    -- Monitor for character changes and shift lock state
    RunService.Heartbeat:Connect(function()
        if player.Character ~= currentCharacter then
            setupCharacter()
        end
        
        -- Additional shift lock compatibility: check if shift is held down
        if hasVIPGamepass and humanoid then
            local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
            
            if shiftHeld and not isRunning then
                debugPrint("Heartbeat detected shift held - starting run (shift lock compatibility)")
                startRunning()
            elseif not shiftHeld and isRunning then
                debugPrint("Heartbeat detected shift released - stopping run (shift lock compatibility)")
                stopRunning()
            end
        end
    end)
    
    -- Initial VIP check with delay to ensure player is fully loaded
    task.wait(3) -- Wait 3 seconds for player to fully load
    checkVIPGamepass()
    
    -- Check VIP gamepass periodically in case player purchases it during gameplay
    spawn(function()
        while true do
            task.wait(30) -- Check every 30 seconds
            checkVIPGamepass()
        end
    end)
    
    debugPrint("VIP Run System initialized successfully")
end

-- Start the system
spawn(initialize) -- Use spawn to avoid blocking other scripts 