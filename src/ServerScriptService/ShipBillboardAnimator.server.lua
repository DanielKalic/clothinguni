-- ShipBillboardAnimator.server.lua
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

print("ShipBillboardAnimator: Starting after delay for core system initialization...")

-- Delay initialization to reduce server load during startup (billboard animations are non-essential)
wait(45)

print("ShipBillboardAnimator: Starting billboard ship animations...")

-- Animation settings
local ROTATION_SPEED = 0.5 -- Degrees per second (adjust for desired speed)
local SHIP_HEIGHT_VARIATION = 2 -- How much ships bob up and down
local BOB_SPEED = 1 -- Speed of the bobbing motion

-- Variables
local shipsFolder = nil
local centerRotation = nil
local shipData = {} -- Store original positions and animation data for each ship
local animationConnection = nil

-- Function to initialize ship animation system
local function initializeShipAnimation()
    -- Find the Billboards folder
    local billboardsFolder = workspace:FindFirstChild("Billboards")
    if not billboardsFolder then
        warn("Billboards folder not found in workspace!")
        return false
    end
    
    -- Find the Ships folder
    shipsFolder = billboardsFolder:FindFirstChild("Ships")
    if not shipsFolder then
        warn("Ships folder not found in Billboards!")
        return false
    end
    
    -- Find the CenterRotation reference point
    centerRotation = shipsFolder:FindFirstChild("CenterRotation")
    if not centerRotation then
        warn("CenterRotation not found in Ships folder!")
        return false
    end
    
    print("Ship animation system initialized successfully")
    return true
end

-- Function to calculate ship positions and setup animation data
local function setupShipData()
    if not shipsFolder or not centerRotation then
        return
    end
    
    -- Clear existing ship data
    shipData = {}
    
    -- Get center position
    local centerPosition = centerRotation.Position
    
    -- Find all ship billboard models
    for _, shipModel in pairs(shipsFolder:GetChildren()) do
        if shipModel:IsA("Model") and shipModel.Name:lower():find("shipbillboard") then
            -- Set the MeshPart as the PrimaryPart if it exists
            local meshPart = shipModel:FindFirstChild("MeshPart")
            if meshPart then
                shipModel.PrimaryPart = meshPart
            end
            
            local primaryPart = shipModel.PrimaryPart or shipModel:FindFirstChild("MeshPart") or shipModel:FindFirstChildOfClass("Part")
            
            if primaryPart then
                -- Get the original CFrame of the entire model
                local originalCFrame = shipModel:GetPrimaryPartCFrame() or primaryPart.CFrame
                
                -- Calculate the offset from center to ship in the original position
                local shipPosition = originalCFrame.Position
                local offsetVector = shipPosition - centerPosition
                local distance = offsetVector.Magnitude
                local startAngle = math.atan2(offsetVector.Z, offsetVector.X)
                
                -- Store the original rotation separately from position
                local originalRotation = originalCFrame - originalCFrame.Position -- Get just the rotation part
                
                -- Store ship data
                shipData[shipModel] = {
                    model = shipModel,
                    primaryPart = primaryPart,
                    distance = distance,
                    currentAngle = startAngle,
                    originalY = shipPosition.Y,
                    bobOffset = math.random() * math.pi * 2, -- Random bob phase
                    originalCFrame = originalCFrame,
                    originalRotation = originalRotation -- Store the original rotation matrix
                }
                
                print("Setup ship data for " .. shipModel.Name .. " - Distance: " .. distance .. ", Start Angle: " .. math.deg(startAngle))
            else
                warn("No primary part found for ship: " .. shipModel.Name)
            end
        end
    end
    
    print("Ship data setup complete for " .. #shipData .. " ships")
end

-- Function to update ship positions
local function updateShipPositions(deltaTime)
    if not centerRotation then
        return
    end
    
    local centerPosition = centerRotation.Position
    local currentTime = tick()
    
    for shipModel, data in pairs(shipData) do
        if shipModel.Parent and data.primaryPart.Parent then
            -- Update rotation angle (clockwise around the island)
            data.currentAngle = data.currentAngle + math.rad(ROTATION_SPEED * deltaTime)
            
            -- Calculate new position on the circle
            local newX = centerPosition.X + math.cos(data.currentAngle) * data.distance
            local newZ = centerPosition.Z + math.sin(data.currentAngle) * data.distance
            
            -- Add bobbing motion
            local bobOffset = math.sin(currentTime * BOB_SPEED + data.bobOffset) * SHIP_HEIGHT_VARIATION
            local newY = data.originalY + bobOffset
            
            -- Create new position vector
            local newPosition = Vector3.new(newX, newY, newZ)
            
            -- Calculate how much the ship has rotated around the circle from its original position
            local originalAngle = math.atan2(data.originalCFrame.Position.Z - centerPosition.Z, data.originalCFrame.Position.X - centerPosition.X)
            local rotationDifference = data.currentAngle - originalAngle
            
            -- Apply the rotation difference to the original rotation (negative to rotate in correct direction)
            local rotationAroundY = CFrame.Angles(0, -rotationDifference, 0)
            local newCFrame = rotationAroundY * data.originalRotation + newPosition
            
            -- Move the entire ship model using SetPrimaryPartCFrame
            if data.model.PrimaryPart then
                data.model:SetPrimaryPartCFrame(newCFrame)
            else
                -- Fallback: move just the primary part if SetPrimaryPartCFrame fails
                data.primaryPart.CFrame = newCFrame
            end
        else
            -- Ship was deleted, remove from data
            shipData[shipModel] = nil
        end
    end
end

-- Function to start ship animation
local function startShipAnimation()
    if animationConnection then
        animationConnection:Disconnect()
    end
    
    local lastTime = tick()
    animationConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        local deltaTime = currentTime - lastTime
        lastTime = currentTime
        
        updateShipPositions(deltaTime)
    end)
    
    print("Ship animation started")
end

-- Function to stop ship animation
local function stopShipAnimation()
    if animationConnection then
        animationConnection:Disconnect()
        animationConnection = nil
    end
    
    print("Ship animation stopped")
end

-- Function to reset ships to original positions
local function resetShipPositions()
    for shipModel, data in pairs(shipData) do
        if shipModel.Parent and data.primaryPart.Parent then
            -- Reset the entire ship model using SetPrimaryPartCFrame
            if data.model.PrimaryPart then
                data.model:SetPrimaryPartCFrame(data.originalCFrame)
            else
                -- Fallback: reset just the primary part if SetPrimaryPartCFrame fails
                data.primaryPart.CFrame = data.originalCFrame
            end
        end
    end
    
    print("Ship positions reset to original")
end

-- Function to refresh ship animation (call when ships are added/removed)
local function refreshShipAnimation()
    stopShipAnimation()
    setupShipData()
    if next(shipData) then -- Only start if we have ships
        startShipAnimation()
    end
end

-- Initialize the system
local function initialize()
    task.wait(5) -- Wait for workspace to load
    
    if initializeShipAnimation() then
        setupShipData()
        
        -- Only start animation if we have ships
        if next(shipData) then
            startShipAnimation()
        else
            print("No ships found, animation will start when ships are added")
        end
        
        -- Monitor for new ships being added
        if shipsFolder then
            shipsFolder.ChildAdded:Connect(function(child)
                if child:IsA("Model") and child.Name:lower():find("shipbillboard") then
                    task.wait(1) -- Wait for the model to fully load
                    print("New ship detected: " .. child.Name)
                    refreshShipAnimation()
                end
            end)
            
            shipsFolder.ChildRemoved:Connect(function(child)
                if child:IsA("Model") and child.Name:lower():find("shipbillboard") then
                    print("Ship removed: " .. child.Name)
                    refreshShipAnimation()
                end
            end)
        end
    else
        warn("Failed to initialize ship animation system")
    end
end

-- Public functions for external control
_G.ShipBillboardAnimator = {
    start = startShipAnimation,
    stop = stopShipAnimation,
    reset = resetShipPositions,
    refresh = refreshShipAnimation,
    setSpeed = function(speed)
        ROTATION_SPEED = speed
        print("Ship rotation speed set to: " .. speed)
    end,
    setBobbing = function(height, speed)
        SHIP_HEIGHT_VARIATION = height
        BOB_SPEED = speed
        print("Ship bobbing set to height: " .. height .. ", speed: " .. speed)
    end
}

-- Start the system
task.spawn(initialize)

print("ShipBillboardAnimator loaded successfully") 