--[[

	Copyright © 2023, MapleMarvel (https://www.roblox.com/users/263710410/profile). All Rights Reserved.
	
	
	ExtendBarClass:
	Class that extends the bar with additional functionality.
		
--]]


-- Class
local ExtendBarClass = {}
ExtendBarClass.__index = ExtendBarClass


-- Constructor
function ExtendBarClass.new(paramGuiObjectBar, paramGuiObjectDivisions)
	local self = setmetatable({}, ExtendBarClass)
	
	
	-- Validate
	if paramGuiObjectBar == nil or paramGuiObjectDivisions == nil then
		error("Required parameters are missing for constructor ExtendBarClass.new.")
	end

	-- Instance Properties
	self.GuiObjectBar = paramGuiObjectBar  -- The GuiObject whose length changes to indicate the progress
	self.GuiObjectDivisions = paramGuiObjectDivisions  -- The GuiObject that displays the divisions
	self.Connections = {}  -- Event connections
	

	return self
end


-- Instance Methods

-- SetProgressFromAttributes
function ExtendBarClass:SetProgressFromAttributes(paramAttributesParent, paramNameAttributeProgressPercent, paramNameAttributProgressBarDivisionsEnabled)
	
	-- Validate
	if paramAttributesParent and paramNameAttributeProgressPercent and paramNameAttributProgressBarDivisionsEnabled then
		
		-- Local function
		local function SetProgress()

			-- Get current attribute values
			local attributeProgressBarPercent = paramAttributesParent:GetAttribute(paramNameAttributeProgressPercent)
			local attributeProgressBarDivisionsEnabled = paramAttributesParent:GetAttribute(paramNameAttributProgressBarDivisionsEnabled)

			-- Validate
			local minValue = 0
			local maxValue = 100
			local newValue = math.clamp(attributeProgressBarPercent, minValue, maxValue)
			if newValue ~= attributeProgressBarPercent then
				paramAttributesParent:SetAttribute(paramNameAttributeProgressPercent, newValue)
			end

			-- Resize the progress bar
			local newXScale = newValue / maxValue
			self.GuiObjectBar.Size = UDim2.new(newXScale, 0, 1, 0)
			if newXScale == 0 then
				self.GuiObjectBar.Visible = false
			else
				self.GuiObjectBar.Visible = true
			end

			-- Show or hide divisions
			self.GuiObjectDivisions.Visible = attributeProgressBarDivisionsEnabled

		end

		-- Update progress bar
		SetProgress()

		
		-- Disconnect existing connections
		local keyConnection1 = "AttributeChangedSignal" .. paramNameAttributeProgressPercent
		local keyConnection2 = "AttributeChangedSignal" .. paramNameAttributProgressBarDivisionsEnabled
		if self.Connections[keyConnection1] then self.Connections[keyConnection1]:Disconnect() end
		if self.Connections[keyConnection2] then self.Connections[keyConnection2]:Disconnect() end
		
		
		-- Attribute Events

		-- Attribute Event - GetPropertyChangedSignal
		-- Triggered when the attribute changes
		self.Connections[keyConnection1] = paramAttributesParent:GetAttributeChangedSignal(paramNameAttributeProgressPercent):Connect(function()

			-- Update progress bar
			SetProgress()

		end)

		-- Attribute Event - GetPropertyChangedSignal
		-- Triggered when the attribute changes
		self.Connections[keyConnection2] = paramAttributesParent:GetAttributeChangedSignal(paramNameAttributProgressBarDivisionsEnabled):Connect(function()

			-- Update progress bar
			SetProgress()

		end)
		
	else
		warn("Required parameters are missing for ExtendBarClass:SetProgressFromAttributes.")
	end
	
end


return ExtendBarClass
