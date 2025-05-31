-- ClothingTemplateHandler (ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

-- Create the remote function for getting clothing templates
local getClothingTemplateFunc = ReplicatedStorage:FindFirstChild("GetClothingTemplateFunc")
if not getClothingTemplateFunc then
    getClothingTemplateFunc = Instance.new("RemoteFunction")
    getClothingTemplateFunc.Name = "GetClothingTemplateFunc"
    getClothingTemplateFunc.Parent = ReplicatedStorage
end

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
        print("DEBUG: [ClothingTemplateHandler] Successfully got template for " .. clothingType .. " ID " .. assetId .. ": " .. result)
        return result
    else
        print("DEBUG: [ClothingTemplateHandler] Failed to get template for " .. clothingType .. " ID " .. assetId)
        return nil
    end
end

-- Handle remote function calls from client
getClothingTemplateFunc.OnServerInvoke = function(player, assetId, clothingType)
    -- Validate inputs
    if not assetId or not clothingType then
        return nil
    end
    
    -- Validate clothing type
    if clothingType ~= "Shirt" and clothingType ~= "Pants" then
        return nil
    end
    
    -- Get and return the template
    return getClothingTemplate(assetId, clothingType)
end

print("ClothingTemplateHandler initialized") 