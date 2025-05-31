-- ProfileStore Pet Handler Module
-- Replaces Firebase with ProfileStore for pet data

local ProfileStorePetHandler = {}

-- Wait for ProfileStore data to be ready
local function waitForProfileStore()
    while not _G.ProfileStoreData or not _G.ProfileStoreData.IsReady do
        wait(0.1)
    end
    return _G.ProfileStoreData
end

-- Function to get pets for a player from ProfileStore
function ProfileStorePetHandler:GetPlayerPets(userId)
    local ProfileStoreData = waitForProfileStore()
    return ProfileStoreData.GetPlayerPets(userId)
end

-- Function to save a pet to ProfileStore
function ProfileStorePetHandler:SavePet(userId, petData)
    local ProfileStoreData = waitForProfileStore()
    return ProfileStoreData.SavePet(userId, petData)
end

-- Function to delete a pet from ProfileStore
function ProfileStorePetHandler:DeletePet(userId, petId)
    local ProfileStoreData = waitForProfileStore()
    return ProfileStoreData.DeletePet(userId, petId)
end

-- Function to migrate pets from DataStore to ProfileStore (one-time use)
function ProfileStorePetHandler:MigrateFromDataStore(ownedPetsStore, userId)
    local ProfileStoreData = waitForProfileStore()
    return ProfileStoreData.MigrateFromDataStore(ownedPetsStore, userId)
end

-- Get equipped pets for a player
function ProfileStorePetHandler:GetEquippedPets(userId)
    local ProfileStoreData = waitForProfileStore()
    return ProfileStoreData.GetEquippedPets(userId)
end

-- Equip a pet to a specific slot
function ProfileStorePetHandler:EquipPet(userId, petId, slot)
    local ProfileStoreData = waitForProfileStore()
    return ProfileStoreData.EquipPet(userId, petId, slot)
end

-- Unequip a pet from a specific slot
function ProfileStorePetHandler:UnequipPet(userId, slot)
    local ProfileStoreData = waitForProfileStore()
    return ProfileStoreData.UnequipPet(userId, slot)
end

return ProfileStorePetHandler 