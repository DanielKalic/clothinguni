-- NPCMoverTemplate (in ServerStorage)
local npc = script.Parent
local humanoid = npc:FindFirstChildOfClass("Humanoid")
if not humanoid then
	warn("NPC has no Humanoid!")
	return
end

-- Ensure a BindableEvent exists on the Humanoid to signal when MoveTo actually finishes.
local moveFinishedEvent = humanoid:FindFirstChild("MoveToActuallyFinished")
if not moveFinishedEvent then
	moveFinishedEvent = Instance.new("BindableEvent")
	moveFinishedEvent.Name = "MoveToActuallyFinished"
	moveFinishedEvent.Parent = humanoid
end

-- Get and sort the waypoints (e.g., Waypoint0, Waypoint1, ...)
local waypointsFolder = game.Workspace:WaitForChild("Waypoints")
local waypoints = {}
for _, wp in ipairs(waypointsFolder:GetChildren()) do
	table.insert(waypoints, wp)
end
table.sort(waypoints, function(a, b)
	-- Extract numbers from waypoint names for proper numerical sorting
	local numA = tonumber(a.Name:match("%d+")) or 0
	local numB = tonumber(b.Name:match("%d+")) or 0
	return numA < numB
end)

-- Custom function that keeps calling MoveTo until the NPC actually reaches the point.
local function actuallyMoveTo(model, point)
	local connection
	connection = humanoid.MoveToFinished:Connect(function(reached)
		connection:Disconnect()
		connection = nil
		if reached then
			moveFinishedEvent:Fire()
		else
			-- If MoveTo stopped for any reason, try again.
			actuallyMoveTo(model, point)
		end
	end)
	humanoid:MoveTo(point)
end

-- Loop through each waypoint with no extra delays.
for _, wp in ipairs(waypoints) do
	actuallyMoveTo(npc, wp.Position)
	moveFinishedEvent.Event:Wait()
end

npc:Destroy()
