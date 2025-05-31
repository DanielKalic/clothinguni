--[[

	Copyright © 2023, MapleMarvel (https://www.roblox.com/users/263710410/profile). All Rights Reserved.
	
	
	ExtendGuiButtonClass:
	Class that extends the GuiButton class with additional functionality.
		
--]]


-- Class
local ExtendGuiButtonClass = {}
ExtendGuiButtonClass.__index = ExtendGuiButtonClass


-- Constructor
function ExtendGuiButtonClass.new(paramGuiButton)
	local self = setmetatable({}, ExtendGuiButtonClass)
	
	
	-- Validate
	if paramGuiButton == nil then
		error("Required parameters are missing for constructor ExtendGuiButtonClass.new.")
	end

	-- Instance Properties
	self.GuiButton = paramGuiButton  -- The GuiButton extended by this class
	self.Connections = {}  -- Event connections

	
	return self
end


-- Instance Methods

-- SetReveal
function ExtendGuiButtonClass:SetReveal(paramGuiObjectToDisplay, paramImageLabelRevealOff, paramImageLabelRevealOn, paramIsRevealed)
	
	-- Validate
	if paramGuiObjectToDisplay and paramImageLabelRevealOff and paramImageLabelRevealOn then
		
		-- Set revealed state
		self.IsRevealed = false
		if paramIsRevealed then
			self.IsRevealed = paramIsRevealed
		end
		
		-- Local function
		local function RefreshGui()
			
			-- GuiObject to display
			paramGuiObjectToDisplay.Visible = self.IsRevealed
			
			-- Image that shows reveal status
			if self.IsRevealed then
				paramImageLabelRevealOn.Visible = true
				paramImageLabelRevealOff.Visible = false
			else
				paramImageLabelRevealOn.Visible = false
				paramImageLabelRevealOff.Visible = true
			end
			
		end
		
		-- Update gui
		RefreshGui()
		
		
		-- Disconnect existing connection
		local keyConnection1 = "MouseButton1Click"
		if self.Connections[keyConnection1] then self.Connections[keyConnection1]:Disconnect() end
		
		
		-- GuiButton Events

		-- GuiButton Event - MouseButton1Click
		self.Connections[keyConnection1] = self.GuiButton.MouseButton1Click:Connect(function()
			
			-- Toggle value
			self.IsRevealed = not self.IsRevealed
			
			-- Update gui
			RefreshGui()
			
		end)
		
	else
		warn("Required parameters are missing for ExtendGuiButtonClass:SetReveal.")
	end
	
end


return ExtendGuiButtonClass
