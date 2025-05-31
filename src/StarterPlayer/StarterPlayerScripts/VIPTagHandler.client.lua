-- VIP Tag Handler Client Script
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

-- Distance settings
local MAX_VISIBILITY_DISTANCE = 25 -- Maximum distance to see VIP tags (in studs)

-- Special users who should NOT get VIP tags (they have special tags instead)
local SPECIAL_USERS_OVERRIDE = {
    ["DanielKGaming"] = true,
    ["Pherociously"] = true
}

-- Table to track VIP tags for all players
local vipTags = {}

-- Function to check if a player owns VIP gamepass
local function hasVIPGamepass(checkPlayer)
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(checkPlayer.UserId, VIP_GAMEPASS_ID)
    end)
    return success and ownsGamepass
end

-- Function to create VIP tag
local function createVIPTag(targetPlayer)
    local character = targetPlayer.Character
    if not character then return nil end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local head = character:FindFirstChild("Head")
    if not humanoid or not head then return nil end
    
    -- Create BillboardGui for the VIP tag
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "VIPTag"
    billboardGui.Size = UDim2.new(0, 80, 0, 25)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0) -- Position above head
    billboardGui.Adornee = head
    billboardGui.Parent = head
    
    -- Create VIP text with golden style
    local vipLabel = Instance.new("TextLabel")
    vipLabel.Name = "VIPLabel"
    vipLabel.Size = UDim2.new(1, 0, 1, 0)
    vipLabel.BackgroundTransparency = 1 -- No background
    vipLabel.Text = "VIP"
    vipLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Golden color
    vipLabel.TextSize = 18
    vipLabel.Font = Enum.Font.GothamBold
    vipLabel.TextStrokeTransparency = 0
    vipLabel.TextStrokeColor3 = Color3.fromRGB(200, 150, 0) -- Darker golden stroke
    vipLabel.Parent = billboardGui
    
    -- Add text gradient for golden effect
    local textGradient = Instance.new("UIGradient")
    textGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 150)), -- Light golden
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)), -- Golden
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 0)) -- Deeper golden
    }
    textGradient.Rotation = 90
    textGradient.Parent = vipLabel
    
    -- Create pulsing animation for the text
    local function createPulseAnimation()
        -- Pulse the text size
        local textPulse = TweenService:Create(
            vipLabel,
            TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {TextSize = 22}
        )
        textPulse:Play()
        
        -- Pulse the text transparency for glow effect
        local glowPulse = TweenService:Create(
            vipLabel,
            TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {TextStrokeTransparency = 0.3}
        )
        glowPulse:Play()
        
        -- Rotate the gradient for shimmer effect
        local gradientRotate = TweenService:Create(
            textGradient,
            TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
            {Rotation = 450}
        )
        gradientRotate:Play()
        
        return {textPulse, glowPulse, gradientRotate}
    end
    
    -- Start the pulsing animation
    local animations = createPulseAnimation()
    
    return {
        gui = billboardGui,
        animations = animations,
        cleanup = function()
            for _, anim in pairs(animations) do
                anim:Cancel()
            end
            billboardGui:Destroy()
        end
    }
end

-- Function to add VIP tag to a player
local function addVIPTag(targetPlayer)
    if vipTags[targetPlayer.UserId] then
        return -- Already has a tag
    end
    
    -- Check if this player has a special tag that overrides VIP
    if SPECIAL_USERS_OVERRIDE[targetPlayer.Name] then
        print("DEBUG: [VIPTagHandler] Skipping VIP tag for", targetPlayer.Name, "- has special tag override")
        return
    end
    
    local function onCharacterAdded(character)
        -- Wait a bit for character to fully load
        wait(1)
        
        -- Check if player still has VIP gamepass
        if hasVIPGamepass(targetPlayer) then
            local tag = createVIPTag(targetPlayer)
            if tag then
                vipTags[targetPlayer.UserId] = tag
            end
        end
    end
    
    -- Connect to character spawning
    if targetPlayer.Character then
        onCharacterAdded(targetPlayer.Character)
    end
    
    targetPlayer.CharacterAdded:Connect(onCharacterAdded)
end

-- Function to remove VIP tag from a player
local function removeVIPTag(targetPlayer)
    local tag = vipTags[targetPlayer.UserId]
    if tag then
        tag.cleanup()
        vipTags[targetPlayer.UserId] = nil
    end
end

-- Function to check and update VIP status for a player
local function updateVIPStatus(targetPlayer)
    -- Skip VIP tags for special users
    if SPECIAL_USERS_OVERRIDE[targetPlayer.Name] then
        removeVIPTag(targetPlayer) -- Remove VIP tag if they somehow have one
        return
    end
    
    if hasVIPGamepass(targetPlayer) then
        addVIPTag(targetPlayer)
    else
        removeVIPTag(targetPlayer)
    end
end

-- Check all current players
for _, targetPlayer in pairs(Players:GetPlayers()) do
    updateVIPStatus(targetPlayer)
end

-- Check new players when they join
Players.PlayerAdded:Connect(function(targetPlayer)
    -- Wait a bit for player to fully load
    wait(2)
    updateVIPStatus(targetPlayer)
end)

-- Clean up when players leave
Players.PlayerRemoving:Connect(function(targetPlayer)
    removeVIPTag(targetPlayer)
end)

-- Function to check distance between local player and target player
local function getDistanceToPlayer(targetPlayer)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return math.huge
    end
    
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return math.huge
    end
    
    local localPosition = player.Character.HumanoidRootPart.Position
    local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
    
    return (localPosition - targetPosition).Magnitude
end

-- Function to update VIP tag visibility based on distance
local function updateTagVisibility()
    for userId, tagData in pairs(vipTags) do
        local targetPlayer = Players:GetPlayerByUserId(userId)
        if targetPlayer and tagData.gui then
            local distance = getDistanceToPlayer(targetPlayer)
            local shouldBeVisible = distance <= MAX_VISIBILITY_DISTANCE
            
            -- Smoothly fade in/out based on distance
            local targetTransparency = shouldBeVisible and 0 or 1
            
            -- Tween the transparency for smooth fade
            if tagData.gui:FindFirstChild("VIPLabel") then
                local vipLabel = tagData.gui:FindFirstChild("VIPLabel")
                local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local fadeTween = TweenService:Create(vipLabel, fadeInfo, {
                    TextTransparency = targetTransparency,
                    TextStrokeTransparency = shouldBeVisible and 0 or 1
                })
                fadeTween:Play()
            end
        end
    end
end

-- Start distance checking loop
spawn(function()
    while true do
        updateTagVisibility()
        wait(0.1) -- Check distance every 0.1 seconds for smooth updates
    end
end)

-- Periodically check VIP status (in case someone purchases VIP while in game)
spawn(function()
    while true do
        wait(30) -- Check every 30 seconds
        for _, targetPlayer in pairs(Players:GetPlayers()) do
            -- Skip special users
            if not SPECIAL_USERS_OVERRIDE[targetPlayer.Name] then
                local hasVIP = hasVIPGamepass(targetPlayer)
                local hasTag = vipTags[targetPlayer.UserId] ~= nil
                
                if hasVIP and not hasTag then
                    addVIPTag(targetPlayer)
                elseif not hasVIP and hasTag then
                    removeVIPTag(targetPlayer)
                end
            else
                -- Remove VIP tag from special users if they somehow have one
                if vipTags[targetPlayer.UserId] then
                    removeVIPTag(targetPlayer)
                end
            end
        end
    end
end)

print("VIP Tag Handler initialized") 