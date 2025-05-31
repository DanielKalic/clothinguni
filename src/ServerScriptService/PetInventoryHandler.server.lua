-- Pet Inventory Handler
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Load the ProfileStore Pet Handler
local ProfileStorePetHandler = require(ReplicatedStorage:WaitForChild("ProfileStorePetHandler"))

-- Get or create remote function for retrieving pet data
local getPetsDataEvent = ReplicatedStorage:FindFirstChild("GetPetsDataEvent")
if not getPetsDataEvent then
    getPetsDataEvent = Instance.new("RemoteFunction")
    getPetsDataEvent.Name = "GetPetsDataEvent"
    getPetsDataEvent.Parent = ReplicatedStorage
end

-- Data store to track owned pets (for migration and legacy support)
local ownedPetsStore = DataStoreService:GetDataStore("OwnedPets")

-- Function to get a player's pets
local function getPlayerPets(player)
    local userId = player.UserId
    
    -- Get pets from ProfileStore
    local pets = ProfileStorePetHandler:GetPlayerPets(userId)
    
    -- If no pets found in ProfileStore, try to migrate from DataStore
    if #pets == 0 then
        local success, message = ProfileStorePetHandler:MigrateFromDataStore(ownedPetsStore, userId)
        if success then
            print("Migrated pets for player " .. player.Name .. ": " .. message)
            -- Get the freshly migrated pets
            pets = ProfileStorePetHandler:GetPlayerPets(userId)
        end
    end
    
    return pets
end

-- Handle remote function calls
getPetsDataEvent.OnServerInvoke = function(player)
    return getPlayerPets(player)
end

-- Update pet XP/levels when players earn XP (optional enhancement)
local function handlePlayerXPChange(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local xp = leaderstats:FindFirstChild("XP")
        if xp and xp:IsA("IntValue") then
            xp.Changed:Connect(function()
                -- This could be used to update pet XP based on player XP gains
                -- For now, we'll just leave this as a placeholder
            end)
        end
    end
end

-- Connect player added event
Players.PlayerAdded:Connect(function(player)
    handlePlayerXPChange(player)
    
    -- Check for pets to migrate
    task.spawn(function()
        local pets = getPlayerPets(player)
        print("Player " .. player.Name .. " has " .. #pets .. " pets")
    end)
end)

-- Handle existing players
for _, player in ipairs(Players:GetPlayers()) do
    handlePlayerXPChange(player)
end

print("Pet Inventory Handler initialized") 