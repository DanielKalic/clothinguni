-- Coin Rain System Script
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")

-- VIP Gamepass ID
local VIP_GAMEPASS_ID = 1226490667

-- Get the coin template from ReplicatedStorage
local coinTemplate = ReplicatedStorage:WaitForChild("Coin"):WaitForChild("CoinPart")

-- Get the CoinRainPart from workspace
local coinRainPart = workspace:WaitForChild("CoinRainPart")

-- Create a unique event for coin notifications to avoid duplicate notifications
local coinNotificationEvent
if not ReplicatedStorage:FindFirstChild("CoinNotificationEvent") then
    coinNotificationEvent = Instance.new("RemoteEvent")
    coinNotificationEvent.Name = "CoinNotificationEvent"
    coinNotificationEvent.Parent = ReplicatedStorage
else
    coinNotificationEvent = ReplicatedStorage:FindFirstChild("CoinNotificationEvent")
end

-- Configuration
local SPAWN_INTERVAL = 180 -- Spawn coins every 3 minutes (180 seconds)
local COIN_LIFETIME = 180 -- Coins disappear after 3 minutes (180 seconds)
local COINS_PER_SPAWN = 2 -- Number of coins to spawn each time
local COIN_REWARD = 5 -- Coins to give player when collected
local FALL_SPEED = 8 -- How fast coins fall (studs per second)
local SPIN_SPEED = 3 -- How fast coins spin

-- Variables
local activeCoins = {} -- Track all active coins
local notificationDebounce = {} -- Track which players have received notifications recently

-- Function to check if player owns VIP gamepass
local function hasVIPGamepass(player)
    local success, ownsGamepass = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, VIP_GAMEPASS_ID)
    end)
    return success and ownsGamepass
end

-- Function to get a random position on the CoinRainPart
local function getRandomRainPosition()
    local size = coinRainPart.Size
    local position = coinRainPart.Position
    
    -- Calculate random position within the part bounds
    local x = position.X + math.random(-size.X/2, size.X/2)
    local y = position.Y + (size.Y/2) + 5 -- Start slightly above the part
    local z = position.Z + math.random(-size.Z/2, size.Z/2)
    
    return Vector3.new(x, y, z)
end

-- Function to add coins to a player
local function addCoinsToPlayer(player, amount, coinId)
    print("DEBUG: Adding", amount, "coins to player", player.Name, "for coin", coinId)
    
    -- Check for notification debounce
    if notificationDebounce[player.UserId] then
        print("DEBUG: Notification debounce active for", player.Name, "- skipping")
        return
    end
    
    -- Check if player has VIP gamepass for 2x coins
    local isVIP = hasVIPGamepass(player)
    local finalAmount = amount
    if isVIP then
        finalAmount = amount * 2
        print("DEBUG: VIP player detected - doubling coins from", amount, "to", finalAmount)
    end
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local coins = leaderstats:FindFirstChild("Coins")
        if coins and coins:IsA("IntValue") then
            coins.Value = coins.Value + finalAmount
            
            -- Set notification debounce for this player
            notificationDebounce[player.UserId] = true
            
            -- Show notification to player - USING DEDICATED COIN NOTIFICATION EVENT
            if coinNotificationEvent then
                print("DEBUG: Firing COIN notification event for", player.Name)
                local message = "+" .. finalAmount .. " Coins!"
                if isVIP then
                    message = message .. " (VIP 2x)"
                end
                coinNotificationEvent:FireClient(player, message, Color3.fromRGB(255, 215, 0))
            end
            
            -- Update daily objectives for coin collection (count as 1 pickup, not coin amount)
            if _G.UpdateDailyObjective then
                _G.UpdateDailyObjective(player, "collectCoins", 1)
            end
            
            -- Reset debounce after a delay
            task.delay(1, function()
                notificationDebounce[player.UserId] = nil
                print("DEBUG: Notification debounce cleared for", player.Name)
            end)
        else
            warn("Player " .. player.Name .. " does not have a Coins value in leaderstats")
        end
    else
        warn("Player " .. player.Name .. " does not have leaderstats")
    end
end

-- Function to create physics body for falling coins
local function setupCoinPhysics(coin)
    -- Set up collision filtering to ignore CenterRotation AND CoinRainPart
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local ignoreParts = {}
    
    -- Find CenterRotation meshpart in workspace.Billboards.Ships
    local centerRotation = nil
    local billboardsFolder = workspace:FindFirstChild("Billboards")
    if billboardsFolder then
        local shipsFolder = billboardsFolder:FindFirstChild("Ships")
        if shipsFolder then
            for _, child in pairs(shipsFolder:GetDescendants()) do
                if child.Name == "CenterRotation" and child:IsA("MeshPart") then
                    centerRotation = child
                    table.insert(ignoreParts, child)
                    break
                end
            end
        end
    end
    
    -- Add CoinRainPart to ignore list so coins don't hit it immediately
    if coinRainPart then
        table.insert(ignoreParts, coinRainPart)
    end
    
    -- Add the coin itself to ignore list
    table.insert(ignoreParts, coin)
    
    raycastParams.FilterDescendantsInstances = ignoreParts
    
    print("DEBUG: [CoinRain] Set up collision filtering to ignore", #ignoreParts, "parts including CoinRainPart and CenterRotation")
    
    -- Keep coin anchored and manually move it down
    coin.CanCollide = false
    coin.Anchored = true
    
    local falling = true
    local fallConnection
    
    -- Set up falling animation
    fallConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not coin or not coin.Parent or not falling then
            if fallConnection then
                fallConnection:Disconnect()
            end
            return
        end
        
        -- Move coin down
        local currentPos = coin.Position
        local newY = currentPos.Y - (FALL_SPEED * deltaTime)
        
        -- Cast a ray downward to detect ground (cast much further down)
        local rayOrigin = Vector3.new(currentPos.X, currentPos.Y, currentPos.Z)
        local rayDirection = Vector3.new(0, -50, 0) -- Cast 50 studs down to find actual ground
        
        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        
        if raycastResult then
            -- Check if we're close enough to the ground (within 2 studs)
            local distanceToGround = currentPos.Y - raycastResult.Position.Y
            
            --print("DEBUG: [CoinRain] Coin", coin.Name, "distance to ground:", distanceToGround, "hit part:", raycastResult.Instance.Name)
            
            if distanceToGround <= 2 then
                -- Hit the ground, stop falling
                falling = false
                coin.Position = Vector3.new(currentPos.X, raycastResult.Position.Y + 1, currentPos.Z) -- Position slightly above ground
                coin.CanCollide = true -- Enable collision for player interaction
                
                print("DEBUG: [CoinRain] Coin", coin.Name, "landed on ground at", coin.Position, "hit:", raycastResult.Instance.Name)
                
                -- Disconnect the falling connection
                fallConnection:Disconnect()
            else
                -- Continue falling
                coin.Position = Vector3.new(currentPos.X, newY, currentPos.Z)
            end
        else
            -- No ground found, continue falling (this shouldn't happen but just in case)
            coin.Position = Vector3.new(currentPos.X, newY, currentPos.Z)
            
            -- Safety check - if coin falls too far below spawn point, destroy it
            if newY < (currentPos.Y - 500) then
                --print("DEBUG: [CoinRain] Coin", coin.Name, "fell too far, destroying")
                falling = false
                coin:Destroy()
                fallConnection:Disconnect()
            end
        end
    end)
    
    return fallConnection
end

-- Function to spawn a single coin
local function spawnSingleCoin()
    local position = getRandomRainPosition()
    local coinId = "Coin_" .. os.time() .. "_" .. math.random(1000, 9999)
    
    -- Clone the coin template
    local coin = coinTemplate:Clone()
    coin.Name = coinId
    coin.Position = position
    coin.CanCollide = false -- Start non-collidable while falling
    coin.Anchored = true -- Keep anchored and move manually
    
    -- Parent to workspace
    coin.Parent = workspace
    
    -- Set up physics for falling
    local fallConnection = setupCoinPhysics(coin)
    
    -- Set up spin animation
    local spinConnection
    spinConnection = RunService.Heartbeat:Connect(function()
        if not coin or not coin.Parent then
            if spinConnection then
                spinConnection:Disconnect()
            end
            return
        end
        
        -- Spin the coin
        coin.Orientation = coin.Orientation + Vector3.new(0, SPIN_SPEED, 0)
    end)
    
    -- Global debounce per coin to completely prevent multiple collections
    local collected = false
    
    -- Handle touched event
    local touchConnection
    touchConnection = coin.Touched:Connect(function(hit)
        -- Check if already collected to prevent multiple collections
        if collected then
            print("DEBUG: Coin", coinId, "already collected, ignoring touch")
            return
        end
        
        local player = Players:GetPlayerFromCharacter(hit.Parent)
        if player and coin.Parent then
            print("DEBUG: Player", player.Name, "touched coin", coinId)
            
            -- Set collection flag immediately to prevent double processing
            collected = true
            
            -- Give the player coins
            addCoinsToPlayer(player, COIN_REWARD, coinId)
            
            -- Clean up connections
            if spinConnection then 
                spinConnection:Disconnect()
                print("DEBUG: Disconnected spin connection for coin", coinId)
            end
            if touchConnection then
                touchConnection:Disconnect()
            end
            if fallConnection then
                fallConnection:Disconnect()
            end
            
            -- Remove from active coins tracking
            for i, activeCoin in ipairs(activeCoins) do
                if activeCoin.coin == coin then
                    table.remove(activeCoins, i)
                    break
                end
            end
            
            -- Remove the coin
            coin:Destroy()
            print("DEBUG: Destroyed coin", coinId)
        end
    end)
    
    -- Add to active coins tracking with cleanup timer
    local coinData = {
        coin = coin,
        spawnTime = os.time(),
        spinConnection = spinConnection,
        touchConnection = touchConnection,
        fallConnection = fallConnection
    }
    table.insert(activeCoins, coinData)
    
    -- Set up auto-cleanup after lifetime expires
    task.delay(COIN_LIFETIME, function()
        if coin and coin.Parent then
            print("DEBUG: Auto-removing expired coin", coinId)
            
            -- Clean up connections
            if spinConnection then
                spinConnection:Disconnect()
            end
            if touchConnection then
                touchConnection:Disconnect()
            end
            if fallConnection then
                fallConnection:Disconnect()
            end
            
            -- Remove from active coins tracking
            for i, activeCoin in ipairs(activeCoins) do
                if activeCoin.coin == coin then
                    table.remove(activeCoins, i)
                    break
                end
            end
            
            coin:Destroy()
        end
    end)
    
    print("DEBUG: [CoinRain] Spawned coin", coinId, "at", position)
    return coin
end

-- Function to spawn multiple coins (rain effect)
local function spawnCoinRain()
    print("DEBUG: [CoinRain] Starting coin rain - spawning", COINS_PER_SPAWN, "coins")
    
    for i = 1, COINS_PER_SPAWN do
        -- Add small delay between coin spawns for visual effect
        task.delay(i * 0.5, function()
            spawnSingleCoin()
        end)
    end
end

-- Function to clean up expired coins (safety cleanup)
local function cleanupExpiredCoins()
    local currentTime = os.time()
    for i = #activeCoins, 1, -1 do
        local coinData = activeCoins[i]
        if currentTime - coinData.spawnTime > COIN_LIFETIME then
            print("DEBUG: [CoinRain] Cleaning up expired coin", coinData.coin.Name)
            
            -- Clean up connections
            if coinData.spinConnection then
                coinData.spinConnection:Disconnect()
            end
            if coinData.touchConnection then
                coinData.touchConnection:Disconnect()
            end
            if coinData.fallConnection then
                coinData.fallConnection:Disconnect()
            end
            
            -- Remove coin
            if coinData.coin and coinData.coin.Parent then
                coinData.coin:Destroy()
            end
            
            -- Remove from tracking
            table.remove(activeCoins, i)
        end
    end
end

-- Start the coin rain system
task.spawn(function()
    -- Initial spawn
    spawnCoinRain()
    
    while true do
        task.wait(SPAWN_INTERVAL)
        
        -- Clean up any expired coins first
        cleanupExpiredCoins()
        
        -- Spawn new coin rain
        spawnCoinRain()
    end
end)

-- Cleanup expired coins every minute as safety measure
task.spawn(function()
    while true do
        task.wait(60) -- Check every minute
        cleanupExpiredCoins()
    end
end)

-- Clean up all coins when the server is shutting down
game:BindToClose(function()
    for _, coinData in ipairs(activeCoins) do
        if coinData.coin and coinData.coin.Parent then
            coinData.coin:Destroy()
        end
    end
end)

print("Coin Rain System initialized - Spawning", COINS_PER_SPAWN, "coins every", SPAWN_INTERVAL, "seconds") 