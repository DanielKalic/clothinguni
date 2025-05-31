local Players = game:GetService("Players")
local player = Players.LocalPlayer
local progressBarContainer = script.Parent  -- adjust if needed

-- Wait for leaderstats and the Level value.
local leaderstats = player:WaitForChild("leaderstats")
local levelValue = leaderstats:WaitForChild("Level")

-- Function to update the progress bar's text.
local function updateLevelText()
	progressBarContainer:SetAttribute("TextValue", "Level " .. tostring(levelValue.Value))
end

levelValue.Changed:Connect(updateLevelText)
updateLevelText()

-- Debug function: prints the GUI hierarchy only for GuiObjects.
local function printGUIHierarchy(guiObject, indent)
	indent = indent or ""
	local info = guiObject.Name .. " (" .. guiObject.ClassName .. ")"
	if guiObject:IsA("GuiObject") then
		info = info .. " - Position: " .. tostring(guiObject.Position) .. " | Size: " .. tostring(guiObject.Size)
	else
		info = info .. " (No Position/Size)"
	end
	print(indent .. info)
	for _, child in ipairs(guiObject:GetChildren()) do
		printGUIHierarchy(child, indent .. "  ")
	end
end

-- Uncomment the following line to print the hierarchy:
-- printGUIHierarchy(progressBarContainer)
