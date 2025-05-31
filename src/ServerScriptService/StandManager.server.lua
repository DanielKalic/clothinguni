-- StandManager.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Constants
local PROXIMITY_PROMPT_HOLD_DURATION = 1 -- seconds
local CLAIM_STAND_GAMEPASS_ID = 1233611231 -- "Claim a Stand" gamepass

-- Variables
local stands = workspace:WaitForChild("Stands"):GetChildren()
local standOwners = {} -- {standName = userId}
local playerStands = {} -- {userId = standName}
local standTexts = {} -- {standName = textContent}

-- Create remote events for client-server communication
local standEvents = Instance.new("Folder")
standEvents.Name = "StandEvents"
standEvents.Parent = ReplicatedStorage

local claimStandEvent = Instance.new("RemoteEvent")
claimStandEvent.Name = "ClaimStandEvent"
claimStandEvent.Parent = standEvents

local releaseStandEvent = Instance.new("RemoteEvent")
releaseStandEvent.Name = "ReleaseStandEvent"
releaseStandEvent.Parent = standEvents

local updateStandDisplayEvent = Instance.new("RemoteEvent")
updateStandDisplayEvent.Name = "UpdateStandDisplayEvent"
updateStandDisplayEvent.Parent = standEvents

local updateTextSignEvent = Instance.new("RemoteEvent")
updateTextSignEvent.Name = "UpdateTextSignEvent"
updateTextSignEvent.Parent = standEvents

-- Helper function to update attributes for other scripts
local function updateAttributes()
    -- Update stand owner attributes
    for standName, userId in pairs(standOwners) do
        script:SetAttribute("standOwner_" .. standName, userId)
    end
    
    -- Update player stand attributes
    for userId, standName in pairs(playerStands) do
        script:SetAttribute("playerStands_" .. userId, standName)
    end
end

-- Helper function to send notifications
local function sendNotification(player, message, color)
    local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
    if notificationEvent then
        notificationEvent:FireClient(player, message, color)
    end
end

-- Function to create or update TextSign
local function updateTextSign(stand, text)
    if not stand then return end
    
    local textSign = stand:FindFirstChild("TextSign")
    if not textSign then
        warn("TextSign model not found in stand:", stand.Name)
        return
    end
    
    local textSignPart = textSign:FindFirstChild("TextSign")
    if not textSignPart then
        warn("TextSign part not found in TextSign model for stand:", stand.Name)
        return
    end
    
    -- Remove existing SurfaceGui if it exists
    local existingSurfaceGui = textSignPart:FindFirstChild("SurfaceGui")
    if existingSurfaceGui then
        existingSurfaceGui:Destroy()
    end
    
    -- Only create new SurfaceGui if text is not empty
    if text and text ~= "" then
        local surfaceGui = Instance.new("SurfaceGui")
        surfaceGui.Name = "SurfaceGui"
        surfaceGui.Face = Enum.NormalId.Back -- Facing back as requested
        surfaceGui.Parent = textSignPart
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "TextLabel"
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Position = UDim2.new(0, 0, 0, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = text
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextSize = 24
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextScaled = true
        textLabel.TextWrapped = true
        textLabel.Parent = surfaceGui
        
        print("Updated TextSign for " .. stand.Name .. " with text: " .. text)
    else
        print("Cleared TextSign for " .. stand.Name)
    end
end

-- Setup each stand
for _, stand in pairs(stands) do
    if stand:IsA("Model") and stand.Name:match("Stand%d") then
        local claimSign = stand:FindFirstChild("ClaimSign")
        if claimSign then
            local ownerPart = claimSign:FindFirstChild("Owner")
            if ownerPart then
                -- Create ProximityPrompt
                local prompt = Instance.new("ProximityPrompt")
                prompt.ObjectText = "Stand"
                prompt.ActionText = "Claim"
                prompt.HoldDuration = PROXIMITY_PROMPT_HOLD_DURATION
                prompt.RequiresLineOfSight = false
                prompt.Parent = ownerPart
                
                -- Store the stand name in the prompt
                prompt:SetAttribute("StandName", stand.Name)
                
                -- Update text label
                local surfaceGui = ownerPart:FindFirstChild("SurfaceGui")
                if surfaceGui then
                    local textLabel = surfaceGui:FindFirstChild("TextLabel")
                    if textLabel then
                        textLabel.Text = "Claim Stand"
                    end
                end
            end
        end
        
        print("Set up stand: " .. stand.Name)
    end
end

-- Function to release a stand
local function releaseStand(player)
    local userId = player.UserId
    local standName = playerStands[userId]
    
    if not standName then
        return false
    end
    
    -- Release the stand
    standOwners[standName] = nil
    playerStands[userId] = nil
    standTexts[standName] = nil -- Clear the text
    
    -- Update attributes
    updateAttributes()
    
    -- Update claim sign text
    local stand = workspace.Stands:FindFirstChild(standName)
    if stand then
        local claimSign = stand:FindFirstChild("ClaimSign")
        if claimSign then
            local ownerPart = claimSign:FindFirstChild("Owner")
            if ownerPart then
                local surfaceGui = ownerPart:FindFirstChild("SurfaceGui")
                if surfaceGui then
                    local textLabel = surfaceGui:FindFirstChild("TextLabel")
                    if textLabel then
                        textLabel.Text = "Claim Stand"
                    end
                end
                
                -- Update prompt
                local prompt = ownerPart:FindFirstChild("ProximityPrompt")
                if prompt then
                    prompt.ActionText = "Claim"
                end
            end
        end
        
        -- Clear the TextSign
        updateTextSign(stand, "")
    end
    
    -- Fire cleanup event to StandDisplayHandler
    local cleanupEvent = standEvents:FindFirstChild("CleanupStandDisplaysEvent")
    if cleanupEvent then
        cleanupEvent:Fire(standName)
    end
    
    -- Notify player
    sendNotification(player, "You released " .. standName, Color3.fromRGB(255, 255, 0))
    
    -- Fire event to client
    releaseStandEvent:FireClient(player, standName)
    
    return true
end

-- Function to claim a stand
local function claimStand(player, standName)
    local userId = player.UserId
    
    -- Check if player owns the "Claim a Stand" gamepass
    local hasGamepass = false
    local success, result = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(userId, CLAIM_STAND_GAMEPASS_ID)
    end)
    
    if success then
        hasGamepass = result
    else
        warn("Failed to check gamepass ownership for player " .. player.Name .. ": " .. tostring(result))
    end
    
    if not hasGamepass then
        -- Prompt player to buy the gamepass
        sendNotification(player, "You need the 'Claim a Stand' gamepass to claim stands!", Color3.fromRGB(255, 100, 0))
        
        -- Prompt gamepass purchase
        local promptSuccess, promptError = pcall(function()
            MarketplaceService:PromptGamePassPurchase(player, CLAIM_STAND_GAMEPASS_ID)
        end)
        
        if not promptSuccess then
            warn("Failed to prompt gamepass purchase for player " .. player.Name .. ": " .. tostring(promptError))
        end
        
        return false
    end
    
    -- Check if player already has a stand
    if playerStands[userId] then
        sendNotification(player, "You already own a stand! Release your current stand first before claiming a new one.", Color3.fromRGB(255, 100, 0))
        return false
    end
    
    -- Check if stand is already claimed
    if standOwners[standName] then
        sendNotification(player, "This stand is already claimed!", Color3.fromRGB(255, 0, 0))
        return false
    end
    
    -- Claim the stand
    standOwners[standName] = userId
    playerStands[userId] = standName
    standTexts[standName] = "" -- Initialize with empty text
    
    -- Update attributes
    updateAttributes()
    
    -- Update claim sign text
    local stand = workspace.Stands:FindFirstChild(standName)
    if stand then
        local claimSign = stand:FindFirstChild("ClaimSign")
        if claimSign then
            local ownerPart = claimSign:FindFirstChild("Owner")
            if ownerPart then
                local surfaceGui = ownerPart:FindFirstChild("SurfaceGui")
                if surfaceGui then
                    local textLabel = surfaceGui:FindFirstChild("TextLabel")
                    if textLabel then
                        textLabel.Text = "Claimed by\n" .. player.Name
                    end
                end
                
                -- Update prompt
                local prompt = ownerPart:FindFirstChild("ProximityPrompt")
                if prompt then
                    prompt.ActionText = "Release"
                end
            end
        end
    end
    
    -- Notify player
    sendNotification(player, "You claimed " .. standName .. "! Press F to open clothing selection menu.", Color3.fromRGB(0, 255, 0))
    
    -- Fire event to client
    claimStandEvent:FireClient(player, standName)
    
    return true
end

-- Handle TextSign update event
updateTextSignEvent.OnServerEvent:Connect(function(player, text)
    local userId = player.UserId
    local standName = playerStands[userId]
    
    if not standName then
        sendNotification(player, "You don't own a stand!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    -- Validate text length (optional)
    if text and string.len(text) > 100 then
        sendNotification(player, "Text is too long! Maximum 100 characters.", Color3.fromRGB(255, 100, 100))
        return
    end
    
    -- Update the text
    standTexts[standName] = text or ""
    
    -- Find the stand and update the TextSign
    local stand = workspace.Stands:FindFirstChild(standName)
    if stand then
        updateTextSign(stand, text)
        sendNotification(player, "TextSign updated!", Color3.fromRGB(100, 255, 100))
    else
        warn("Stand not found:", standName)
        sendNotification(player, "Stand not found!", Color3.fromRGB(255, 100, 100))
    end
end)

-- Handle proximity prompt interactions
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    -- Check if this is a stand prompt
    local standName = prompt:GetAttribute("StandName")
    if not standName then
        return
    end
    
    local userId = player.UserId
    
    -- If this stand is already claimed by this player, release it
    if playerStands[userId] == standName then
        releaseStand(player)
    -- If this stand is claimed by someone else, notify player
    elseif standOwners[standName] and standOwners[standName] ~= userId then
        sendNotification(player, "This stand is already claimed!", Color3.fromRGB(255, 0, 0))
    -- Otherwise, claim the stand
    else
        claimStand(player, standName)
    end
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
    releaseStand(player)
end)

print("Stand Manager initialized") 