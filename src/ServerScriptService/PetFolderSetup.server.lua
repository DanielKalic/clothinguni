-- Pet Folder Setup
-- This script ensures the pet folder structure exists in ReplicatedStorage

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Function to create a folder if it doesn't exist
local function createFolderIfNeeded(parent, name)
    local folder = parent:FindFirstChild(name)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
    end
    return folder
end

-- Create main Pets folder
local petsFolder = createFolderIfNeeded(ReplicatedStorage, "Pets")

-- Create rarity folders
local commonFolder = createFolderIfNeeded(petsFolder, "Common")
local rareFolder = createFolderIfNeeded(petsFolder, "Rare")
local legendaryFolder = createFolderIfNeeded(petsFolder, "Legendary")
local vipFolder = createFolderIfNeeded(petsFolder, "VIP")

-- Add attributes to folders for additional properties
commonFolder:SetAttribute("Description", "Common pets are easy to find and make good starter companions.")
rareFolder:SetAttribute("Description", "Rare pets are harder to find but provide better bonuses.")
legendaryFolder:SetAttribute("Description", "Legendary pets are extremely rare and provide substantial bonuses.")
vipFolder:SetAttribute("Description", "VIP pets are exclusive to VIP members and provide the best bonuses.")
-- Add attributes to folders for additional properties

print("Pet folder structure initialized") 