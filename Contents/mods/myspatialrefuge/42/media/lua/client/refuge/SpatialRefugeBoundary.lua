-- Spatial Refuge Boundary Enforcement
-- Monitors player position and prevents them from leaving refuge boundaries

SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Check if player is outside their refuge boundaries
function SpatialRefuge.IsOutsideRefugeBoundary(player)
    if not player then return false end
    
    -- Only check if player is in refuge area
    if not SpatialRefuge.IsPlayerInRefuge(player) then
        return false
    end
    
    local refugeData = SpatialRefuge.GetRefugeData(player)
    if not refugeData then return false end
    
    local playerX = player:getX()
    local playerY = player:getY()
    local centerX = refugeData.centerX
    local centerY = refugeData.centerY
    local radius = refugeData.radius
    
    -- Check if outside boundary
    local minX = centerX - radius
    local maxX = centerX + radius + 1
    local minY = centerY - radius
    local maxY = centerY + radius + 1
    
    if playerX < minX or playerX > maxX or playerY < minY or playerY > maxY then
        return true, centerX, centerY
    end
    
    return false
end

-- Monitor player position and enforce boundaries
local function OnPlayerUpdate(player)
    if not player then return end
    
    -- Check if player is outside their refuge boundary
    local isOutside, centerX, centerY = SpatialRefuge.IsOutsideRefugeBoundary(player)
    
    if isOutside and centerX and centerY then
        -- Teleport player back to center
        player:setX(centerX)
        player:setLastX(centerX)
        player:setY(centerY)
        player:setLastY(centerY)
        
        -- Optional: Show message
        if getDebug() then
            print("[SpatialRefuge] Player reached boundary, teleported back to center")
        end
        
        player:Say("Cannot leave refuge boundary!")
    end
end

-- Register event (only check every few ticks to save performance)
local tickCounter = 0
local CHECK_INTERVAL = 10  -- Check every 10 ticks (~0.16 seconds)

local function OnPlayerUpdateThrottled(player)
    tickCounter = tickCounter + 1
    if tickCounter >= CHECK_INTERVAL then
        tickCounter = 0
        OnPlayerUpdate(player)
    end
end

Events.OnPlayerUpdate.Add(OnPlayerUpdateThrottled)

if getDebug() then
    print("[SpatialRefuge] Boundary enforcement initialized")
end

return SpatialRefuge

