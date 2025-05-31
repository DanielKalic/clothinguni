-- StandDisplayHandler.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local InsertService = game:GetService("InsertService")

-- Get the NPC template from ServerStorage (same as PodiumNPCs)
local npcTemplate = game.ServerStorage:WaitForChild("NPC_Template")

-- Get events
local standEvents = ReplicatedStorage:WaitForChild("StandEvents")
local updateStandDisplayEvent = standEvents:WaitForChild("UpdateStandDisplayEvent")

-- Variables
local activeDisplays = {} -- {standName = {platformKey = npcModel}}

-- Function to get the actual clothing template from an asset ID
local function getClothingTemplate(assetId, clothingType)
    local success, result = pcall(function()
        -- Load the asset using InsertService
        local asset = InsertService:LoadAsset(tonumber(assetId))
        
        if asset then
            -- Find the clothing object in the asset
            local clothing = asset:FindFirstChildOfClass(clothingType)
            if clothing then
                local template
                if clothingType == "Shirt" then
                    template = clothing.ShirtTemplate
                elseif clothingType == "Pants" then
                    template = clothing.PantsTemplate
                end
                
                -- Clean up the asset
                asset:Destroy()
                
                return template
            end
            
            -- Clean up if no clothing found
            asset:Destroy()
        end
        
        return nil
    end)
    
    if success and result then
        print("DEBUG: [StandDisplayHandler] Successfully got template for " .. clothingType .. " ID " .. assetId .. ": " .. result)
        return result
    else
        print("DEBUG: [StandDisplayHandler] Failed to get template for " .. clothingType .. " ID " .. assetId .. ", using fallback")
        return "http://www.roblox.com/asset/?id=" .. assetId
    end
end

-- Helper function to send notifications
local function sendNotification(player, message, color)
    local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent")
    if notificationEvent then
        notificationEvent:FireClient(player, message, color)
    end
end

-- Function to remove a clothing display
local function removeClothingDisplay(stand, platformName)
    if not stand or not platformName then return end
    
    -- Check if we have an active display tracked
    if activeDisplays[stand.Name] and activeDisplays[stand.Name][platformName] then
        local npcModel = activeDisplays[stand.Name][platformName]
        if npcModel and npcModel.Parent then
            npcModel:Destroy()
            print("Removed tracked NPC display from " .. stand.Name .. "/" .. platformName)
        end
        activeDisplays[stand.Name][platformName] = nil
    end
    
    -- Also check for any NPCs in workspace with the expected name (cleanup)
    local expectedName = platformName .. "Display"
    for _, child in pairs(workspace:GetChildren()) do
        if child.Name == expectedName and child:IsA("Model") then
            child:Destroy()
            print("Cleaned up orphaned NPC display: " .. expectedName)
        end
    end
end

-- Function to create an NPC mannequin using the template (like PodiumNPCs)
local function createNPCMannequin(platform, clothingData, platformName)
    if not platform or not clothingData then return nil end
    
    -- Clone the NPC template
    local npc = npcTemplate:Clone()
    -- Set name to empty so it doesn't show "Platform1Display"
    npc.Name = ""
    
    -- Calculate position above the platform
    local platformCFrame = platform.CFrame
    local platformSize = platform.Size
    
    -- Position the NPC on top of the platform, facing left (270 degrees rotation)
    local npcPosition = platformCFrame * CFrame.new(0, platformSize.Y/2 + 3, 0) * CFrame.Angles(0, math.rad(270), 0)
    npc:SetPrimaryPartCFrame(npcPosition)
    
    -- Remove any existing clothing first
    local existingShirt = npc:FindFirstChildOfClass("Shirt")
    local existingPants = npc:FindFirstChildOfClass("Pants")
    
    if existingShirt then
        existingShirt:Destroy()
    end
    if existingPants then
        existingPants:Destroy()
    end
    
    -- Apply the selected clothing using real templates
    if clothingData.assetType == "Shirt" then
        local shirtTemplate = getClothingTemplate(clothingData.assetId, "Shirt")
        local shirt = Instance.new("Shirt")
        shirt.Name = "Shirt"
        shirt.ShirtTemplate = shirtTemplate
        shirt.Parent = npc
        print("DEBUG: [StandDisplayHandler] Applied shirt template: " .. shirtTemplate)
        
        -- Add default pants
        local defaultPants = Instance.new("Pants")
        defaultPants.Name = "Pants"
        defaultPants.PantsTemplate = "http://www.roblox.com/asset/?id=7526844691" -- Default gray pants
        defaultPants.Parent = npc
    elseif clothingData.assetType == "Pants" then
        local pantsTemplate = getClothingTemplate(clothingData.assetId, "Pants")
        local pants = Instance.new("Pants")
        pants.Name = "Pants"
        pants.PantsTemplate = pantsTemplate
        pants.Parent = npc
        print("DEBUG: [StandDisplayHandler] Applied pants template: " .. pantsTemplate)
        
        -- Add default shirt
        local defaultShirt = Instance.new("Shirt")
        defaultShirt.Name = "Shirt"
        defaultShirt.ShirtTemplate = "http://www.roblox.com/asset/?id=7526844438" -- Default gray shirt
        defaultShirt.Parent = npc
    end
    
    -- Set all NPC parts to the "NPC" collision group (like in PodiumNPCs)
    for _, part in ipairs(npc:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = "NPC"
        end
    end
    
    -- No label needed - removed to keep NPCs clean
    
    -- Add try-on ProximityPrompt (same as PodiumNPCs)
    local promptParent = headPart or (npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart"))
    if promptParent then
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = "Try On"
        prompt.ObjectText = "Clothing"
        prompt.HoldDuration = 1
        prompt.MaxActivationDistance = 10
        prompt.RequiresLineOfSight = false
        prompt.Enabled = true
        prompt.Parent = promptParent
        prompt.UIOffset = Vector2.new(0, 0)
        prompt.Triggered:Connect(function(triggeringPlayer)
            local character = triggeringPlayer.Character
            if not character then return end
            
            local originalShirt, originalPants
            local currentShirt = character:FindFirstChildOfClass("Shirt")
            if currentShirt then
                originalShirt = currentShirt.ShirtTemplate
                -- Only remove the current shirt if we're trying on a new shirt
                if clothingData.assetType == "Shirt" then
                    currentShirt:Destroy()
                end
            end
            
            local currentPants = character:FindFirstChildOfClass("Pants")
            if currentPants then
                originalPants = currentPants.PantsTemplate
                -- Only remove the current pants if we're trying on new pants
                if clothingData.assetType == "Pants" then
                    currentPants:Destroy()
                end
            end
            
            -- Apply the new clothing using real templates
            if clothingData.assetType == "Shirt" then
                local shirtTemplate = getClothingTemplate(clothingData.assetId, "Shirt")
                local newShirt = Instance.new("Shirt")
                newShirt.ShirtTemplate = shirtTemplate
                newShirt.Parent = character
            elseif clothingData.assetType == "Pants" then
                local pantsTemplate = getClothingTemplate(clothingData.assetId, "Pants")
                local newPants = Instance.new("Pants")
                newPants.PantsTemplate = pantsTemplate
                newPants.Parent = character
            end
            
            -- Update daily objectives for clothing try-on (once per action)
            if _G.UpdateDailyObjective then
                local success, err = pcall(function()
                    _G.UpdateDailyObjective(triggeringPlayer, "tryOnClothes", 1)
                end)
                if not success then
                    warn("DEBUG: [StandDisplayHandler] Daily objective update failed:", err)
                end
            end
            
            -- Clothing now stays on the player until manually changed
            -- No automatic revert after 10 seconds
        end)
    end
    
    -- Add purchase functionality (same as PodiumNPCs)
    local MarketplaceService = game:GetService("MarketplaceService")
    local primaryPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
    if primaryPart then
        -- Create purchase zone covering the NPC
        local purchaseZone = Instance.new("Part")
        purchaseZone.Name = "PurchaseZone"
        purchaseZone.Size = Vector3.new(4, 6, 4) -- Cover the whole NPC
        purchaseZone.CFrame = primaryPart.CFrame
        purchaseZone.Transparency = 1
        purchaseZone.CanCollide = false
        purchaseZone.Parent = npc
        
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = purchaseZone
        weld.Part1 = primaryPart
        weld.Parent = purchaseZone
        
        local clickDetector = Instance.new("ClickDetector")
        clickDetector.MaxActivationDistance = 10
        clickDetector.Parent = purchaseZone
        clickDetector.MouseClick:Connect(function(player)
            MarketplaceService:PromptPurchase(player, tonumber(clothingData.assetId))
        end)
    end
    
    return npc
end

-- Function to create a clothing display on a platform
local function createClothingDisplay(stand, platformName, clothingData)
    if not stand or not platformName or not clothingData then return end
    
    -- Find the platform
    local platform = stand:FindFirstChild(platformName)
    if not platform then 
        warn("Platform not found:", platformName, "in stand:", stand.Name)
        return 
    end
    
    -- Remove any existing display
    removeClothingDisplay(stand, platformName)
    
    -- Create the NPC mannequin using the template
    local npcModel = createNPCMannequin(platform, clothingData, platformName)
    if not npcModel then
        warn("Failed to create NPC mannequin for", platformName)
        return
    end
    
    -- Parent to workspace (like in PodiumNPCs)
    npcModel.Parent = workspace
    
    -- Store in the active displays
    if not activeDisplays[stand.Name] then
        activeDisplays[stand.Name] = {}
    end
    activeDisplays[stand.Name][platformName] = npcModel
    
    print("Created display for " .. clothingData.assetType .. " #" .. clothingData.assetId .. " on " .. stand.Name .. "/" .. platformName)
    return npcModel
end

-- Handle update display event
updateStandDisplayEvent.OnServerEvent:Connect(function(player, standName, clothingSelection)
    print("DEBUG: UpdateStandDisplayEvent received from", player.Name)
    print("DEBUG: Stand:", standName)
    print("DEBUG: Clothing selection:")
    for platform, data in pairs(clothingSelection) do
        if data then
            print("DEBUG:", platform, "=", data.assetType, "#" .. data.assetId)
        else
            print("DEBUG:", platform, "= nil")
        end
    end
    
    -- Validate player
    local userId = player.UserId
    
    -- Get the stand
    local stand = workspace.Stands:FindFirstChild(standName)
    if not stand then
        warn("Stand not found:", standName)
        sendNotification(player, "Stand not found!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    -- Update each platform
    for platformKey, clothingData in pairs(clothingSelection) do
        if clothingData and clothingData.assetId and clothingData.assetType then
            print("DEBUG: Creating display for", platformKey, "with", clothingData.assetType, "#" .. clothingData.assetId)
            createClothingDisplay(stand, platformKey, clothingData)
        else
            print("DEBUG: Removing display for", platformKey)
            removeClothingDisplay(stand, platformKey)
        end
    end
    
    sendNotification(player, "Stand display updated!", Color3.fromRGB(100, 255, 100))
end)

-- Clean up displays when stand is released
local function cleanupStandDisplays(standName)
    local stand = workspace.Stands:FindFirstChild(standName)
    if not stand then return end
    
    -- Remove all displays
    for i = 1, 4 do
        local platformName = "Platform" .. i
        removeClothingDisplay(stand, platformName)
    end
    
    -- Clear tracking
    activeDisplays[standName] = nil
end

-- Create a server-side cleanup event
local cleanupStandDisplaysEvent = Instance.new("BindableEvent")
cleanupStandDisplaysEvent.Name = "CleanupStandDisplaysEvent"
cleanupStandDisplaysEvent.Parent = standEvents

-- Connect to the cleanup event
cleanupStandDisplaysEvent.Event:Connect(function(standName)
    print("DEBUG: Stand " .. standName .. " was released, cleaning up displays")
    cleanupStandDisplays(standName)
end)

print("StandDisplayHandler loaded successfully") 