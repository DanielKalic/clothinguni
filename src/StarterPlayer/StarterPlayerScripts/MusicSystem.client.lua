-- Music System for Clothing Universe
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SaveMusicSetting = ReplicatedStorage:WaitForChild("SaveMusicSetting", 5)
local musicEnabled = true


local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Load music setting from server
local function loadMusicSetting()
	if SaveMusicSetting then
		local ok, result = pcall(function()
			return SaveMusicSetting:InvokeServer(nil)
		end)
		if ok and typeof(result) == "boolean" then
			musicEnabled = result
		end
	end
end

-- Music settings
local MUSIC_ENABLED_KEY = "MusicEnabled"
local currentSound = nil
local musicToggleButton = nil

-- Sound names in SoundService
local SOUND_NAMES = { "Sound1", "Sound2", "Sound3" }

-- UI Colors (matching billboard GUI style)
local BACKGROUND_COLOR = Color3.fromRGB(25, 25, 30)
local TITLE_COLOR = Color3.fromRGB(100, 200, 255)

-- Function to get a random sound
local function getRandomSound()
	local soundName = SOUND_NAMES[math.random(1, #SOUND_NAMES)]
	return SoundService:FindFirstChild(soundName)
end

-- Function to play next random song
local function playNextSong()
	if not musicEnabled then
		return
	end
	if currentSound and currentSound.IsPlaying then
		currentSound:Stop()
	end
	currentSound = getRandomSound()
	if currentSound then
		currentSound.Volume = 0.3
		currentSound:Play()
		currentSound.Ended:Connect(function()
			if musicEnabled then
				task.wait(1)
				playNextSong()
			end
		end)
	else
		warn("Could not find any music sounds in SoundService")
	end
end

-- Function to stop music
local function stopMusic()
	if currentSound and currentSound.IsPlaying then
		currentSound:Stop()
	end
end

-- Function to update music button appearance
function updateMusicButton()
	if not musicToggleButton then
		return
	end
	if musicEnabled then
		musicToggleButton.Text = "🎵"
		musicToggleButton.TextColor3 = TITLE_COLOR
	else
		musicToggleButton.Text = "🎵"
		musicToggleButton.TextColor3 = Color3.fromRGB(100, 100, 100)
		local strikeLine = musicToggleButton:FindFirstChild("StrikeLine")
		if not strikeLine then
			strikeLine = Instance.new("Frame")
			strikeLine.Name = "StrikeLine"
			strikeLine.Size = UDim2.new(0.8, 0, 0, 3)
			strikeLine.Position = UDim2.new(0.1, 0, 0.5, -1)
			strikeLine.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
			strikeLine.BorderSizePixel = 0
			strikeLine.Parent = musicToggleButton
			local lineCorner = Instance.new("UICorner")
			lineCorner.CornerRadius = UDim.new(0, 2)
			lineCorner.Parent = strikeLine
		end
		strikeLine.Visible = true
	end
	if musicEnabled then
		local strikeLine = musicToggleButton:FindFirstChild("StrikeLine")
		if strikeLine then
			strikeLine.Visible = false
		end
	end
end

-- Save music setting to server
local function UpdateMusicSetting()
	local onoff = script.onoff.Value
	if onoff == true then
		script.onoff.Value = false
	else
		script.onoff.Value = true
	end
end

-- Function to toggle music
local function toggleMusic()
	musicEnabled = not musicEnabled
	if musicEnabled then
		playNextSong()
		updateMusicButton()
	else
		stopMusic()
		updateMusicButton()
	end
	UpdateMusicSetting()
end

-- Function to create music toggle button
local function createMusicToggleButton()
	local billboardToggle = nil
	repeat
		task.wait(0.1)
		for _, gui in pairs(playerGui:GetChildren()) do
			if gui:IsA("ScreenGui") then
				billboardToggle = gui:FindFirstChild("BillboardToggle")
				if billboardToggle then
					break
				end
			end
		end
	until billboardToggle

	musicToggleButton = Instance.new("TextButton")
	musicToggleButton.Name = "MusicToggle"
	musicToggleButton.Size = UDim2.new(0, 50, 0, 50)
	musicToggleButton.Position = UDim2.new(1, -130, 1, -70)
	musicToggleButton.BackgroundColor3 = BACKGROUND_COLOR
	musicToggleButton.BackgroundTransparency = 0.2
	musicToggleButton.BorderSizePixel = 0
	musicToggleButton.Text = "🎵"
	musicToggleButton.TextColor3 = TITLE_COLOR
	musicToggleButton.TextSize = 24
	musicToggleButton.Font = Enum.Font.GothamBold
	musicToggleButton.Parent = billboardToggle.Parent

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 12)
	buttonCorner.Parent = musicToggleButton

	musicToggleButton.MouseButton1Click:Connect(function()
		toggleMusic()
	end)

	musicToggleButton.MouseEnter:Connect(function()
		TweenService:Create(
			musicToggleButton,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 55, 0, 55), Position = UDim2.new(1, -132.5, 1, -72.5), BackgroundTransparency = 0.1 }
		):Play()
	end)

	musicToggleButton.MouseLeave:Connect(function()
		TweenService:Create(
			musicToggleButton,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 50, 0, 50), Position = UDim2.new(1, -130, 1, -70), BackgroundTransparency = 0.2 }
		):Play()
	end)

	musicToggleButton.MouseButton1Down:Connect(function()
		TweenService:Create(
			musicToggleButton,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 48, 0, 48), Position = UDim2.new(1, -129, 1, -69) }
		):Play()
	end)

	musicToggleButton.MouseButton1Up:Connect(function()
		TweenService:Create(
			musicToggleButton,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 55, 0, 55), Position = UDim2.new(1, -132.5, 1, -72.5) }
		):Play()
	end)

	updateMusicButton()
end

-- Initialize music system
local function initializeMusicSystem()
	createMusicToggleButton()
	if musicEnabled then
		task.wait(2)
		playNextSong()
	end
end

-- Listen for setting changes from server
local musicSetting = script.onoff.Value
if musicSetting then
	if musicSetting == true then
		playNextSong()
	else
		stopMusic()
	end
	updateMusicButton()
end


-- Start the music system
task.spawn(function()
	task.wait(3)
	initializeMusicSystem()
end)
