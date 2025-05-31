-- Pet Follow Handler
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Load the ProfileStore Pet Handler
local ProfileStorePetHandler = require(ReplicatedStorage:WaitForChild("ProfileStorePetHandler"))

-- Constants for pet following
local FOLLOW_DISTANCE = 5 -- Base distance from player
local FOLLOW_HEIGHT = 1.1 -- Height offset above ground
local FOLLOW_SPEED = 3 -- Movement speed multiplier
local UPDATE_INTERVAL = 0.02 -- How often to update pet positions (reduced significantly for near-continuous updates)
local DEBUG_MODE = false -- Set to false to reduce spam
local EQUIP_DEBUG = false -- Set to false to clean up output
local RAY_DISTANCE = 50 -- Maximum distance to cast ray down to find ground
local DEFAULT_HEIGHT = 3 -- Default height if no ground is found
local PREDICTION_FACTOR = 0.7 -- How much to predict player's movement (0-1)

-- Table to store active pet models
local activePets = {}

-- Store any active tweens to prevent interruption
local activeTweens = {}

-- Function to find ground position below a given world position
local function findGroundPosition(position, characterToIgnore, petToIgnore)
    -- Create a ray starting from the position and going downward
    local rayOrigin = position + Vector3.new(0, 2, 0) -- Start slightly above to ensure we're not already inside something
    local rayDirection = Vector3.new(0, -RAY_DISTANCE, 0) -- Cast ray downward
    local ray = Ray.new(rayOrigin, rayDirection)
    
    -- Cast the ray and get the hit position
    local ignoreList = {}
    
    -- Add the character to ignore list if provided
    if characterToIgnore then
        table.insert(ignoreList, characterToIgnore)
    end
    
    -- Add the pet to ignore list if provided
    if petToIgnore then
        table.insert(ignoreList, petToIgnore)
    end
    
    local hit, hitPosition, hitNormal = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
    
    if hit then
        -- Found ground, return position slightly above it
        if DEBUG_MODE then
            print("Found ground at Y: " .. hitPosition.Y)
        end
        return Vector3.new(position.X, hitPosition.Y + FOLLOW_HEIGHT, position.Z), hit
    else
        -- No ground found, use a default height
        if DEBUG_MODE then
            print("No ground found below position, using default height")
        end
        return Vector3.new(position.X, position.Y - DEFAULT_HEIGHT, position.Z), nil
    end
end

-- Get or create remote events for equipping pets
local equipPetEvent = ReplicatedStorage:FindFirstChild("EquipPetEvent")
if not equipPetEvent then
    equipPetEvent = Instance.new("RemoteFunction")
    equipPetEvent.Name = "EquipPetEvent"
    equipPetEvent.Parent = ReplicatedStorage
end

local unequipPetEvent = ReplicatedStorage:FindFirstChild("UnequipPetEvent")
if not unequipPetEvent then
    unequipPetEvent = Instance.new("RemoteFunction")
    unequipPetEvent.Name = "UnequipPetEvent"
    unequipPetEvent.Parent = ReplicatedStorage
end

local getEquippedPetsEvent = ReplicatedStorage:FindFirstChild("GetEquippedPetsEvent")
if not getEquippedPetsEvent then
    getEquippedPetsEvent = Instance.new("RemoteFunction")
    getEquippedPetsEvent.Name = "GetEquippedPetsEvent"
    getEquippedPetsEvent.Parent = ReplicatedStorage
end

-- Create a pet model and set it up to follow the player
local function createPetModel(player, petName, rarity, slotNumber)
    -- Try to find pet model in ReplicatedStorage
    local petFolder = ReplicatedStorage:FindFirstChild("Pets")
    if not petFolder then
        warn("Pets folder not found in ReplicatedStorage")
        return nil
    end
    
    local rarityFolder = petFolder:FindFirstChild(rarity)
    if not rarityFolder then
        warn("Rarity folder not found: " .. rarity)
        return nil
    end
    
    local petModel = rarityFolder:FindFirstChild(petName)
    if not petModel then
        warn("Pet model not found: " .. petName)
        return nil
    end
    
    -- Before creating a new pet, clean up any existing pets for this player in this slot
    local cleanupName = player.Name .. "_Pet_" .. slotNumber
    
    -- Clean up active pets tracking table
    if activePets[player.UserId] and activePets[player.UserId][slotNumber] then
        local existingPet = activePets[player.UserId][slotNumber]
        if existingPet and existingPet.Parent then
            existingPet:Destroy()
        end
        activePets[player.UserId][slotNumber] = nil
    end
    
    -- Clean up workspace
    for _, object in pairs(workspace:GetChildren()) do
        if object.Name == cleanupName then
            object:Destroy()
        end
    end
    
    -- Clone the pet model
    local petInstance = petModel:Clone()
    
    -- Necessary attributes
    local offsetAngle = (slotNumber - 1) * 120 -- 120 degrees between pets
    local offsetX = math.sin(math.rad(offsetAngle)) * FOLLOW_DISTANCE
    local offsetZ = math.cos(math.rad(offsetAngle)) * FOLLOW_DISTANCE

    -- Set pet name
    petInstance.Name = cleanupName
    
    -- Anchor ALL parts to prevent physics issues and ensure they're non-collidable
    if petInstance:IsA("BasePart") then
        if DEBUG_MODE then
            print("Anchoring part: " .. petInstance.Name)
        end
        petInstance.Anchored = true
        petInstance.CanCollide = false  -- Make sure base part cannot collide
    elseif petInstance:IsA("Model") then
        -- Anchor all parts in the model
        for _, part in pairs(petInstance:GetDescendants()) do
            if part:IsA("BasePart") then
                if DEBUG_MODE then
                    print("Anchoring part in model: " .. part.Name)
                end
                part.Anchored = true
                
                -- Disable collisions between pet parts and other objects
                part.CanCollide = false
            end
        end
        
        -- Get or set the PrimaryPart
        if not petInstance.PrimaryPart then
            local mainPart = petInstance:FindFirstChildWhichIsA("BasePart")
            if mainPart then
                petInstance.PrimaryPart = mainPart
                mainPart.CanCollide = false  -- Ensure primary part is non-collidable
                if DEBUG_MODE then
                    print("Set PrimaryPart to: " .. mainPart.Name)
                end
            end
        elseif petInstance.PrimaryPart then
            petInstance.PrimaryPart.CanCollide = false  -- Ensure primary part is non-collidable
        end
    end
    
    -- Set attributes
    petInstance:SetAttribute("OffsetX", offsetX)
    petInstance:SetAttribute("OffsetZ", offsetZ)
    petInstance:SetAttribute("SlotNumber", slotNumber)
    petInstance:SetAttribute("OwnerName", player.Name)
    
    -- Place pet at player's position initially
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = player.Character.HumanoidRootPart
        
        -- Calculate initial position in air
        local airPosition = rootPart.Position + 
            (rootPart.CFrame.RightVector * offsetX) + 
            (rootPart.CFrame.LookVector * offsetZ)
        
        -- Find ground below this position
        local groundPosition, groundPart = findGroundPosition(airPosition, player.Character, petInstance)
        
        -- Use ground position to place pet initially
        if petInstance:IsA("BasePart") then
            petInstance.CFrame = CFrame.new(groundPosition)
        elseif petInstance:IsA("Model") and petInstance.PrimaryPart then
            petInstance:SetPrimaryPartCFrame(CFrame.new(groundPosition))
        end
    end
    
    -- Parent to workspace
    petInstance.Parent = workspace
    
    -- Store in active pets
    if not activePets[player.UserId] then
        activePets[player.UserId] = {}
    end
    activePets[player.UserId][slotNumber] = petInstance
    
    if DEBUG_MODE then
        print("Created pet: " .. petInstance.Name .. " for player: " .. player.Name)
    end
    
    return petInstance
end

-- Update pet positions to follow their players
local function updatePetPositions()
    for userId, playerPets in pairs(activePets) do
        local player = Players:GetPlayerByUserId(userId)
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local character = player.Character
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            
            if DEBUG_MODE then
                print("Updating pets for: " .. player.Name)
            end
            
            -- Get the player's velocity for prediction
            local playerVelocity = rootPart.Velocity
            local playerSpeed = playerVelocity.Magnitude
            local isMoving = playerSpeed > 0.5 -- Check if player is meaningfully moving
            
            -- Calculate a prediction offset based on velocity
            local predictionOffset = Vector3.new(0, 0, 0)
            if isMoving then
                predictionOffset = playerVelocity.Unit * playerSpeed * PREDICTION_FACTOR * UPDATE_INTERVAL
            end
            
            for slotNumber, petModel in pairs(playerPets) do
                if petModel and petModel.Parent then
                    local slotKey = userId .. "_" .. slotNumber
                    
                    -- Find the main part to position
                    local mainPart, petRoot
                    if petModel:IsA("BasePart") then
                        mainPart = petModel
                        petRoot = petModel
                        
                        -- Ensure this part is non-collidable
                        mainPart.CanCollide = false
                    elseif petModel:IsA("Model") and petModel.PrimaryPart then
                        mainPart = petModel.PrimaryPart
                        petRoot = petModel
                        
                        -- Ensure primary part is non-collidable
                        mainPart.CanCollide = false
                    else
                        -- Try to find a part
                        mainPart = petModel:FindFirstChildWhichIsA("BasePart")
                        if not mainPart then
                            if DEBUG_MODE then
                                warn("No main part found for pet: " .. petModel.Name)
                            end
                            continue -- Skip if no usable part
                        end
                        petRoot = petModel
                        
                        -- Ensure this part is non-collidable
                        mainPart.CanCollide = false
                    end
                    
                    -- Make sure the parts are anchored to prevent physics issues and non-collidable
                    if mainPart and not mainPart.Anchored then
                        if DEBUG_MODE then
                            print("Anchoring pet part for: " .. petModel.Name)
                        end
                        mainPart.Anchored = true
                        mainPart.CanCollide = false
                    end
                    
                    -- Check for other unanchored parts and anchor them, also making them non-collidable
                    if petModel:IsA("Model") then
                        for _, part in pairs(petModel:GetDescendants()) do
                            if part:IsA("BasePart") then
                                if not part.Anchored then
                                    part.Anchored = true
                                end
                                part.CanCollide = false  -- Always ensure all pet parts can't collide
                            end
                        end
                    end
                    
                    -- Calculate target position
                    local offsetX = petModel:GetAttribute("OffsetX") or 0
                    local offsetZ = petModel:GetAttribute("OffsetZ") or 0
                    
                    -- Calculate position in air (before finding ground), including velocity prediction
                    local airPosition 
                    if isMoving and humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                        -- Add prediction offset when player is moving but not jumping
                        airPosition = (rootPart.Position + predictionOffset) + 
                            (rootPart.CFrame.RightVector * offsetX) + 
                            (rootPart.CFrame.LookVector * offsetZ)
                    else
                        -- Standard position calculation without prediction
                        airPosition = rootPart.Position + 
                            (rootPart.CFrame.RightVector * offsetX) + 
                            (rootPart.CFrame.LookVector * offsetZ)
                    end
                    
                    -- Find ground below this position
                    local groundPosition, groundPart = findGroundPosition(airPosition, player.Character, petModel)
                    
                    -- Use ground position as target
                    local targetPosition = groundPosition
                    
                    -- Calculate current distance
                    local currentDistance = (targetPosition - mainPart.Position).Magnitude
                    if DEBUG_MODE and currentDistance > 10 then
                        print(petModel.Name .. " distance: " .. currentDistance)
                    end
                    
                    -- Get the player's look direction (Y-rotation only)
                    local playerLookVector = rootPart.CFrame.LookVector
                    local lookCF = CFrame.lookAt(mainPart.Position, mainPart.Position + Vector3.new(playerLookVector.X, 0, playerLookVector.Z))
                    
                    -- Calculate a dynamic tween duration based on distance
                    -- Shorter duration for closer movements, slightly longer for farther movements
                    local tweenDuration = math.min(0.15, math.max(0.05, currentDistance * 0.03))
                    
                    -- Check if we have an active tween running for this pet
                    if activeTweens[slotKey] then
                        -- If the distance is too large or player is moving fast, cancel old tween and create a new one
                        if currentDistance > 10 or (isMoving and playerSpeed > 8) then
                            activeTweens[slotKey]:Cancel()
                            activeTweens[slotKey] = nil
                            
                            if DEBUG_MODE then
                                print("TELEPORTING " .. petModel.Name .. " - distance: " .. currentDistance)
                            end
                            
                            -- For very large distances, directly teleport
                            if currentDistance > 30 then
                                -- Directly set position 
                                if petModel:IsA("Model") and petModel.PrimaryPart then
                                    -- Set whole model CFrame
                                    local targetCF = CFrame.new(targetPosition) * (lookCF - lookCF.Position)
                                    petModel:SetPrimaryPartCFrame(targetCF)
                                else
                                    -- Just set part CFrame
                                    mainPart.CFrame = CFrame.new(targetPosition) * (lookCF - lookCF.Position)
                                end
                            else
                                -- For moderate distances, create a fast tween
                                local newCF = CFrame.new(targetPosition) * (lookCF - lookCF.Position)
                                
                                -- Create a tween for quick catch-up movement
                                local quickTweenInfo = TweenInfo.new(
                                    0.15, -- Quick tween
                                    Enum.EasingStyle.Quad,
                                    Enum.EasingDirection.Out
                                )
                                
                                if petModel:IsA("Model") and petModel.PrimaryPart then
                                    -- Tween the model PrimaryPart
                                    activeTweens[slotKey] = TweenService:Create(mainPart, quickTweenInfo, {
                                        CFrame = newCF
                                    })
                                else
                                    -- Tween the part directly
                                    activeTweens[slotKey] = TweenService:Create(mainPart, quickTweenInfo, {
                                        CFrame = newCF
                                    })
                                end
                                
                                -- Play the tween
                                activeTweens[slotKey]:Play()
                                
                                -- Clean up tween reference when done
                                activeTweens[slotKey].Completed:Connect(function()
                                    activeTweens[slotKey] = nil
                                end)
                            end
                        end
                    else
                        -- Create a target CFrame with the position and rotation
                        local targetCF
                        
                        -- Handle teleporting vs normal movement
                        if currentDistance > 30 then
                            if DEBUG_MODE then
                                print("TELEPORTING " .. petModel.Name .. " - distance: " .. currentDistance)
                            end
                            
                            -- Directly set position if too far
                            if petModel:IsA("Model") and petModel.PrimaryPart then
                                -- Set whole model CFrame
                                targetCF = CFrame.new(targetPosition) * (lookCF - lookCF.Position)
                                petModel:SetPrimaryPartCFrame(targetCF)
                            else
                                -- Just set part CFrame
                                mainPart.CFrame = CFrame.new(targetPosition) * (lookCF - lookCF.Position)
                            end
                        else
                            -- Normal movement - tween to the position
                            local newCF = CFrame.new(targetPosition) * (lookCF - lookCF.Position)
                            
                            -- Create a tween for smooth movement with dynamic duration
                            local tweenInfo = TweenInfo.new(
                                tweenDuration,                      -- Shorter, dynamic duration 
                                Enum.EasingStyle.Quad,              -- Quad for smooth acceleration/deceleration
                                Enum.EasingDirection.Out            -- Out for smoother end of motion
                            )
                            
                            if petModel:IsA("Model") and petModel.PrimaryPart then
                                -- Tween the model PrimaryPart
                                activeTweens[slotKey] = TweenService:Create(mainPart, tweenInfo, {
                                    CFrame = newCF
                                })
                            else
                                -- Tween the part directly
                                activeTweens[slotKey] = TweenService:Create(mainPart, tweenInfo, {
                                    CFrame = newCF
                                })
                            end
                            
                            -- Play the tween
                            activeTweens[slotKey]:Play()
                            
                            -- Clean up tween reference when done
                            activeTweens[slotKey].Completed:Connect(function()
                                activeTweens[slotKey] = nil
                            end)
                        end
                    end
                end
            end
        end
    end
end

-- Remove any existing pets for a player
local function removePetsForPlayer(userId)
    -- Safety check
    if not userId then return end
    
    -- Get player reference for cleanup
    local player = Players:GetPlayerByUserId(userId)
    local playerName = player and player.Name or "Unknown"
    
    -- First remove from active pets table
    if activePets[userId] then
        for slotNumber, petModel in pairs(activePets[userId]) do
            if petModel and petModel.Parent then
                petModel:Destroy()
            end
        end
        activePets[userId] = {}
    end
    
    -- Then do a workspace cleanup for any that might have been missed
    for _, object in pairs(workspace:GetChildren()) do
        if object.Name:match("^" .. playerName .. "_Pet_") then
            object:Destroy()
        end
    end
end

-- Check if player meets level requirements for slots
local function canUseSlot(player, slotNumber)
    if slotNumber == 1 then
        return true -- First slot is always available
    end
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return false end
    
    local level = leaderstats:FindFirstChild("Level")
    if not level then return false end
    
    -- Since you're level 5, you can use slot 2
    if slotNumber == 2 and level.Value >= 5 then
        return true
    elseif slotNumber == 3 and level.Value >= 10 then
        return true
    end
    
    return false
end

-- Load equipped pets for a player
local function loadPlayerPets(player)
    if not player then return end
    
    local userId = player.UserId
    
    -- Get equipped pets from ProfileStore
    local equippedPets = ProfileStorePetHandler:GetEquippedPets(userId)
    
    -- Remove any existing pets (cleanup first)
    removePetsForPlayer(userId)
    
    -- Initialize player's pets table if it doesn't exist
    if not activePets[userId] then
        activePets[userId] = {}
    end
    
    -- Avoid duplicates: check workspace for any pet names matching pattern before creating new ones
    for slot, petId in pairs(equippedPets) do
        if petId then
            -- Get the slot number from the slot string (e.g., "slot1" -> 1)
            local slotNumber = tonumber(string.match(slot, "%d+"))
            
            -- Clean up any existing pets with this slot number
            local cleanupName = player.Name .. "_Pet_" .. slotNumber
            for _, object in pairs(workspace:GetChildren()) do
                if object.Name == cleanupName then
                    object:Destroy()
                end
            end
        end
    end
    
    -- Create pet models for each equipped pet
    for slot, petId in pairs(equippedPets) do
        if petId then
            -- Get the slot number from the slot string (e.g., "slot1" -> 1)
            local slotNumber = tonumber(string.match(slot, "%d+"))
            
            -- Check if player meets level requirements for this slot
            if canUseSlot(player, slotNumber) then
                -- Get pet data from ProfileStore
                local allPets = ProfileStorePetHandler:GetPlayerPets(userId)
                
                -- Find pet with matching ID
                for _, petData in ipairs(allPets) do
                    if petData.id == petId then
                        -- Create and setup the pet model
                        createPetModel(player, petData.name, petData.rarity, slotNumber)
                        break
                    end
                end
            end
        end
    end
end

-- Handle RemoteFunction calls for equipping pets
equipPetEvent.OnServerInvoke = function(player, petId, slot)
    if not player then return false, "Invalid player" end
    
    if EQUIP_DEBUG then
        print("EQUIP REQUEST: Player " .. player.Name .. " trying to equip pet ID " .. petId .. " to slot " .. slot)
    end
    
    -- Convert slot number to slot string
    local slotString = "slot" .. slot
    
    -- Check if player meets level requirements for this slot
    if not canUseSlot(player, slot) then
        if EQUIP_DEBUG then
            print("EQUIP FAILED: Level requirement not met for slot " .. slot)
        end
        return false, "Level requirement not met for this slot"
    end
    
    -- First, do a thorough cleanup to prevent duplicates
    -- 1. Clean up active pets tracking table
    if not activePets[player.UserId] then
        activePets[player.UserId] = {}
    else
        if activePets[player.UserId][slot] then
            local existingPet = activePets[player.UserId][slot]
            if existingPet and existingPet.Parent then
                if EQUIP_DEBUG then
                    print("CLEANUP: Destroying existing pet in slot " .. slot .. " from activePets table")
                end
                existingPet:Destroy()
            end
            activePets[player.UserId][slot] = nil
        end
    end
    
    -- 2. Clean up any pets in workspace with the same slot
    local cleanupName = player.Name .. "_Pet_" .. slot
    local cleanupCount = 0
    for _, object in pairs(workspace:GetChildren()) do
        if object.Name == cleanupName then
            object:Destroy()
            cleanupCount = cleanupCount + 1
        end
    end
    
    if EQUIP_DEBUG and cleanupCount > 0 then
        print("CLEANUP: Removed " .. cleanupCount .. " duplicate pets from workspace for slot " .. slot)
    end
    
    -- Equip the pet in database
    local success, error = ProfileStorePetHandler:EquipPet(player.UserId, petId, slotString)
    
    if not success then
        if EQUIP_DEBUG then
            print("EQUIP FAILED: Database error - " .. (error or "unknown"))
        end
        return false, error
    end
    
    if EQUIP_DEBUG then
        print("EQUIP SUCCESS: Pet " .. petId .. " equipped to slot " .. slot .. " in database")
    end
    
    -- Only create the pet model if successfully equipped in database
    if success then
        -- Get pet data from ProfileStore
        local allPets = ProfileStorePetHandler:GetPlayerPets(player.UserId)
        
        -- Find pet with matching ID
        local petFound = false
        for _, petData in ipairs(allPets) do
            if petData.id == petId then
                petFound = true
                -- Create and setup the pet model (this function now has its own cleanup)
                local petModel = createPetModel(player, petData.name, petData.rarity, slot)
                
                if EQUIP_DEBUG then
                    if petModel then
                        print("MODEL CREATED: Created pet model for " .. petData.name .. " (rarity: " .. petData.rarity .. ") in slot " .. slot)
                    else
                        print("MODEL FAILED: Failed to create pet model for " .. petData.name)
                    end
                end
                
                break
            end
        end
        
        if not petFound and EQUIP_DEBUG then
            print("PET NOT FOUND: Could not find pet with ID " .. petId .. " in player's pets")
        end
    end
    
    return success, error
end

-- Handle RemoteFunction calls for unequipping pets
unequipPetEvent.OnServerInvoke = function(player, slot)
    if not player then return false, "Invalid player" end
    
    if EQUIP_DEBUG then
        print("UNEQUIP REQUEST: Player " .. player.Name .. " trying to unequip pet from slot " .. slot)
    end
    
    -- Convert slot number to slot string
    local slotString = "slot" .. slot
    
    -- First do a thorough cleanup
    -- 1. Clean up from active pets table
    if not activePets[player.UserId] then
        activePets[player.UserId] = {}
    else
        if activePets[player.UserId][slot] then
            local petToRemove = activePets[player.UserId][slot]
            if petToRemove and petToRemove.Parent then
                if EQUIP_DEBUG then
                    print("CLEANUP: Destroying pet in slot " .. slot .. " from activePets table")
                end
                petToRemove:Destroy()
            end
            activePets[player.UserId][slot] = nil
        end
    end
    
    -- 2. Clean up any pets in workspace with the same slot
    local cleanupName = player.Name .. "_Pet_" .. slot
    local cleanupCount = 0
    for _, object in pairs(workspace:GetChildren()) do
        if object.Name == cleanupName then
            object:Destroy()
            cleanupCount = cleanupCount + 1
        end
    end
    
    if EQUIP_DEBUG and cleanupCount > 0 then
        print("CLEANUP: Removed " .. cleanupCount .. " duplicate pets from workspace for slot " .. slot)
    end
    
    -- Then update the database
    local success, error = ProfileStorePetHandler:UnequipPet(player.UserId, slotString)
    
    if success then
        if EQUIP_DEBUG then
            print("UNEQUIP SUCCESS: Pet unequipped from slot " .. slot)
        end
    else
        if EQUIP_DEBUG then
            print("UNEQUIP FAILED: " .. (error or "unknown error"))
        end
    end
    
    return success, error
end

-- Handle RemoteFunction calls for getting equipped pets
getEquippedPetsEvent.OnServerInvoke = function(player)
    if not player then return {} end
    
    -- Get equipped pets
    local equippedPets = ProfileStorePetHandler:GetEquippedPets(player.UserId)
    
    -- Also include information about which slots the player can use
    local slotInfo = {
        slot1 = { petId = equippedPets.slot1, unlocked = canUseSlot(player, 1) },
        slot2 = { petId = equippedPets.slot2, unlocked = canUseSlot(player, 2) },
        slot3 = { petId = equippedPets.slot3, unlocked = canUseSlot(player, 3) }
    }
    
    if EQUIP_DEBUG then
        print("GET EQUIPPED PETS: Returning slots data for " .. player.Name)
        for slotName, data in pairs(slotInfo) do
            print("  " .. slotName .. ": " .. (data.petId or "empty") .. " (unlocked: " .. tostring(data.unlocked) .. ")")
        end
    end
    
    return slotInfo
end

-- Player connections
Players.PlayerAdded:Connect(function(player)
    -- Make sure ProfileStore data is loaded for this player
    if EQUIP_DEBUG then
        print("Player joined, loading pet data for: " .. player.Name)
    end
    
    -- Ensure equipped pets are actually loaded in the database
    task.spawn(function()
        task.wait(1) -- Wait a moment for other systems to start up
        
        local equippedPets = ProfileStorePetHandler:GetEquippedPets(player.UserId)
        if EQUIP_DEBUG then
            print("Initial equipped pets check for " .. player.Name)
            for slotName, petId in pairs(equippedPets) do
                if petId then
                    print("  " .. slotName .. ": " .. petId)
                end
            end
        end
        
        -- Wait for character to load
        if player.Character then
            loadPlayerPets(player)
        else
            if EQUIP_DEBUG then
                print("Waiting for character to load for: " .. player.Name)
            end
        end
        
        player.CharacterAdded:Connect(function(character)
            -- Delay loading pets to ensure character is fully loaded
            task.wait(1)
            loadPlayerPets(player)
        end)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    removePetsForPlayer(player.UserId)
end)

-- Start updating pet positions
-- Modify the frequency and change to use a timer to reduce load
local lastUpdateTime = 0
RunService.Heartbeat:Connect(function(deltaTime)
    local currentTime = tick()
    if currentTime - lastUpdateTime >= UPDATE_INTERVAL then
        lastUpdateTime = currentTime
        
        -- Use pcall to avoid any errors stopping the update loop
        local success, err = pcall(function()
            updatePetPositions()
        end)
        
        if not success then
            warn("Error in pet update: " .. tostring(err))
        end
    end
end)

-- Log initialization
print("Pet Follow Handler initialized") 