-- Disable Default Roblox Player List (the stats display in the upper right corner)
local StarterGui = game:GetService("StarterGui")

-- Function to disable the player list
local function disablePlayerList()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end

-- First attempt to disable
local success, errorMessage = pcall(disablePlayerList)
if not success then
    warn("Failed to disable player list on first attempt: " .. errorMessage)
end

-- Some games might have scripts that re-enable the player list or
-- it might not disable immediately, so we'll keep trying
spawn(function()
    while true do
        wait(2)
        pcall(disablePlayerList)
    end
end)

print("Default player list UI in upper right corner has been disabled") 