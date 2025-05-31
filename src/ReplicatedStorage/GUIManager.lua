-- GUI Manager module
local GUIManager = {}

-- Track the state of GUIs
local guiStates = {
    NPCGeneratorOpen = false,
    ListingsGUIOpen = false
}

-- Store references to toggle buttons
local toggleButtons = {}

-- Function to register a toggle button
function GUIManager:RegisterToggleButton(guiName, button)
    toggleButtons[guiName] = button
end

-- Function to set a GUI's open state
function GUIManager:SetGUIState(guiName, isOpen)
    guiStates[guiName] = isOpen
    self:UpdateToggleButtons()
end

-- Function to check if any GUI is open
function GUIManager:IsAnyGUIOpen()
    for _, isOpen in pairs(guiStates) do
        if isOpen then
            return true
        end
    end
    return false
end

-- Function to update all toggle button visibility
function GUIManager:UpdateToggleButtons()
    local anyGUIOpen = self:IsAnyGUIOpen()
    
    -- Set visibility for all registered toggle buttons
    for _, button in pairs(toggleButtons) do
        button.Visible = not anyGUIOpen
    end
end

return GUIManager 