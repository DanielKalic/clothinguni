--[[

	Copyright © 2023, MapleMarvel (https://www.roblox.com/users/263710410/profile). All Rights Reserved.
	
	
	ExtendGuiObjectClass:
	Class that extends the GuiObject class with additional functionality.
		
--]]


-- Class
local ExtendGuiObjectClass = {}
ExtendGuiObjectClass.__index = ExtendGuiObjectClass


-- Constructor
function ExtendGuiObjectClass.new(paramGuiObject)
	local self = setmetatable({}, ExtendGuiObjectClass)
	
	
	-- Validate
	if paramGuiObject == nil then
		error("Required parameters are missing for constructor ExtendGuiObjectClass.new.")
	end

	-- Instance Properties
	self.GuiObject = paramGuiObject  -- The GuiObject extended by this class
	self.Connections = {}  -- Event connections

	
	return self
end


-- Instance Methods

-- SetHoverOver
function ExtendGuiObjectClass:SetHoverOver(paramGuiObjectToShowOnHoverOver)
	
	-- Validate
	if paramGuiObjectToShowOnHoverOver then
		
		-- Disconnect existing connections
		local keyConnection1 = "MouseEnter"
		local keyConnection2 = "MouseLeave"
		if self.Connections[keyConnection1] then self.Connections[keyConnection1]:Disconnect() end
		if self.Connections[keyConnection2] then self.Connections[keyConnection2]:Disconnect() end
		
		
		-- GuiObject Events

		-- GuiObject Event - MouseEnter
		self.Connections[keyConnection1] = self.GuiObject.MouseEnter:Connect(function(x, y)
			-- Show
			paramGuiObjectToShowOnHoverOver.Visible = true
		end)

		-- GuiObject Event - MouseLeave
		self.Connections[keyConnection2] = self.GuiObject.MouseLeave:Connect(function(x, y)
			-- Hide
			paramGuiObjectToShowOnHoverOver.Visible = false
		end)
		
	else
		warn("Required parameters are missing for ExtendGuiObjectClass:SetHoverOver.")
	end
	
end


return ExtendGuiObjectClass
