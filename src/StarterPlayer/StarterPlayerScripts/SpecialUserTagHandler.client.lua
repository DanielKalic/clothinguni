-- Special User Tag Handler Client Script
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Distance settings
local MAX_VISIBILITY_DISTANCE = 25 -- Maximum distance to see special tags (in studs)

-- Special users configuration
local SPECIAL_USERS = {
    ["DanielKGaming"] = {
        tag = "OWNER",
        color = Color3.fromRGB(150, 0, 0), -- Dark red
        strokeColor = Color3.fromRGB(100, 0, 0), -- Darker red stroke
        gradientColors = {
            Color3.fromRGB(200, 50, 50), -- Light red
            Color3.fromRGB(150, 0, 0), -- Dark red
            Color3.fromRGB(100, 0, 0) -- Darker red
        }
    },
    ["Pherociously"] = {
        tag = "THE GODFATHER",
        color = Color3.fromRGB(0, 150, 150), -- Teal blue
        strokeColor = Color3.fromRGB(0, 100, 100), -- Darker teal stroke
        gradientColors = {
            Color3.fromRGB(50, 200, 200), -- Light teal
            Color3.fromRGB(0, 150, 150), -- Teal blue
            Color3.fromRGB(0, 100, 100) -- Darker teal
        }
    }
}

-- Table to track special tags for all players
local specialTags = {}

-- Function to create special tag
local function createSpecialTag(targetPlayer, userConfig)
    local character = targetPlayer.Character
    if not character then return nil end
    
    local humanoid = character:FindFirstChild("Humanoid")
    local head = character:FindFirstChild("Head")
    if not humanoid or not head then return nil end
    
    -- Create BillboardGui for the special tag
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "SpecialUserTag"
    billboardGui.Size = UDim2.new(0, 120, 0, 30)
    billboardGui.StudsOffset = Vector3.new(0, 3.5, 0) -- Position above head (higher than VIP tags)
    billboardGui.Adornee = head
    billboardGui.Parent = head
    
    -- Create special tag text
    local tagLabel = Instance.new("TextLabel")
    tagLabel.Name = "SpecialLabel"
    tagLabel.Size = UDim2.new(1, 0, 1, 0)
    tagLabel.BackgroundTransparency = 1 -- No background
    tagLabel.Text = userConfig.tag
    tagLabel.TextColor3 = userConfig.color
    tagLabel.TextSize = 20
    tagLabel.Font = Enum.Font.GothamBold
    tagLabel.TextStrokeTransparency = 0
    tagLabel.TextStrokeColor3 = userConfig.strokeColor
    tagLabel.Parent = billboardGui
    
    -- Add text gradient for special effect
    local textGradient = Instance.new("UIGradient")
    textGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, userConfig.gradientColors[1]),
        ColorSequenceKeypoint.new(0.5, userConfig.gradientColors[2]),
        ColorSequenceKeypoint.new(1, userConfig.gradientColors[3])
    }
    textGradient.Rotation = 90
    textGradient.Parent = tagLabel
    
    -- Create special animations for the text
    local function createSpecialAnimation()
        -- Pulse the text size
        local textPulse = TweenService:Create(
            tagLabel,
            TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {TextSize = 24}
        )
        textPulse:Play()
        
        -- Pulse the text transparency for glow effect
        local glowPulse = TweenService:Create(
            tagLabel,
            TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {TextStrokeTransparency = 0.4}
        )
        glowPulse:Play()
        
        -- Rotate the gradient for shimmer effect
        local gradientRotate = TweenService:Create(
            textGradient,
            TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
            {Rotation = 450}
        )
        gradientRotate:Play()
        
        -- Special floating effect for owner tag
        local floatEffect = nil
        if userConfig.tag == "OWNER" then
            floatEffect = TweenService:Create(
                billboardGui,
                TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                {StudsOffset = Vector3.new(0, 4, 0)}
            )
            floatEffect:Play()
        end
        
        return {textPulse, glowPulse, gradientRotate, floatEffect}
    end
    
    -- Start the special animation
    local animations = createSpecialAnimation()
    
    return {
        gui = billboardGui,
        animations = animations,
        cleanup = function()
            for _, anim in pairs(animations) do
                if anim then
                    anim:Cancel()
                end
            end
            billboardGui:Destroy()
        end
    }
end

-- Function to add special tag to a player
local function addSpecialTag(targetPlayer)
    if specialTags[targetPlayer.UserId] then
        return -- Already has a tag
    end
    
    -- Check if this player is in our special users list
    local userConfig = SPECIAL_USERS[targetPlayer.Name]
    if not userConfig then
        return -- Not a special user
    end
    
    local function onCharacterAdded(character)
        -- Wait a bit for character to fully load
        wait(1)
        
        local tag = createSpecialTag(targetPlayer, userConfig)
        if tag then
            specialTags[targetPlayer.UserId] = tag
            print("DEBUG: [SpecialUserTags] Added", userConfig.tag, "tag for", targetPlayer.Name)
        end
    end
    
    -- Connect to character spawning
    if targetPlayer.Character then
        onCharacterAdded(targetPlayer.Character)
    end
    
    targetPlayer.CharacterAdded:Connect(onCharacterAdded)
end

-- Function to remove special tag from a player
local function removeSpecialTag(targetPlayer)
    local tag = specialTags[targetPlayer.UserId]
    if tag then
        tag.cleanup()
        specialTags[targetPlayer.UserId] = nil
        print("DEBUG: [SpecialUserTags] Removed tag for", targetPlayer.Name)
    end
end

-- Function to check and update special status for a player
local function updateSpecialStatus(targetPlayer)
    if SPECIAL_USERS[targetPlayer.Name] then
        addSpecialTag(targetPlayer)
    else
        removeSpecialTag(targetPlayer)
    end
end

-- Check all current players
for _, targetPlayer in pairs(Players:GetPlayers()) do
    updateSpecialStatus(targetPlayer)
end

-- Check new players when they join
Players.PlayerAdded:Connect(function(targetPlayer)
    -- Wait a bit for player to fully load
    wait(2)
    updateSpecialStatus(targetPlayer)
end)

-- Clean up when players leave
Players.PlayerRemoving:Connect(function(targetPlayer)
    removeSpecialTag(targetPlayer)
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

-- Function to update special tag visibility based on distance
local function updateTagVisibility()
    for userId, tagData in pairs(specialTags) do
        local targetPlayer = Players:GetPlayerByUserId(userId)
        if targetPlayer and tagData.gui then
            local distance = getDistanceToPlayer(targetPlayer)
            local shouldBeVisible = distance <= MAX_VISIBILITY_DISTANCE
            
            -- Smoothly fade in/out based on distance
            local targetTransparency = shouldBeVisible and 0 or 1
            
            -- Tween the transparency for smooth fade
            if tagData.gui:FindFirstChild("SpecialLabel") then
                local tagLabel = tagData.gui:FindFirstChild("SpecialLabel")
                local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                local fadeTween = TweenService:Create(tagLabel, fadeInfo, {
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

print("Special User Tag Handler initialized - Monitoring for DanielKGaming (OWNER) and Ferociously (THE GODFATHER)") 