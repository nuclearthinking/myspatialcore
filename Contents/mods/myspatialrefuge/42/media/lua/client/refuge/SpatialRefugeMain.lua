-- Spatial Refuge Main Module
-- Handles refuge data persistence and coordinate management

-- Prevent double-loading
if SpatialRefuge and SpatialRefuge._mainLoaded then
    return SpatialRefuge
end

-- Use global modules (loaded by main)
SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Mark as loaded
SpatialRefuge._mainLoaded = true

-- Initialize ModData structure
function SpatialRefuge.InitializeModData()
    local modData = ModData.getOrCreate(SpatialRefugeConfig.MODDATA_KEY)
    if not modData[SpatialRefugeConfig.REFUGES_KEY] then
        modData[SpatialRefugeConfig.REFUGES_KEY] = {}
    end
    return modData
end

-- Get global refuge registry
function SpatialRefuge.GetRefugeRegistry()
    local modData = SpatialRefuge.InitializeModData()
    return modData[SpatialRefugeConfig.REFUGES_KEY]
end

-- Get refuge data for a specific player
function SpatialRefuge.GetRefugeData(player)
    if not player then return nil end
    
    local username = player:getUsername()
    local registry = SpatialRefuge.GetRefugeRegistry()
    
    return registry[username]
end

-- Get or create refuge data for a player
function SpatialRefuge.GetOrCreateRefugeData(player)
    if not player then return nil end
    
    local refugeData = SpatialRefuge.GetRefugeData(player)
    
    if not refugeData then
        -- Allocate coordinates for new refuge
        local centerX, centerY, centerZ = SpatialRefuge.AllocateRefugeCoordinates()
        
        local username = player:getUsername()
        refugeData = {
            refugeId = "refuge_" .. username,
            username = username,
            centerX = centerX,
            centerY = centerY,
            centerZ = centerZ,
            tier = 0,
            radius = SpatialRefugeConfig.TIERS[0].radius,
            createdTime = os.time(),
            lastExpanded = os.time()
        }
        
        -- Save to registry
        SpatialRefuge.SaveRefugeData(refugeData)
        
        if getDebug() then
            print("[SpatialRefuge] Created new refuge for " .. username .. " at (" .. centerX .. ", " .. centerY .. ")")
        end
    end
    
    return refugeData
end

-- Save refuge data to ModData
function SpatialRefuge.SaveRefugeData(refugeData)
    if not refugeData or not refugeData.username then return end
    
    local registry = SpatialRefuge.GetRefugeRegistry()
    registry[refugeData.username] = refugeData
end

-- Delete refuge data from ModData
function SpatialRefuge.DeleteRefugeData(player)
    if not player then return end
    
    local username = player:getUsername()
    local registry = SpatialRefuge.GetRefugeRegistry()
    registry[username] = nil
    
    if getDebug() then
        print("[SpatialRefuge] Deleted refuge data for " .. username)
    end
end

-- Allocate coordinates for a new refuge
-- Returns: centerX, centerY, centerZ
function SpatialRefuge.AllocateRefugeCoordinates()
    local registry = SpatialRefuge.GetRefugeRegistry()
    local baseX = SpatialRefugeConfig.REFUGE_BASE_X
    local baseY = SpatialRefugeConfig.REFUGE_BASE_Y
    local baseZ = SpatialRefugeConfig.REFUGE_BASE_Z
    local spacing = SpatialRefugeConfig.REFUGE_SPACING
    
    -- Simple allocation: count existing refuges and offset
    local count = 0
    for _ in pairs(registry) do
        count = count + 1
    end
    
    -- Arrange refuges in a grid pattern
    local row = math.floor(count / 10)
    local col = count % 10
    
    local centerX = baseX + (col * spacing)
    local centerY = baseY + (row * spacing)
    local centerZ = baseZ
    
    return centerX, centerY, centerZ
end

-- Check if player is currently in their refuge
function SpatialRefuge.IsPlayerInRefuge(player)
    if not player then return false end
    
    -- Safety check for player position functions
    if not player.getX or not player.getY then
        return false
    end
    
    local x = player:getX()
    local y = player:getY()
    
    if not x or not y then return false end
    
    -- Check if in refuge coordinate space (within 1000 tiles of base)
    local baseX = SpatialRefugeConfig.REFUGE_BASE_X
    local baseY = SpatialRefugeConfig.REFUGE_BASE_Y
    
    return x >= baseX and x < baseX + 1000 and 
           y >= baseY and y < baseY + 1000
end

-- Get player's return position from ModData
function SpatialRefuge.GetReturnPosition(player)
    if not player then return nil end
    
    local pmd = player:getModData()
    return pmd.spatialRefuge_return
end

-- Save player's return position to ModData
function SpatialRefuge.SaveReturnPosition(player, x, y, z)
    if not player then return end
    
    local pmd = player:getModData()
    pmd.spatialRefuge_return = {
        x = x,
        y = y,
        z = z
    }
end

-- Clear player's return position
function SpatialRefuge.ClearReturnPosition(player)
    if not player then return end
    
    local pmd = player:getModData()
    pmd.spatialRefuge_return = nil
end

-- Get last teleport timestamp
function SpatialRefuge.GetLastTeleportTime(player)
    if not player then return 0 end
    
    local pmd = player:getModData()
    return pmd.spatialRefuge_lastTeleport or 0
end

-- Update last teleport timestamp
function SpatialRefuge.UpdateTeleportTime(player)
    if not player then return end
    
    local pmd = player:getModData()
    pmd.spatialRefuge_lastTeleport = getTimestamp()  -- Use game time instead of os.time()
end

-- Get last damage timestamp
function SpatialRefuge.GetLastDamageTime(player)
    if not player then return 0 end
    
    local pmd = player:getModData()
    return pmd.spatialRefuge_lastDamage or 0
end

-- Update last damage timestamp (called from damage event)
function SpatialRefuge.UpdateDamageTime(player)
    if not player then return end
    
    local pmd = player:getModData()
    pmd.spatialRefuge_lastDamage = getTimestamp()  -- Use game time instead of os.time()
end

-- Track damage events for combat teleport blocking
local function OnPlayerDamage(player)
    SpatialRefuge.UpdateDamageTime(player)
end

-- Global flag to track world readiness
SpatialRefuge.worldReady = false

-- Initialize on game start
local function OnGameStart()
    SpatialRefuge.InitializeModData()
    
    if getDebug() then
        print("[SpatialRefuge] System initialized")
    end
end

-- World initialization (wait for world to be fully loaded)
local function OnInitWorld()
    SpatialRefuge.worldReady = true
    
    if getDebug() then
        print("[SpatialRefuge] World ready, refuge generation enabled")
    end
end

-- Register events
Events.OnGameStart.Add(OnGameStart)
Events.OnInitWorld.Add(OnInitWorld)
Events.OnPlayerGetDamage.Add(OnPlayerDamage)

return SpatialRefuge

