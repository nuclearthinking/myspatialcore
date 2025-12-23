-- ISExitRefugeAction
-- Timed action for exiting Spatial Refuge (with progress bar)

-- Check if ISBaseTimedAction is available
if not ISBaseTimedAction then
    print("[SpatialRefuge] ERROR: ISBaseTimedAction not available! Cannot create ISExitRefugeAction")
    return
end

-- Create the class
ISExitRefugeAction = ISBaseTimedAction:derive("ISExitRefugeAction")

print("[SpatialRefuge] ISExitRefugeAction class created successfully")

function ISExitRefugeAction:isValid()
    -- Check if player is in refuge
    if not self.player then return false end
    
    if SpatialRefuge and SpatialRefuge.IsPlayerInRefuge then
        return SpatialRefuge.IsPlayerInRefuge(self.player)
    end
    
    return true
end

function ISExitRefugeAction:update()
    self.character:faceThisObject(self.character)
end

function ISExitRefugeAction:start()
    self:setActionAnim("Loot")
    self:setOverrideHandModels(nil, nil)
end

function ISExitRefugeAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISExitRefugeAction:perform()
    -- Action completed - teleport player back
    if SpatialRefuge and SpatialRefuge.ExitRefuge then
        SpatialRefuge.ExitRefuge(self.player)
    end
    ISBaseTimedAction.perform(self)
end

function ISExitRefugeAction:new(player, time)
    local o = ISBaseTimedAction.new(self, player)
    o.player = player
    o.stopOnWalk = true  -- Interrupt on movement
    o.stopOnRun = true
    o.maxTime = time     -- Duration in ticks
    return o
end

return ISExitRefugeAction
