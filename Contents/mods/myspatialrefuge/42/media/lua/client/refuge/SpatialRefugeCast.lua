-- Spatial Refuge Cast Time System
-- Uses native ISTimedAction for professional progress bar

SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Cast time in ticks (60 ticks = 1 second)
local CAST_TIME_TICKS = 180  -- 3 seconds

-- Begin teleport casting using ISTimedAction (with progress bar)
function SpatialRefuge.BeginTeleportCast(player)
    if not player then return end
    
    -- Safety check for ISEnterRefugeAction
    if not ISEnterRefugeAction then
        print("[SpatialRefuge] ERROR: ISEnterRefugeAction not loaded!")
        player:Say("Error: Refuge action not available")
        return
    end
    
    if getDebug() then
        print("[SpatialRefuge] Starting timed action to enter refuge")
    end
    
    -- Create and queue the timed action
    local action = ISEnterRefugeAction:new(player, CAST_TIME_TICKS)
    
    if not ISTimedActionQueue then
        print("[SpatialRefuge] ERROR: ISTimedActionQueue not available!")
        player:Say("Error: Action queue not available")
        return
    end
    
    ISTimedActionQueue.add(action)
end

-- Begin exit casting using ISTimedAction
function SpatialRefuge.BeginExitCast(player, relicObj)
    if not player then return end
    
    -- Safety check for ISExitRefugeAction
    if not ISExitRefugeAction then
        print("[SpatialRefuge] ERROR: ISExitRefugeAction not loaded!")
        player:Say("Error: Refuge exit action not available")
        return
    end
    
    if getDebug() then
        print("[SpatialRefuge] Starting timed action to exit refuge")
    end

    if not ISTimedActionQueue then
        print("[SpatialRefuge] ERROR: ISTimedActionQueue not available!")
        return
    end
    
    -- Walk to relic first when possible (prevents bugged action when far away)
    if relicObj and relicObj.getSquare then
        local square = relicObj:getSquare()
        if square then
            if ISWalkToTimedAction then
                local walkAction = ISWalkToTimedAction:new(player, square)
                ISTimedActionQueue.add(walkAction)
            elseif luautils and luautils.walkAdj then
                if not luautils.walkAdj(player, square) then
                    return
                end
            end
        end
    end

    -- Create and queue the timed action
    local action = ISExitRefugeAction:new(player, CAST_TIME_TICKS)
    ISTimedActionQueue.add(action)
end

if getDebug() then
    print("[SpatialRefuge] Timed action system initialized (3 second cast with progress bar)")
end

return SpatialRefuge
