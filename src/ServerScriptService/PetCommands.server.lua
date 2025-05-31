-- Pet Management Commands
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

-- Load the ProfileStore Pet Handler
local ProfileStorePetHandler = require(ReplicatedStorage:WaitForChild("ProfileStorePetHandler"))

-- Legacy DataStore
local ownedPetsStore = DataStoreService:GetDataStore("OwnedPets")

-- Admin user IDs with pet management permissions
local ADMIN_USERS = {
    52452243, -- Add your own user ID here
}

-- Check if a player is an admin
local function isAdmin(player)
    return table.find(ADMIN_USERS, player.UserId) ~= nil
end

-- Handle player chat commands
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        -- Only process commands for admins
        if not isAdmin(player) then
            return
        end
        
        -- Commands must start with !pets
        if not string.match(message, "^!pets") then
            return
        end
        
        -- Parse the command
        local args = {}
        for arg in string.gmatch(message, "%S+") do
            table.insert(args, arg)
        end
        
        if #args < 2 then
            -- Send usage help
            player:SetAttribute("LastPetCommand", "Usage: !pets <command> [args]")
            player:SetAttribute("LastPetCommandTime", os.time())
            return
        end
        
        local command = string.lower(args[2])
        
        -- !pets count - Show how many pets a player has
        if command == "count" then
            local targetPlayer = player
            if args[3] then
                targetPlayer = Players:FindFirstChild(args[3])
                if not targetPlayer then
                    player:SetAttribute("LastPetCommand", "Player not found: " .. args[3])
                    player:SetAttribute("LastPetCommandTime", os.time())
                    return
                end
            end
            
            local pets = ProfileStorePetHandler:GetPlayerPets(targetPlayer.UserId)
            player:SetAttribute("LastPetCommand", targetPlayer.Name .. " has " .. #pets .. " pets")
            player:SetAttribute("LastPetCommandTime", os.time())
        
        -- !pets migrate - Migrate pets from DataStore to ProfileStore
        elseif command == "migrate" then
            local targetPlayer = player
            if args[3] then
                targetPlayer = Players:FindFirstChild(args[3])
                if not targetPlayer then
                    player:SetAttribute("LastPetCommand", "Player not found: " .. args[3])
                    player:SetAttribute("LastPetCommandTime", os.time())
                    return
                end
            end
            
            local success, message = ProfileStorePetHandler:MigrateFromDataStore(ownedPetsStore, targetPlayer.UserId)
            player:SetAttribute("LastPetCommand", message)
            player:SetAttribute("LastPetCommandTime", os.time())
        
        -- !pets list - List all pets for a player
        elseif command == "list" then
            local targetPlayer = player
            if args[3] then
                targetPlayer = Players:FindFirstChild(args[3])
                if not targetPlayer then
                    player:SetAttribute("LastPetCommand", "Player not found: " .. args[3])
                    player:SetAttribute("LastPetCommandTime", os.time())
                    return
                end
            end
            
            local pets = ProfileStorePetHandler:GetPlayerPets(targetPlayer.UserId)
            
            -- Create a list with the first few pets
            local petList = ""
            local maxPetsToShow = 5
            for i = 1, math.min(maxPetsToShow, #pets) do
                petList = petList .. pets[i].name .. " (" .. pets[i].rarity .. "), "
            end
            
            -- Remove trailing comma
            if petList ~= "" then
                petList = string.sub(petList, 1, -3)
            end
            
            -- Add ellipsis if there are more pets
            if #pets > maxPetsToShow then
                petList = petList .. " ... and " .. (#pets - maxPetsToShow) .. " more"
            end
            
            if petList == "" then
                petList = "No pets found"
            end
            
            player:SetAttribute("LastPetCommand", targetPlayer.Name .. "'s pets: " .. petList)
            player:SetAttribute("LastPetCommandTime", os.time())
        
        -- !pets add <player> <petname> <rarity> - Add a pet to a player
        elseif command == "add" and args[3] and args[4] and args[5] then
            local targetPlayer = Players:FindFirstChild(args[3])
            if not targetPlayer then
                player:SetAttribute("LastPetCommand", "Player not found: " .. args[3])
                player:SetAttribute("LastPetCommandTime", os.time())
                return
            end
            
            local petName = args[4]
            local rarity = args[5]
            
            if rarity ~= "Common" and rarity ~= "Rare" and rarity ~= "Legendary" and rarity ~= "VIP" then
                player:SetAttribute("LastPetCommand", "Invalid rarity. Use: Common, Rare, Legendary, or VIP")
                player:SetAttribute("LastPetCommandTime", os.time())
                return
            end
            
            -- Create pet data
            local petData = {
                name = petName,
                rarity = rarity,
                level = 1,
                xp = 0,
                acquiredAt = os.time()
            }
            
            -- Save to ProfileStore
            local success, petId = ProfileStorePetHandler:SavePet(targetPlayer.UserId, petData)
            
            if success then
                player:SetAttribute("LastPetCommand", "Added " .. petName .. " (" .. rarity .. ") to " .. targetPlayer.Name)
                player:SetAttribute("LastPetCommandTime", os.time())
            else
                player:SetAttribute("LastPetCommand", "Failed to add pet")
                player:SetAttribute("LastPetCommandTime", os.time())
            end
        
        -- !pets clear <player> - Remove all pets from a player
        elseif command == "clear" and args[3] then
            local targetPlayer = Players:FindFirstChild(args[3])
            if not targetPlayer then
                player:SetAttribute("LastPetCommand", "Player not found: " .. args[3])
                player:SetAttribute("LastPetCommandTime", os.time())
                return
            end
            
            -- Get all pets
            local pets = ProfileStorePetHandler:GetPlayerPets(targetPlayer.UserId)
            
            -- Delete each pet
            for _, pet in ipairs(pets) do
                ProfileStorePetHandler:DeletePet(targetPlayer.UserId, pet.id)
            end
            
            player:SetAttribute("LastPetCommand", "Cleared " .. #pets .. " pets from " .. targetPlayer.Name)
            player:SetAttribute("LastPetCommandTime", os.time())
        else
            -- Unknown command
            player:SetAttribute("LastPetCommand", "Unknown command. Try: count, migrate, list, add, clear")
            player:SetAttribute("LastPetCommandTime", os.time())
        end
    end)
end)

print("Pet Commands initialized") 