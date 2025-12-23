-- Spatial Refuge Death Handling
-- Handles player death in refuge: corpse relocation and refuge deletion

-- Assume dependencies are already loaded
SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Handle player death
local function OnPlayerDeath(player)
    if not player then return end
    
    -- Check if player died inside their refuge
    if not SpatialRefuge.IsPlayerInRefuge(player) then
        return  -- Death occurred in normal world
    end
    
    if getDebug() then
        print("[SpatialRefuge] Player " .. player:getUsername() .. " died in refuge")
    end
    
    local pmd = player:getModData()
    local returnPos = pmd.spatialRefuge_return
    
    -- Move corpse to last world position (where they entered from)
    if returnPos then
        -- Get player's corpse
        local corpse = player:getCorpse()
        if corpse then
            corpse:setX(returnPos.x)
            corpse:setY(returnPos.y)
            corpse:setZ(returnPos.z)
            
            if getDebug() then
                print("[SpatialRefuge] Moved corpse to world position: " .. returnPos.x .. ", " .. returnPos.y)
            end
        end
    end
    
    -- Delete refuge completely
    SpatialRefuge.DeleteRefuge(player)
    
    -- Clear all player refuge data
    pmd.spatialRefuge_id = nil
    pmd.spatialRefuge_return = nil
    pmd.spatialRefuge_lastTeleport = nil
    pmd.spatialRefuge_lastDamage = nil
    
    if getDebug() then
        print("[SpatialRefuge] Refuge deleted - player will start fresh on respawn")
    end
end

-- Register death event handler
Events.OnPlayerDeath.Add(OnPlayerDeath)

if getDebug() then
    print("[SpatialRefuge] Death handling initialized")
end

return SpatialRefuge

