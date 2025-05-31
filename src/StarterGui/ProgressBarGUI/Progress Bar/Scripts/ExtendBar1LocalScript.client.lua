-- ExtendLocalBar1Script (LocalScript)
local Players = game:GetService("Players")

local SCRIPTS_FOLDER_NAME = "Epic UI Pack"
local ExtendTextLabelClass = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild(SCRIPTS_FOLDER_NAME):WaitForChild("ExtendTextLabelClass"))
local ExtendBarClass = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild(SCRIPTS_FOLDER_NAME):WaitForChild("ExtendBarClass"))

local guiObjectProgessBar = script.Parent.Parent
local configuration = guiObjectProgessBar:WaitForChild("Configuration")
local guiObjectTextLabelVar = configuration:WaitForChild("ObjectTextLabel")
local guiObjectTextLabelStrokeVar = configuration:WaitForChild("ObjectTextLabelStroke")
local guiObjectBarVar = configuration:WaitForChild("ObjectBar")
local guiObjectBarDivisionsVar = configuration:WaitForChild("ObjectBarDivisions")

local attributesParent = guiObjectProgessBar

if guiObjectTextLabelVar and guiObjectTextLabelStrokeVar and guiObjectBarVar and guiObjectBarDivisionsVar then
	while not guiObjectTextLabelVar.Value do task.wait() end
	while not guiObjectTextLabelStrokeVar.Value do task.wait() end
	while not guiObjectBarVar.Value do task.wait() end
	while not guiObjectBarDivisionsVar.Value do task.wait() end

	local guiObjectTextLabel = guiObjectTextLabelVar.Value
	local guiObjectTextLabelStroke = guiObjectTextLabelStrokeVar.Value
	local guiObjectBar = guiObjectBarVar.Value
	local guiObjectBarDivisions = guiObjectBarDivisionsVar.Value

	local extendedTextLabel = ExtendTextLabelClass.new(guiObjectTextLabel)
	local extendedTextLabelStroke = ExtendTextLabelClass.new(guiObjectTextLabelStroke)
	extendedTextLabel:SetTextValueFromAttributes(attributesParent, "TextValueEnabled", "TextValue")
	extendedTextLabelStroke:SetTextValueFromAttributes(attributesParent, "TextValueEnabled", "TextValue")
	extendedTextLabel:SetTextSizeFromAttributes(attributesParent, "TextSizeEnabled", "TextSizeScale", guiObjectProgessBar)
	extendedTextLabelStroke:SetTextSizeFromAttributes(attributesParent, "TextSizeEnabled", "TextSizeScale", guiObjectProgessBar)

	local extendedBar = ExtendBarClass.new(guiObjectBar, guiObjectBarDivisions)
	extendedBar:SetProgressFromAttributes(attributesParent, "BarPercent", "BarDivisionsEnabled")
end
