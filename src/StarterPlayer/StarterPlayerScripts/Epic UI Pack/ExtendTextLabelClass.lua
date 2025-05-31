--[[

	Copyright © 2023, MapleMarvel (https://www.roblox.com/users/263710410/profile). All Rights Reserved.
	
	
	ExtendTextLabelClass:
	Class that extends the TextLabel class with additional functionality.
		
--]]


-- Class
local ExtendTextLabelClass = {}
ExtendTextLabelClass.__index = ExtendTextLabelClass


-- Constructor
function ExtendTextLabelClass.new(paramTextLabel)
	local self = setmetatable({}, ExtendTextLabelClass)
	
	
	-- Validate
	if paramTextLabel == nil then
		error("Required parameters missing for constructor ExtendTextLabelClass.new.")
	end
	
	-- Instance Properties
	self.TextLabel = paramTextLabel  -- The TextLabel extended by this class 
	self.TextLabelTextOriginal = paramTextLabel.Text  -- The original text value
	self.TextLabelSizeOriginal = paramTextLabel.TextSize  -- The original text size
	self.Connections = {}  -- Event connections

	
	return self
end


-- Instance Methods

-- SetTextValueFromAttributes
function ExtendTextLabelClass:SetTextValueFromAttributes(paramAttributesParent, paramNameAttributeTextValueEnabled, paramNameAttributeTextValue)
	
	-- Validate
	if paramAttributesParent and paramNameAttributeTextValueEnabled and paramNameAttributeTextValue then
		
		-- Local function
		local function SetTextValue()

			-- Get current attribute values
			local attributeTextValueEnabled = paramAttributesParent:GetAttribute(paramNameAttributeTextValueEnabled)
			local attributeTextValue = paramAttributesParent:GetAttribute(paramNameAttributeTextValue)

			-- If enabled
			if attributeTextValueEnabled == true then

				-- Set text to attribute value
				self.TextLabel.Text = attributeTextValue

			else

				-- Set text to original property value in Roblox Studio
				self.TextLabel.Text = self.TextLabelTextOriginal

			end

		end

		-- Update text value
		SetTextValue()
		

		-- Disconnect existing connections
		local keyConnection1 = "AttributeChangedSignal" .. paramNameAttributeTextValueEnabled
		local keyConnection2 = "AttributeChangedSignal" .. paramNameAttributeTextValue
		if self.Connections[keyConnection1] then self.Connections[keyConnection1]:Disconnect() end
		if self.Connections[keyConnection2] then self.Connections[keyConnection2]:Disconnect() end

		
		-- Attribute Events

		-- Attribute Event - GetPropertyChangedSignal
		-- Triggered when the attribute changes
		self.Connections[keyConnection1] = paramAttributesParent:GetAttributeChangedSignal(paramNameAttributeTextValueEnabled):Connect(function()

			-- Update text value
			SetTextValue()

		end)

		-- Attribute Event - GetPropertyChangedSignal
		-- Triggered when the attribute changes
		self.Connections[keyConnection2] = paramAttributesParent:GetAttributeChangedSignal(paramNameAttributeTextValue):Connect(function()

			-- Update text value
			SetTextValue()

		end)
		
	else
		warn("Required parameters are missing for ExtendTextLabelClass:SetTextValueFromAttributes.")
	end
	
end


-- SetTextValueFromAttributes
function ExtendTextLabelClass:SetTextSizeFromAttributes(paramAttributesParent, paramNameAttributeTextResponsiveEnabled, paramNameAttributeTextResponsiveScale, paramReferenceGuiObject)
	
	-- Validate
	if paramAttributesParent and paramNameAttributeTextResponsiveEnabled and paramNameAttributeTextResponsiveScale and paramReferenceGuiObject then
		
		-- Local function
		local function SetTextSize()

			-- Attributes
			local attributeTextResponsiveEnabled = paramAttributesParent:GetAttribute(paramNameAttributeTextResponsiveEnabled)
			local attributeTextResponsiveScale = paramAttributesParent:GetAttribute(paramNameAttributeTextResponsiveScale)

			-- If responsive is enabled
			if attributeTextResponsiveEnabled == true then

				-- Responsive size
				local referenceHeight = paramReferenceGuiObject.AbsoluteSize.Y
				if referenceHeight >= 0 then

					-- Responsive size
					local newTextSize = attributeTextResponsiveScale * referenceHeight
					self.TextLabel.TextSize = newTextSize

				end

			else

				-- Set text size to original property value in Roblox Studio
				self.TextLabel.TextSize = self.TextLabelSizeOriginal

			end

		end

		-- Update text size
		SetTextSize()
		
		
		-- Disconnect existing connections
		local keyConnection3 = "AttributeChangedSignal" .. paramNameAttributeTextResponsiveEnabled
		local keyConnection4 = "AttributeChangedSignal" .. paramNameAttributeTextResponsiveScale
		local keyConnection5 = "PropertyChangedSignal" .. "paramReferenceGuiObject"
		if self.Connections[keyConnection3] then self.Connections[keyConnection3]:Disconnect() end
		if self.Connections[keyConnection4] then self.Connections[keyConnection4]:Disconnect() end
		if self.Connections[keyConnection5] then self.Connections[keyConnection5]:Disconnect() end
		
		
		-- Attribute Events

		-- Attribute Event - GetPropertyChangedSignal
		-- Triggered when the attribute changes
		self.Connections[keyConnection3] = paramAttributesParent:GetAttributeChangedSignal(paramNameAttributeTextResponsiveEnabled):Connect(function()

			-- Update text size
			SetTextSize()

		end)

		-- Attribute Event - GetPropertyChangedSignal
		-- Triggered when the attribute changes
		self.Connections[keyConnection4] = paramAttributesParent:GetAttributeChangedSignal(paramNameAttributeTextResponsiveScale):Connect(function()

			-- Update text size
			SetTextSize()

		end)


		-- Instance Events

		-- Instance Event - GetPropertyChangedSignal
		-- Triggered whenever the object size changes
		self.Connections[keyConnection5] = paramReferenceGuiObject:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()

			-- Update text value
			SetTextSize()

		end)
		
	else
		warn("Required parameters are missing for ExtendTextLabelClass:SetTextSizeFromAttributes.")
	end
	
end


return ExtendTextLabelClass
