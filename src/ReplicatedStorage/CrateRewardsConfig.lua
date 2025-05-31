-- Crate Rewards Configuration
-- This module stores all crate rewards and can be easily updated

return {
    ["Common"] = {
        devProductId = 3286468900,
        petFolder = "Pets/Common", -- Path to the pet models in ReplicatedStorage
        chances = {
            -- Define the chances (0-100%) for each pet
            ["BassBear"] = 16,
            ["Boxer"] = 17,
            ["Gnome"] = 17,
            ["Heart"] = 16,
            ["Mia"] = 17,
            ["WhiteCat"] = 17
            -- Sum of all chances should be 100
        }
    },
    ["Rare"] = {
        devProductId = 3286469077,
        petFolder = "Pets/Rare",
        chances = {
            ["Fox"] = 25,
            ["Pirate"] = 25,
            ["Sly"] = 25,
            ["Zebra"] = 25
        }
    },
    ["Legendary"] = {
        devProductId = 3286469322,
        petFolder = "Pets/Legendary",
        chances = {
            ["ConfusedAstronaut"] = 25,
            ["FBIAgent"] = 25,
            ["Murray"] = 25,
            ["Sticky"] = 25
        }
    },
    ["VIP"] = {
        devProductId = 3286470000,
        petFolder = "Pets/VIP",
        chances = {
            ["Cthulhu"] = 25,
            ["DarthVader"] = 25,
            ["ElephantShrew"] = 25,
            ["Penguin"] = 25
        }
    }
} 